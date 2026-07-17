import SwiftUI
import SwiftData
import CoreLocation
import Shared

// MARK: - NewRoundView
// iphone-2.2: 새 라운드 시작
// - 골프장 자동 매칭 (Haversine 3km) + 수동 검색
// - 서브코스 선택: 골프장 holesCount > 18 && subCourses 있으면 전반/후반 picker 표시
//   - 18홀: 전반 코스 picker + 후반 코스 picker
//   - 9홀: 전반 코스 picker만
//   - 미선택 가능 — "전반"/"후반" 자동 라벨
// - 동반자 입력 (최대 4인)
// - holesCount nil이면 9/18 선택 프롬프트 (라운드는 9 또는 18홀만)
// 02-USER_FLOWS F-A → F-B

@MainActor
struct NewRoundView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var roundViewModel: RoundViewModel?
    @Binding var isPresented: Bool

    // 골프장 매칭
    @State private var matchedCourse: GolfCourse?
    @State private var isMatching: Bool = false
    @State private var matchError: String?
    @State private var showCourseSearch: Bool = false
    @State private var courseSearchText: String = ""
    @State private var allCourses: [GolfCourse] = []
    @State private var filteredCourses: [GolfCourse] = []

    // 적응형 매칭 추가 상태
    @State private var candidateCourses: [GolfCourse] = []
    @State private var matchRadiusKm: Double = 3.0
    @State private var kakaoVerificationStatus: KakaoMatchStatus = .idle

    private enum KakaoMatchStatus: Equatable {
        case idle
        case verifying
        case verified       // GPS + 카카오 모두 확인
        case uncertain      // 사용자 확인 필요
        case unavailable    // API 없음, GPS 결과만 사용
    }

    // 서브코스 선택 (전반/후반 각각)
    @State private var selectedFrontSubCourse: SubCourse?
    @State private var selectedBackSubCourse: SubCourse?
    /// 후반 코스를 "추후 결정"으로 선택한 상태 — 전반 다음 순번 코스 잠정 배정
    @State private var isBackTentative: Bool = false

    // holesCount nil 처리 (라운드는 9 또는 18홀만)
    @State private var selectedHolesCount: Int = 18
    private let holeOptions = [9, 18]

    // 동반자 입력 (최대 4인)
    @State private var playerNames: [String] = ["나", "", "", ""]
    @State private var playerCount: Int = 1

    // Location
    @State private var userLocation: CLLocation?

    // 카카오 발견 골프장 (옵션 A fallback + 옵션 B 검색 통합)
    @State private var discoveredCandidates: [DiscoveredCourse] = []
    @State private var isDiscovering: Bool = false
    /// 현재 선택된 카카오 발견 코스 (startRound 시 영구 캐싱용)
    @State private var selectedDiscoveredCourse: DiscoveredCourse?

    /// Par 안내 alert (라운드 시작 직전 표시)
    @State private var showParGuideAlert: Bool = false

    /// 매칭된 골프장의 주소 (DB address nil 시 카카오 lazy resolve 결과)
    @State private var resolvedMatchedAddress: String?

    /// 복원 모드 — true이면 onAppear에서 NewRoundDraftStore.load() 적용
    private let restoreDraft: Bool

    init(roundViewModel: Binding<RoundViewModel?>, isPresented: Binding<Bool>, restoreDraft: Bool = false) {
        self._roundViewModel = roundViewModel
        self._isPresented = isPresented
        self.restoreDraft = restoreDraft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        courseSection
                        if let course = matchedCourse {
                            // 골프장 holesCount가 9/18이 아니거나 nil이면 라운드 홀 수 picker 표시
                            // (27/36홀 골프장도 라운드는 9 또는 18로 선택)
                            let metaHoles = course.holesCount ?? 0
                            if metaHoles != 9 && metaHoles != 18 {
                                holesPickerSection
                            }
                            if shouldShowSubCourseSelector(course: course) {
                                subCourseSelectorSection(course: course)
                            }
                        }
                        playersSection
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                // 시작 버튼
                VStack {
                    Spacer()
                    Button {
                        // par prefill 가능 여부 사전 판정:
                        // - prefill 가능하면 alert 없이 바로 시작
                        // - 불가능하면 "par 4로 시작" 안내 alert 표시
                        let canPrefill: Bool = {
                            guard let course = matchedCourse else { return false }
                            let courseHoles = course.holesCount ?? 0
                            let holes = (courseHoles == 9 || courseHoles == 18) ? courseHoles : selectedHolesCount
                            if holes == 18 {
                                if isBackTentative {
                                    // 추후 결정: 전반 par prefill 가능하면 잠정 배정 코스로도 prefill 시도 (정상 경로)
                                    return CourseParsResolver.pars(courseId: course.id, subCourseName: selectedFrontSubCourse?.name, context: modelContext) != nil
                                }
                                return CourseParsResolver.pars18(courseId: course.id, front: selectedFrontSubCourse?.name, back: selectedBackSubCourse?.name, context: modelContext) != nil
                            } else {
                                return CourseParsResolver.pars(courseId: course.id, subCourseName: selectedFrontSubCourse?.name, context: modelContext) != nil
                            }
                        }()
                        if canPrefill { startRound() } else { showParGuideAlert = true }
                    } label: {
                        Text("라운드 시작")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.springTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canStart ? Color.springGreenPrimary : Color.springBorder)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                    }
                    .disabled(!canStart)
                }
            }
            .navigationTitle("새 라운드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { isPresented = false }
                }
            }
            .alert("Par 설정 안내", isPresented: $showParGuideAlert) {
                Button("시작") { startRound() }
                Button("취소", role: .cancel) { }
            } message: {
                Text("모든 홀이 Par 4로 시작합니다.\n진행 화면에서 Par 셀(상단 행)을 탭해 3/4/5로 변경할 수 있어요.")
            }
            .task {
                await loadCourses()
                if restoreDraft, let draft = NewRoundDraftStore.load() {
                    applyDraft(draft)
                } else {
                    await matchNearestCourse()
                }
                // 초기 매칭 완료 후 address resolve (onChange가 task에서 발화 안 될 수 있으므로 직접 처리)
                if let course = matchedCourse, course.address?.nilIfEmpty == nil {
                    resolvedMatchedAddress = await CourseAddressResolver.shared.address(for: course)
                }
            }
            .onChange(of: matchedCourse?.id) { _, newId in
                saveDraft()
                // 골프장 변경 시 주소 초기화 후 lazy resolve
                resolvedMatchedAddress = nil
                if let course = matchedCourse, course.address?.nilIfEmpty == nil {
                    Task {
                        resolvedMatchedAddress = await CourseAddressResolver.shared.address(for: course)
                    }
                }
            }
            .onChange(of: selectedFrontSubCourse?.id) { _, _ in saveDraft() }
            .onChange(of: selectedBackSubCourse?.id) { _, _ in saveDraft() }
            .onChange(of: isBackTentative) { _, _ in saveDraft() }
            .onChange(of: selectedHolesCount) { _, _ in saveDraft() }
            .onChange(of: playerCount) { _, _ in saveDraft() }
            .onChange(of: playerNames) { _, _ in saveDraft() }
            .sheet(isPresented: $showCourseSearch) {
                CourseSearchSheet(
                    localCourses: allCourses,
                    searchText: $courseSearchText,
                    userLocation: userLocation,
                    modelContext: modelContext,
                    onSelectLocal: { course in
                        matchedCourse = course
                        selectedDiscoveredCourse = nil
                        selectedFrontSubCourse = nil
                        selectedBackSubCourse = nil
                        showCourseSearch = false
                    },
                    onSelectDiscovered: { discovered in
                        selectedDiscoveredCourse = discovered
                        matchedCourse = discovered.asGolfCourse()
                        selectedFrontSubCourse = nil
                        selectedBackSubCourse = nil
                        showCourseSearch = false
                    }
                )
            }
        }
    }

    // MARK: Sections

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("골프장")

            if isMatching {
                HStack {
                    ProgressView()
                        .tint(Color.springGreenPrimary)
                    Text("GPS로 골프장 찾는 중...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
                .background(Color.springSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let course = matchedCourse {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(course.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.springTextPrimary)
                                matchBadge
                            }
                            if let region = course.region.nilIfEmpty,
                               !region.isEmpty {
                                Text(region)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                            if let holes = course.holesCount {
                                Text("\(holes)홀")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                            // 주소 표시 — DB address 우선, 없으면 lazy resolve 결과
                            if let addr = course.address?.nilIfEmpty ?? resolvedMatchedAddress {
                                Text(addr)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.springTextSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer()
                        Button("변경") {
                            showCourseSearch = true
                            // 골프장 변경 시 서브코스 선택 초기화
                            selectedFrontSubCourse = nil
                            selectedBackSubCourse = nil
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springGreenPrimary)
                    }
                    // 카카오 검증 중 스피너
                    if kakaoVerificationStatus == .verifying {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(Color.springTextSecondary)
                            Text("카카오 위치 확인 중...")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.springTextSecondary)
                        }
                    }
                }
                .padding(16)
                .background(Color.springSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if !candidateCourses.isEmpty {
                // 다중 후보: 사용자 선택 UI
                candidateListSection
            } else if isDiscovering {
                // 카카오 발견 중 스피너
                HStack {
                    ProgressView()
                        .tint(Color.springGreenPrimary)
                    Text("카카오맵에서 근처 골프장 찾는 중...")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.springTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
                .background(Color.springSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if !discoveredCandidates.isEmpty {
                // 카카오 발견 골프장 fallback 섹션 (옵션 A)
                discoveredCandidatesSection
            } else {
                Button {
                    showCourseSearch = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(matchError ?? "골프장 검색")
                            .font(.system(size: 15))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    .foregroundStyle(matchError != nil ? .red : Color.springTextSecondary)
                    .padding(16)
                    .background(Color.springSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: 매칭 배지

    @ViewBuilder
    private var matchBadge: some View {
        switch kakaoVerificationStatus {
        case .verified:
            Text("GPS + 카카오 확인됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.springGreenSecondary.opacity(0.3))
                .clipShape(Capsule())
        case .uncertain:
            Text("GPS 자동 선택됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.8, green: 0.5, blue: 0.0))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.2))
                .clipShape(Capsule())
        default:
            Text("자동 선택됨")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.springGreenSecondary.opacity(0.3))
                .clipShape(Capsule())
        }
    }

    // MARK: 다중 후보 선택 카드

    private var candidateListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "location.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springGreenPrimary)
                Text("여러 후보가 있어요, 선택해주세요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.springTextPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Text("반경 \(String(format: "%.0f", matchRadiusKm * 1000))m 이내 골프장")
                .font(.system(size: 12))
                .foregroundStyle(Color.springTextSecondary)
                .padding(.horizontal, 16)

            ForEach(candidateCourses) { course in
                Button {
                    selectCourse(course)
                } label: {
                    CandidateCourseRowView(course: course, userLocation: userLocation)
                }
            }

            Button {
                showCourseSearch = true
            } label: {
                Text("직접 검색하기")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .background(Color.springSurfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 카카오 발견 골프장 섹션 (옵션 A fallback)

    private var discoveredCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.0))
                Text("근처에 발견된 골프장이 있어요")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.springTextPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Text("카카오맵 기준 — DB 미등록 골프장")
                .font(.system(size: 12))
                .foregroundStyle(Color.springTextSecondary)
                .padding(.horizontal, 16)

            ForEach(discoveredCandidates) { discovered in
                Button {
                    selectDiscoveredCourse(discovered)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(discovered.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.springTextPrimary)
                            if let address = discovered.address {
                                Text(address)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.springTextSecondary)
                                    .lineLimit(1)
                            }
                            // "카카오맵에 등록됨" 배지
                            Text("카카오맵에 등록됨")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.0))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        if let dist = discovered.distanceKm {
                            Text(String(format: "%.1fkm", dist))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.springGreenPrimary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.springTextSecondary)
                    }
                    .padding(14)
                    .background(Color.springSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                }
            }

            Button {
                showCourseSearch = true
            } label: {
                Text("직접 검색하기")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.springTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
        .background(Color.springSurfaceElevated.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 카카오 발견 코스 선택

    private func selectDiscoveredCourse(_ discovered: DiscoveredCourse) {
        selectedDiscoveredCourse = discovered
        matchedCourse = discovered.asGolfCourse()
        discoveredCandidates = []
        kakaoVerificationStatus = .idle
        Task { await HapticEngine.shared.play(.gpsMatchComplete) }
    }

    // MARK: - 후보에서 코스 선택

    private func selectCourse(_ course: GolfCourse) {
        matchedCourse = course
        candidateCourses = []
        kakaoVerificationStatus = .idle
        Task { await HapticEngine.shared.play(.gpsMatchComplete) }
    }

    private var holesPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("홀 수")
            HStack(spacing: 8) {
                ForEach(holeOptions, id: \.self) { n in
                    Button {
                        selectedHolesCount = n
                    } label: {
                        Text("\(n)홀")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedHolesCount == n
                                ? Color.springTextPrimary
                                : Color.springTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(selectedHolesCount == n
                                ? Color.springGreenPrimary
                                : Color.springSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    /// 전반/후반 코스 picker 섹션.
    /// - 18홀: 전반 picker + 후반 picker 둘 다 표시
    /// - 9홀: 전반 picker만 표시
    /// - 미선택 가능 (nil이면 화면에서 "전반"/"후반" 자동 라벨)
    private func subCourseSelectorSection(course: GolfCourse) -> some View {
        let subCourses = availableSubCourses(course: course)

        return VStack(alignment: .leading, spacing: 16) {
            // 전반 코스 picker
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("전반 코스")
                subCoursePickerRow(
                    subCourses: subCourses,
                    selected: selectedFrontSubCourse,
                    onSelect: { selectedFrontSubCourse = $0 }
                )
            }

            // 후반 코스 picker — 18홀일 때만
            if selectedHolesCount == 18 {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("후반 코스")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 일반 서브코스 칩
                            ForEach(subCourses) { sub in
                                let isSelected = !isBackTentative && selectedBackSubCourse?.name == sub.name
                                Button {
                                    isBackTentative = false
                                    selectedBackSubCourse = isSelected ? nil : sub
                                } label: {
                                    Text(sub.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(isSelected
                                            ? Color.springTextPrimary
                                            : Color.springTextSecondary)
                                        .padding(.horizontal, 16)
                                        .frame(height: 44)
                                        .background(isSelected
                                            ? Color.springGreenPrimary
                                            : Color.springSurfaceElevated)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            // "추후 결정" 칩 — 전반 다음 순번 코스 잠정 배정
                            Button {
                                isBackTentative = true
                                selectedBackSubCourse = nil
                            } label: {
                                Text("추후 결정")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(isBackTentative
                                        ? Color.springTextPrimary
                                        : Color.springTextSecondary)
                                    .padding(.horizontal, 16)
                                    .frame(height: 44)
                                    .background(isBackTentative
                                        ? Color.orange
                                        : Color.springSurfaceElevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }
        }
    }

    /// 서브코스 후보 버튼 행 (선택/미선택 토글 가능)
    private func subCoursePickerRow(
        subCourses: [SubCourse],
        selected: SubCourse?,
        onSelect: @escaping (SubCourse?) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(subCourses) { sub in
                    let isSelected = selected?.name == sub.name
                    Button {
                        // 이미 선택된 항목을 다시 탭하면 해제 (미선택으로 복귀)
                        onSelect(isSelected ? nil : sub)
                    } label: {
                        Text(sub.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isSelected
                                ? Color.springTextPrimary
                                : Color.springTextSecondary)
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(isSelected
                                ? Color.springGreenPrimary
                                : Color.springSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var playersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("동반자")
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        if playerCount > 1 { playerCount -= 1 }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(playerCount > 1 ? Color.springGreenPrimary : Color.springBorder)
                    }
                    .disabled(playerCount <= 1)

                    Text("\(playerCount)명")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.springTextPrimary)
                        .frame(minWidth: 30)

                    Button {
                        if playerCount < 4 { playerCount += 1 }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(playerCount < 4 ? Color.springGreenPrimary : Color.springBorder)
                    }
                    .disabled(playerCount >= 4)
                }
            }

            VStack(spacing: 8) {
                ForEach(0..<playerCount, id: \.self) { idx in
                    HStack {
                        Text(idx == 0 ? "나" : "동반자\(idx)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.springTextSecondary)
                            .frame(width: 60, alignment: .leading)
                        TextField("이름 (선택)", text: $playerNames[idx])
                            .font(.system(size: 15))
                            .foregroundStyle(Color.springTextPrimary)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color.springSurfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private var canStart: Bool {
        matchedCourse != nil
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.springTextSecondary)
            .textCase(.uppercase)
    }

    /// 서브코스 selector 표시 여부.
    /// 1) 골프장 자체 subCourses 메타에 있으면 표시
    /// 2) CourseParsCatalog에 등록된 sub-course가 2개 이상이면 표시 (par prefill 가능)
    private func shouldShowSubCourseSelector(course: GolfCourse) -> Bool {
        if let subs = course.subCourses, !subs.isEmpty, (course.holesCount ?? 0) > 18 {
            return true
        }
        return CourseParsCatalog.subCourseNames(for: course.id).count >= 2
    }

    /// picker에 표시할 서브코스 후보 (메타 + CoursePars 통합)
    private func availableSubCourses(course: GolfCourse) -> [SubCourse] {
        if let subs = course.subCourses, !subs.isEmpty {
            return subs
        }
        // CoursePars 데이터에서 동적 생성
        return CourseParsCatalog.subCourseNames(for: course.id)
            .map { SubCourse(name: $0) }
    }

    // MARK: Logic

    private func loadCourses() async {
        do {
            allCourses = try await CourseRepository.shared.loadAll()
            filteredCourses = allCourses
        } catch {
            matchError = "골프장 DB 로드 실패"
        }
    }

    private func matchNearestCourse() async {
        isMatching = true
        defer { isMatching = false }

        // 위치 권한 요청 (미결정 상태면 시스템 팝업 표시)
        let locationService = LocationService.shared
        let authStatus = await locationService.requestAuthorization()

        guard authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways else {
            matchError = "위치 권한이 없어요. 직접 검색하세요"
            Task { await HapticEngine.shared.play(.permissionDenied) }
            return
        }

        // 현재 위치 획득 (5초 타임아웃)
        guard let loc = await locationService.currentLocation() else {
            matchError = "위치를 가져올 수 없어요. 직접 검색하세요"
            return
        }

        userLocation = loc

        // 적응형 임계값 매칭: 1km → 3km → 5km 순차 탐색
        let adaptiveResult = (try? await CourseRepository.shared.nearestCoursesAdaptive(
            to: (lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        ))

        matchRadiusKm = adaptiveResult?.radiusKm ?? 5.0

        if let matched = adaptiveResult?.matched {
            // 단일 자동 매칭 → 카카오 재검증
            matchedCourse = matched
            Task { await HapticEngine.shared.play(.gpsMatchComplete) }
            await verifyWithKakao(course: matched, location: loc)
        } else if let candidates = adaptiveResult?.candidates, !candidates.isEmpty {
            // 다중 후보 → 사용자 선택 UI
            candidateCourses = candidates
            matchedCourse = nil
        } else {
            // 매칭 없음 → 카카오 발견 fallback (옵션 A)
            await discoverNearbyWithKakao(location: loc)
        }
    }

    /// GPS 매칭 실패 시 카카오 로컬 API로 근처 골프장 발견 시도.
    private func discoverNearbyWithKakao(location: CLLocation) async {
        isDiscovering = true
        defer { isDiscovering = false }

        do {
            let discovered = try await CourseDiscoveryService.shared.searchNearby(
                location: location,
                radiusM: 2000
            )
            if discovered.isEmpty {
                matchError = "반경 5km 이내 골프장이 없어요. 직접 검색하세요"
            } else {
                discoveredCandidates = discovered
            }
        } catch CourseDiscoveryError.unavailable {
            // API 키 없음 — 수동 검색으로 안내
            matchError = "반경 5km 이내 골프장이 없어요. 직접 검색하세요"
        } catch {
            matchError = "골프장을 찾을 수 없어요. 직접 검색하세요"
        }
    }

    /// GPS 매칭 결과를 카카오 로컬 API로 재검증한다.
    private func verifyWithKakao(course: GolfCourse, location: CLLocation) async {
        kakaoVerificationStatus = .verifying
        let result = await KakaoVerificationService.shared.verify(
            course: course,
            userLocation: location
        )
        switch result {
        case .matched:
            kakaoVerificationStatus = .verified
        case .uncertain:
            kakaoVerificationStatus = .uncertain
        case .unavailable:
            kakaoVerificationStatus = .unavailable
        }
    }

    private func startRound() {
        guard let course = matchedCourse else { return }

        // 라운드는 9 또는 18홀만. 골프장 holesCount는 메타데이터용 — 라운드 홀 수에 직접 사용 안 함.
        // holesCount가 nil이거나 9/18이 아닌 경우에는 selectedHolesCount(9 또는 18) 사용.
        let courseHoles = course.holesCount ?? 0
        let holes = (courseHoles == 9 || courseHoles == 18) ? courseHoles : selectedHolesCount

        // 카카오 발견 코스 영구 캐싱 (옵션 C)
        // @Attribute(.unique) 제거 → insert 전 중복 조회로 대체
        if let discovered = selectedDiscoveredCourse {
            let kakaoId = discovered.kakaoPlaceId
            let predicate = #Predicate<PersistedDiscoveredCourse> { $0.kakaoPlaceId == kakaoId }
            let existing = (try? modelContext.fetch(FetchDescriptor(predicate: predicate))) ?? []
            if existing.isEmpty {
                let persisted = PersistedDiscoveredCourse(
                    kakaoPlaceId: discovered.kakaoPlaceId,
                    name: discovered.name,
                    address: discovered.address,
                    phone: discovered.phone,
                    lat: discovered.lat,
                    lng: discovered.lng,
                    placeUrl: discovered.placeUrl,
                    firstUsedAt: .now
                )
                modelContext.insert(persisted)
                do {
                    try modelContext.save()
                } catch {
                    // 캐시 실패는 라운드 시작을 막지 않는다 — 다음 검색 시 재캐싱된다.
                    AppLogger.round.error("[NewRound] 카카오 골프장 캐시 저장 실패 — id=\(kakaoId, privacy: .public): \(error.localizedDescription)")
                }
            }
        }

        // 플레이어 생성
        var players: [Player] = []
        for i in 0..<playerCount {
            let trimmed = playerNames[i].trimmingCharacters(in: .whitespaces)
            let name = trimmed.isEmpty ? (i == 0 ? "나" : "동반자\(i)") : trimmed
            players.append(Player(name: name, isOwner: i == 0, order: i))
        }

        // RoundViewModel 생성 후 라운드 시작
        let vm = RoundViewModel(modelContext: modelContext)
        vm.attachWorkoutCoordinator()
        WCRoundBridge.shared.attach(to: vm)  // B: iOS↔Watch 양방향 sync (startRound 전에 hook)
        vm.startRound(
            courseId: course.id,
            courseName: course.name,
            frontCourseName: selectedFrontSubCourse?.name,
            backCourseName: isBackTentative ? nil : selectedBackSubCourse?.name,
            backTentative: isBackTentative,
            players: players,
            holesCount: holes
        )
        roundViewModel = vm
        // 라운드 실제 시작 — draft clear
        NewRoundDraftStore.clear()
        isPresented = false
    }

    // MARK: - Draft persistence

    private func saveDraft() {
        let draft = NewRoundDraft(
            courseId: matchedCourse?.id ?? "",
            courseName: matchedCourse?.name ?? "",
            frontSubCourseName: selectedFrontSubCourse?.name,
            backSubCourseName: selectedBackSubCourse?.name,
            isBackTentative: isBackTentative,
            holesCount: selectedHolesCount,
            playerNames: playerNames,
            playerCount: playerCount
        )
        NewRoundDraftStore.save(draft)
    }

    private func applyDraft(_ draft: NewRoundDraft) {
        // 골프장 — id로 allCourses에서 찾기
        if !draft.courseId.isEmpty, let course = allCourses.first(where: { $0.id == draft.courseId }) {
            matchedCourse = course
            // 서브코스 매칭
            if let frontName = draft.frontSubCourseName {
                selectedFrontSubCourse = course.subCourses?.first(where: { $0.name == frontName })
            }
            if let backName = draft.backSubCourseName {
                selectedBackSubCourse = course.subCourses?.first(where: { $0.name == backName })
            }
        }
        selectedHolesCount = draft.holesCount
        isBackTentative = draft.isBackTentative
        playerCount = draft.playerCount
        playerNames = draft.playerNames
        AppLogger.view.info("NewRoundDraft 복원: course=\(draft.courseName, privacy: .private), \(draft.playerCount)명")
    }
}

// MARK: - CourseSearchSheet (카카오 통합 검색 — 옵션 B)

/// 이전 라운드 이력 요약 (count + 가장 최근 날짜).
struct RoundHistorySummary {
    let count: Int
    let latestDate: Date
}

/// 로컬 DB + 영구 캐시 + 카카오 로컬 API 통합 검색 Sheet.
struct CourseSearchSheet: View {
    let localCourses: [GolfCourse]
    @Binding var searchText: String
    let userLocation: CLLocation?
    let modelContext: ModelContext
    let onSelectLocal: (GolfCourse) -> Void
    let onSelectDiscovered: (DiscoveredCourse) -> Void
    @Environment(\.dismiss) private var dismiss

    // 검색 결과 상태
    @State private var kakaoResults: [DiscoveredCourse] = []
    @State private var persistedCourses: [GolfCourse] = []
    @State private var isSearchingKakao: Bool = false
    /// 카카오 검색 debounce 태스크
    @State private var kakaoSearchTask: Task<Void, Never>?

    // MARK: - 이전 라운드 이력 (courseId 기준 + courseName 폴백)
    /// courseId → 이력 요약 (isFinished == true 라운드만)
    @State private var historyById: [String: RoundHistorySummary] = [:]
    /// courseName → 이력 요약 (courseId 없을 때 폴백)
    @State private var historyByName: [String: RoundHistorySummary] = [:]

    // MARK: - 결과 분류

    /// 로컬 DB + 캐시 결과 (이름 필터링 + alias 매칭)
    private var localFiltered: [GolfCourse] {
        let all = localCourses + persistedCourses
        if searchText.isEmpty { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || CourseNameMatcher.matches(course: $0, query: searchText)
        }
    }

    /// 카카오 결과에서 로컬과 중복 제거 (이름+200m 이내면 제거)
    private var deduplicatedKakaoResults: [DiscoveredCourse] {
        kakaoResults.filter { kakao in
            !localFiltered.contains { local in
                guard let ch = local.clubhouse else { return false }
                let nameMatch = local.name.localizedCaseInsensitiveContains(kakao.name) ||
                               kakao.name.localizedCaseInsensitiveContains(local.name)
                let dist = haversineKm(
                    lat1: ch.lat, lng1: ch.lng,
                    lat2: kakao.lat, lng2: kakao.lng
                )
                return nameMatch && dist < 0.2
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // 로컬 DB 결과
                if !localFiltered.isEmpty {
                    Section {
                        ForEach(localFiltered) { course in
                            Button {
                                onSelectLocal(course)
                            } label: {
                                LocalCourseRowView(
                                    course: course,
                                    history: historySummary(for: course)
                                )
                            }
                        }
                    } header: {
                        Text("등록 골프장 (\(localFiltered.count))")
                    }
                }

                // 카카오 발견 결과
                if isSearchingKakao {
                    Section {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text("카카오맵 검색 중...")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.springTextSecondary)
                        }
                    } header: {
                        Text("카카오맵 발견")
                    }
                } else if !deduplicatedKakaoResults.isEmpty {
                    Section {
                        ForEach(deduplicatedKakaoResults) { discovered in
                            Button {
                                onSelectDiscovered(discovered)
                            } label: {
                                courseRowDiscovered(discovered)
                            }
                        }
                    } header: {
                        Text("카카오맵 발견 (\(deduplicatedKakaoResults.count))")
                    }
                }
            }
            .navigationTitle("골프장 검색")
            .searchable(text: $searchText, prompt: "골프장 이름")
            .onChange(of: searchText) { _, newValue in
                scheduleKakaoSearch(query: newValue)
            }
            .task {
                loadPersistedCourses()
                loadRoundHistory()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    // MARK: - Row Builders

    private func courseRowDiscovered(_ discovered: DiscoveredCourse) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(discovered.name)
                    .foregroundStyle(Color.springTextPrimary)
                Text("카카오맵 발견")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.0))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Capsule())
            }
            if let address = discovered.address {
                Text(address)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.springTextSecondary)
                    .lineLimit(1)
            }
            if let dist = discovered.distanceKm {
                Text(String(format: "%.1fkm", dist))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springGreenPrimary)
            }
        }
    }

    // MARK: - Logic

    /// 영구 캐시 PersistedDiscoveredCourse → GolfCourse로 변환해 로컬 목록에 병합
    private func loadPersistedCourses() {
        let fetched = (try? modelContext.fetch(FetchDescriptor<PersistedDiscoveredCourse>())) ?? []
        persistedCourses = fetched.map { $0.toGolfCourse() }
    }

    /// 완료된 라운드(isFinished == true)를 courseId / courseName 기준으로 집계.
    /// O(N) 1회 스캔 후 O(1) lookup dictionary 구성.
    private func loadRoundHistory() {
        var descriptor = FetchDescriptor<Round>()
        descriptor.predicate = #Predicate { $0.isFinished == true }
        let finished = (try? modelContext.fetch(descriptor)) ?? []

        var byId: [String: (count: Int, latest: Date)] = [:]
        var byName: [String: (count: Int, latest: Date)] = [:]

        for round in finished {
            let date = round.finishedAt ?? round.startedAt
            let cid = round.courseId
            if !cid.isEmpty {
                if let existing = byId[cid] {
                    byId[cid] = (existing.count + 1, max(existing.latest, date))
                } else {
                    byId[cid] = (1, date)
                }
            }
            let cname = round.courseName
            if !cname.isEmpty {
                if let existing = byName[cname] {
                    byName[cname] = (existing.count + 1, max(existing.latest, date))
                } else {
                    byName[cname] = (1, date)
                }
            }
        }

        historyById = byId.mapValues { RoundHistorySummary(count: $0.count, latestDate: $0.latest) }
        historyByName = byName.mapValues { RoundHistorySummary(count: $0.count, latestDate: $0.latest) }
    }

    /// courseId 우선, 없으면 courseName으로 이력 조회.
    func historySummary(for course: GolfCourse) -> RoundHistorySummary? {
        if !course.id.isEmpty, let s = historyById[course.id] { return s }
        return historyByName[course.name]
    }

    /// 검색어 변경 → 300ms debounce → 카카오 API 호출
    private func scheduleKakaoSearch(query: String) {
        kakaoSearchTask?.cancel()
        kakaoResults = []

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 1 else { return }

        kakaoSearchTask = Task {
            // 300ms debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run { isSearchingKakao = true }
            defer { Task { await MainActor.run { isSearchingKakao = false } } }

            do {
                let results = try await CourseDiscoveryService.shared.searchByKeyword(
                    query: trimmed,
                    location: userLocation
                )
                await MainActor.run { kakaoResults = results }
            } catch CourseDiscoveryError.unavailable {
                // API 키 없음 — 카카오 결과 없이 로컬만 표시
            } catch {
                // 기타 에러 — 조용히 무시
            }
        }
    }
}

// MARK: - CandidateCourseRowView

/// 다중 후보 선택 카드의 개별 row. per-item address lazy resolve를 위해 별도 View로 분리.
@MainActor
struct CandidateCourseRowView: View {
    let course: GolfCourse
    let userLocation: CLLocation?

    @State private var resolvedAddress: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.springTextPrimary)
                if let region = course.region.nilIfEmpty {
                    Text(region)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.springTextSecondary)
                }
                // 주소 표시 — DB address 우선, 없으면 lazy resolve 결과
                let displayAddress = course.address?.nilIfEmpty ?? resolvedAddress
                if let addr = displayAddress {
                    Text(addr)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.springTextSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer()
            if let userLoc = userLocation, let ch = course.clubhouse {
                let dist = haversineKm(
                    lat1: userLoc.coordinate.latitude, lng1: userLoc.coordinate.longitude,
                    lat2: ch.lat, lng2: ch.lng
                )
                Text(String(format: "%.1fkm", dist))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.springGreenPrimary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(Color.springTextSecondary)
        }
        .padding(14)
        .background(Color.springSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .task {
            if course.address?.nilIfEmpty == nil {
                resolvedAddress = await CourseAddressResolver.shared.address(for: course)
            }
        }
    }
}

// MARK: - LocalCourseRowView

/// CourseSearchSheet 로컬 결과 row. per-item address lazy resolve를 위해 별도 View로 분리.
@MainActor
struct LocalCourseRowView: View {
    let course: GolfCourse
    var history: RoundHistorySummary? = nil

    @State private var resolvedAddress: String?

    private static let historyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(course.name)
                    .foregroundStyle(Color.springTextPrimary)
                sourceBadge(for: course)
            }
            HStack(spacing: 8) {
                if !course.region.isEmpty {
                    Text(course.region)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
                if let holes = course.holesCount {
                    Text("\(holes)홀")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.springTextSecondary)
                }
            }
            // 주소 표시 — DB address 우선, 없으면 lazy resolve 결과
            let displayAddress = course.address?.nilIfEmpty ?? resolvedAddress
            if let addr = displayAddress {
                Text(addr)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.springTextSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            // 이전 라운드 이력 (isFinished 완료 라운드만)
            if let h = history {
                Text("이전 \(h.count)회 · \(Self.historyDateFormatter.string(from: h.latestDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            if course.address?.nilIfEmpty == nil {
                resolvedAddress = await CourseAddressResolver.shared.address(for: course)
            }
        }
    }

    @ViewBuilder
    private func sourceBadge(for course: GolfCourse) -> some View {
        if course.sources?.contains("kakao_persisted") == true {
            Text("발견 캐시")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.0))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Capsule())
        } else {
            Text("DB 등록")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.springGreenPrimary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Color.springGreenSecondary.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

// MARK: - String helper

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
