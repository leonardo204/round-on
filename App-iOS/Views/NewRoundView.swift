import SwiftUI
import SwiftData
import CoreLocation
import Shared

// MARK: - NewRoundView
// iphone-2.2: 새 라운드 시작
// - 골프장 자동 매칭 (Haversine 3km) + 수동 검색
// - 서브코스 선택 (holesCount > 18 && subCourses 있으면)
// - 동반자 입력 (최대 4인)
// - holesCount nil이면 9/18/27/36 선택 프롬프트
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

    // 서브코스 선택
    @State private var selectedSubCourse: SubCourse?

    // holesCount nil 처리
    @State private var selectedHolesCount: Int = 18
    private let holeOptions = [9, 18, 27, 36]

    // 동반자 입력 (최대 4인)
    @State private var playerNames: [String] = ["나", "", "", ""]
    @State private var playerCount: Int = 1

    // Location
    @State private var userLocation: CLLocation?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.springSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        courseSection
                        if let course = matchedCourse {
                            if let holesCount = course.holesCount, holesCount == 0 {
                                holesPickerSection
                            } else if course.holesCount == nil {
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
                    Button(action: startRound) {
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
            .task {
                await loadCourses()
                await matchNearestCourse()
            }
            .sheet(isPresented: $showCourseSearch) {
                CourseSearchSheet(
                    courses: filteredCourses,
                    searchText: $courseSearchText,
                    onSelect: { course in
                        matchedCourse = course
                        selectedSubCourse = nil
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
                        }
                        Spacer()
                        Button("변경") {
                            showCourseSearch = true
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

    private func subCourseSelectorSection(course: GolfCourse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("코스 선택")
            let subCourses = course.subCourses ?? []
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(subCourses) { sub in
                    Button {
                        selectedSubCourse = sub
                    } label: {
                        Text(sub.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(selectedSubCourse?.name == sub.name
                                ? Color.springTextPrimary
                                : Color.springTextSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(selectedSubCourse?.name == sub.name
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
                        Text(idx == 0 ? "나" : "동반자 \(idx)")
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

    private func shouldShowSubCourseSelector(course: GolfCourse) -> Bool {
        guard let subs = course.subCourses, !subs.isEmpty else { return false }
        let holes = course.holesCount ?? selectedHolesCount
        return holes > 18
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
            // 매칭 없음 → 수동 검색 fallback
            matchError = "반경 5km 이내 골프장이 없어요. 직접 검색하세요"
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

        let holes = course.holesCount ?? selectedHolesCount

        // 플레이어 생성
        var players: [Player] = []
        for i in 0..<playerCount {
            let name = playerNames[i].isEmpty ? (i == 0 ? "나" : "동반자 \(i)") : playerNames[i]
            players.append(Player(name: name, isOwner: i == 0, order: i))
        }

        // RoundViewModel 생성 후 라운드 시작
        let vm = RoundViewModel(modelContext: modelContext)
        vm.attachWorkoutCoordinator()
        vm.startRound(
            courseId: course.id,
            courseName: course.name,
            courseSubName: selectedSubCourse?.name,
            players: players,
            holesCount: holes
        )
        roundViewModel = vm
        isPresented = false
    }
}

// MARK: - CourseSearchSheet

private struct CourseSearchSheet: View {
    let courses: [GolfCourse]
    @Binding var searchText: String
    let onSelect: (GolfCourse) -> Void
    @Environment(\.dismiss) private var dismiss

    private var filtered: [GolfCourse] {
        if searchText.isEmpty { return courses }
        return courses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { course in
                Button {
                    onSelect(course)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .foregroundStyle(Color.springTextPrimary)
                        HStack(spacing: 8) {
                            Text(course.region)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.springTextSecondary)
                            if let holes = course.holesCount {
                                Text("\(holes)홀")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.springTextSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("골프장 검색")
            .searchable(text: $searchText, prompt: "골프장 이름")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
}

// MARK: - String helper

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
