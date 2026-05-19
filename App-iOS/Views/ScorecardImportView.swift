import SwiftUI
import PhotosUI
import SwiftData
import Shared

// MARK: - ScorecardImportView
// 스코어카드 이미지 → OCR → 편집 → SwiftData 저장 흐름

struct ScorecardImportView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: State

    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var phase: ImportPhase = .picking
    @State private var payload: ScorecardImportPayload? = nil
    @State private var errorMessage: String? = nil
    @State private var showHelp = false
    @State private var showCoursePicker = false
    @State private var isSaving = false

    // MARK: Phase

    enum ImportPhase {
        case picking            // 사진 선택 전
        case processing         // OCR 진행 중
        case editing            // 결과 편집
        case error(String)      // 오류
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .picking:
                    pickingView
                case .processing:
                    processingView
                case .editing:
                    if let p = payload {
                        editingView(payload: p)
                    }
                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .navigationTitle("라운드 불러오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                ImportHelpView()
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            if let item = newItem {
                Task { await processPhoto(item: item) }
            }
        }
    }

    // MARK: - 사진 선택 화면

    private var pickingView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("스코어카드 사진 선택")
                    .font(.title3.weight(.semibold))
                Text("스마트스코어 앱 스코어카드 사진을\n선택하면 자동으로 인식합니다.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("사진 선택", systemImage: "photo.on.rectangle")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }

    // MARK: - OCR 진행 중 화면

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("스코어카드를 인식하고 있습니다...")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 편집 화면

    @ViewBuilder
    private func editingView(payload: ScorecardImportPayload) -> some View {
        List {
            // 부분 인식 경고 (있을 때만)
            if !payload.warnings.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("일부만 인식했어요")
                                .font(.subheadline.weight(.semibold))
                        }
                        ForEach(payload.warnings, id: \.self) { w in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(.orange)
                                Text(w.message)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("아래에서 직접 채우거나 수정한 뒤 저장해 주세요.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }

            // 골프장 섹션
            Section("골프장") {
                HStack {
                    Text("골프장명")
                    Spacer()
                    TextField("골프장명", text: Bindable(payload).courseName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                if !payload.matchedCourses.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("검색 결과")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(payload.matchedCourses.prefix(3)) { course in
                            Button {
                                payload.courseName = course.name
                                payload.courseId = course.id
                                payload.isCourseConfirmed = true
                            } label: {
                                HStack {
                                    Text(course.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if payload.courseId == course.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }

                Button("골프장 직접 검색") {
                    showCoursePicker = true
                }
                .foregroundStyle(.tint)
            }

            // 날짜/시간 섹션
            Section("날짜 / 시간") {
                DatePicker("날짜", selection: Bindable(payload).date, displayedComponents: .date)
                HStack {
                    Text("티오프 시간")
                    Spacer()
                    TextField("예: PM 01:20", text: Bindable(payload).teeOffTime)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            }

            // 코스명 섹션
            Section("코스") {
                HStack {
                    Text("전반")
                    Spacer()
                    TextField("예: 힐", text: Bindable(payload).frontCourseName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
                if payload.holeCount == 18 {
                    HStack {
                        Text("후반")
                        Spacer()
                        TextField("예: 크리크", text: Bindable(payload).backCourseName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Hole(par) 섹션
            Section("Hole") {
                parEditSection(payload: payload)
            }

            // 플레이어 섹션
            Section {
                playerEditSection(payload: payload)
            } header: {
                HStack {
                    Text("플레이어")
                    Spacer()
                    Button {
                        payload.addPlayer()
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }

            // 저장 버튼
            Section {
                Button {
                    Task { await saveRound(payload: payload) }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("라운드 저장")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentGreen)
                .disabled(!payload.isValid || isSaving)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .sheet(isPresented: $showCoursePicker) {
            CourseSearchPickerView { course in
                payload.courseName = course.name
                payload.courseId = course.id
                payload.isCourseConfirmed = true
            }
        }
        .task {
            // 골프장명 fuzzy 매칭
            await matchCourses(payload: payload)
        }
    }

    // MARK: - Hole(par) 편집

    @ViewBuilder
    private func parEditSection(payload: ScorecardImportPayload) -> some View {
        let holeCount = payload.holeCount
        VStack(spacing: 8) {
            // 전반 (1~9)
            parRow(payload: payload, start: 0, end: min(9, holeCount))
            // 후반 (10~18) — 18홀일 때만
            if holeCount > 9 {
                parRow(payload: payload, start: 9, end: holeCount)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
    }

    /// 9홀 par row (Menu picker — 컴팩트)
    @ViewBuilder
    private func parRow(payload: ScorecardImportPayload, start: Int, end: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(start..<end, id: \.self) { idx in
                VStack(spacing: 3) {
                    Text("\(idx + 1)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Menu {
                        ForEach([3, 4, 5], id: \.self) { v in
                            Button("\(v)") {
                                if payload.pars.indices.contains(idx) { payload.pars[idx] = v }
                            }
                        }
                    } label: {
                        Text("\(payload.pars.indices.contains(idx) ? payload.pars[idx] : 4)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    // MARK: - 플레이어 편집

    @ViewBuilder
    private func playerEditSection(payload: ScorecardImportPayload) -> some View {
        ForEach(0..<payload.players.count, id: \.self) { playerIdx in
            let player = payload.players[playerIdx]
            VStack(alignment: .leading, spacing: 8) {
                // 플레이어 헤더
                HStack {
                    TextField("이름", text: Binding(
                        get: { payload.players[playerIdx].name },
                        set: { payload.players[playerIdx].name = $0 }
                    ))
                    .font(.body.weight(.semibold))

                    Spacer()

                    // Owner 토글
                    Button {
                        payload.setOwner(id: player.id)
                    } label: {
                        Label(player.isOwner ? "나" : "동반자",
                              systemImage: player.isOwner ? "person.fill" : "person")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(player.isOwner ? Color.accentGreen.opacity(0.15) : Color.secondary.opacity(0.1))
                            .foregroundStyle(player.isOwner ? Color.accentGreen : Color.secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // 점수 그리드 — 9홀씩 2행 (18홀일 때), 스크롤 없음
                VStack(spacing: 6) {
                    scoreRow(payload: payload, playerIdx: playerIdx, start: 0, end: min(9, payload.holeCount))
                    if payload.holeCount > 9 {
                        scoreRow(payload: payload, playerIdx: playerIdx, start: 9, end: payload.holeCount)
                    }
                    // 합계
                    HStack {
                        Spacer()
                        Text("합계 \(payload.players[playerIdx].computedTotal)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .onDelete { offsets in
            payload.removePlayer(at: offsets)
        }
    }

    /// 9홀 점수 row — 1~9 또는 10~18 단위. 컬럼 폭 균등 분배 (스크롤 없음)
    @ViewBuilder
    private func scoreRow(payload: ScorecardImportPayload, playerIdx: Int, start: Int, end: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(start..<end, id: \.self) { holeIdx in
                let par = payload.pars.indices.contains(holeIdx) ? payload.pars[holeIdx] : 4
                let score = payload.players[playerIdx].scores.indices.contains(holeIdx)
                    ? payload.players[playerIdx].scores[holeIdx] : 0
                let diff = score - par
                VStack(spacing: 2) {
                    Text("\(holeIdx + 1)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    TextField("",
                        value: Binding(
                            get: {
                                payload.players[playerIdx].scores.indices.contains(holeIdx)
                                    ? payload.players[playerIdx].scores[holeIdx] : 0
                            },
                            set: {
                                if payload.players[playerIdx].scores.indices.contains(holeIdx) {
                                    payload.players[playerIdx].scores[holeIdx] = $0
                                }
                            }
                        ),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                    .foregroundStyle(scoreColor(diff: diff))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(scoreBackground(diff: diff))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - 오류 화면

    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("인식 실패")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("다시 시도") {
                phase = .picking
                selectedPhoto = nil
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentGreen)

            Spacer()
        }
        .padding()
    }

    // MARK: - 사진 처리

    private func processPhoto(item: PhotosPickerItem) async {
        phase = .processing
        AppLogger.ocr.info("[Import] processPhoto 시작")

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                AppLogger.ocr.error("[Import] PhotosPicker 데이터 로드 실패")
                phase = .error("이미지 로드에 실패했습니다.")
                return
            }
            AppLogger.ocr.info("[Import] 이미지 로드 OK: \(data.count) bytes, \(Int(image.size.width))x\(Int(image.size.height))")

            let result = try await ScorecardOCRService.recognize(image: image)
            let p = ScorecardImportPayload(from: result)
            payload = p
            phase = .editing
            AppLogger.ocr.info("[Import] 편집 화면 진입 (warnings \(result.warnings.count))")

        } catch let ocrError as ScorecardOCRError {
            AppLogger.ocr.error("[Import] ScorecardOCRError: \(ocrError.localizedDescription, privacy: .public)")
            phase = .error(ocrError.localizedDescription)
        } catch {
            AppLogger.ocr.error("[Import] 알 수 없는 오류: \(error.localizedDescription, privacy: .public)")
            phase = .error("오류: \(error.localizedDescription)")
        }
    }

    // MARK: - 코스 매칭

    private func matchCourses(payload: ScorecardImportPayload) async {
        guard !payload.courseName.isEmpty else { return }
        do {
            let results = try await CourseRepository.shared.search(byName: payload.courseName)
            payload.matchedCourses = Array(results.prefix(3))
            // 정확 일치가 있으면 자동 확정
            if let exact = results.first(where: { $0.name == payload.courseName }) {
                payload.courseId = exact.id
                payload.isCourseConfirmed = true
            }
        } catch {
            // 매칭 실패는 무시 (사용자가 직접 선택)
        }
    }

    // MARK: - 저장

    private func saveRound(payload: ScorecardImportPayload) async {
        guard payload.isValid else { return }
        isSaving = true
        defer { isSaving = false }

        // 1. 플레이어 생성
        var swiftDataPlayers: [Player] = []
        for (idx, ip) in payload.players.enumerated() {
            let p = Player(name: ip.name, isOwner: ip.isOwner, order: idx)
            swiftDataPlayers.append(p)
        }

        // 2. 홀 생성
        var holes: [HoleScore] = []
        for holeIdx in 0..<payload.holeCount {
            let par = payload.pars.indices.contains(holeIdx) ? payload.pars[holeIdx] : 4
            var entries: [ScoreEntry] = []
            for (pIdx, player) in swiftDataPlayers.enumerated() {
                let score = payload.players.indices.contains(pIdx)
                    && payload.players[pIdx].scores.indices.contains(holeIdx)
                    ? payload.players[pIdx].scores[holeIdx]
                    : 0
                entries.append(ScoreEntry(playerId: player.id, value: score))
            }
            holes.append(HoleScore(holeNumber: holeIdx + 1, par: par, counts: entries))
        }

        // 3. Round 생성
        let round = Round(
            date: payload.date,
            courseId: payload.courseId,
            courseName: payload.courseName,
            frontCourseName: payload.frontCourseName.isEmpty ? nil : payload.frontCourseName,
            backCourseName: payload.backCourseName.isEmpty ? nil : payload.backCourseName,
            players: swiftDataPlayers,
            holes: holes,
            isFinished: true,
            startedAt: payload.date,
            finishedAt: payload.date
        )

        modelContext.insert(round)
        try? modelContext.save()

        dismiss()
    }

    // MARK: - 스코어 색상 헬퍼

    private func scoreColor(diff: Int) -> Color {
        if diff < 0 { return .blue }
        if diff == 0 { return .primary }
        if diff == 1 { return .orange }
        return .red
    }

    private func scoreBackground(diff: Int) -> Color {
        if diff < 0 { return .blue.opacity(0.12) }
        if diff == 0 { return .secondary.opacity(0.08) }
        if diff == 1 { return .orange.opacity(0.12) }
        return .red.opacity(0.12)
    }
}

// MARK: - 도움말 화면

struct ImportHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("어떤 사진이 잘 인식되나요?") {
                    helpRow(icon: "checkmark.circle", text: "스마트스코어 앱 스코어카드 — PAR·점수 표 형식")
                    helpRow(icon: "checkmark.circle", text: "선명하고 기울지 않은 전체 화면 캡쳐")
                    helpRow(icon: "xmark.circle", text: "손글씨 스코어카드 — 인식 어려움")
                    helpRow(icon: "xmark.circle", text: "흐리거나 일부 잘린 이미지")
                }
                Section("다른 앱 스코어카드") {
                    Text("스마트스코어 외 형식도 시도됩니다. 인식 결과를 반드시 확인·수정 후 저장하세요.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Section("개인정보") {
                    Text("OCR은 기기 내부(iOS Vision)에서만 처리됩니다. 이미지나 텍스트가 외부 서버로 전송되지 않습니다.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("도움말")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func helpRow(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(icon.contains("checkmark") ? Color.accentGreen : Color.red)
    }
}

// MARK: - 골프장 검색 시트

struct CourseSearchPickerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (GolfCourse) -> Void

    @State private var searchText = ""
    @State private var results: [GolfCourse] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results) { course in
                Button {
                    onSelect(course)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name).foregroundStyle(.primary)
                        Text(course.region).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if results.isEmpty && !searchText.isEmpty && !isSearching {
                    Text("검색 결과 없음")
                        .foregroundStyle(.secondary)
                }
            }
            .searchable(text: $searchText, prompt: "골프장명 검색")
            .navigationTitle("골프장 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .onChange(of: searchText) { _, newVal in
                guard newVal.count >= 1 else { results = []; return }
                Task {
                    isSearching = true
                    results = (try? await CourseRepository.shared.search(byName: newVal)) ?? []
                    isSearching = false
                }
            }
        }
    }
}
