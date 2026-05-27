import SwiftUI
import SwiftData
import MapKit
import Shared

// MARK: - StatsView
// F9 라운드 통계 화면 v2 (01-SPEC §F9)
// mockup: .mockups/stats-v2.html (안 A)

struct StatsView: View {

    /// CourseRepository 인메모리 캐시 (courseId → GolfCourse lookup용)
    @State private var courseCache: [String: GolfCourse] = [:]

    /// 정규화된 코스명 → GolfCourse 인덱스 (courseId 매칭 실패 시 폴백 매칭용)
    @State private var courseNameIndex: [String: GolfCourse] = [:]

    /// alias normalize 키 → GolfCourse (courseNameIndex 와 별개로 alias 인덱스 보유)
    @State private var aliasIndex: [String: GolfCourse] = [:]

    /// 지역별 라운드 지도 카메라 위치
    @State private var mapPosition: MapCameraPosition = .automatic

    @Query(
        filter: #Predicate<Round> { $0.isFinished == true },
        sort: \Round.startedAt,
        order: .reverse
    ) private var finishedRounds: [Round]

    /// 통계 대상 라운드 배열 — 가져온 라운드 포함 전체
    private var displayedRounds: [Round] {
        finishedRounds
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.paleSageBg.ignoresSafeArea()

            if displayedRounds.isEmpty {
                emptyStateView
            } else {
                let stats = aggregateStatistics(rounds: displayedRounds)
                let regionStats = aggregateRegionStats(rounds: displayedRounds, courseFor: courseFor)
                let mapLocations = roundLocations(rounds: finishedRounds, courseFor: courseFor)
                let mappedCount = mapLocations.reduce(0) { $0 + $1.roundCount }
                let totalFinished = finishedRounds.filter { $0.isFinished }.count
                let unmatchedRoundCount = max(0, totalFinished - mappedCount)
                ScrollView {
                    VStack(spacing: 16) {
                        // ① Hero: 핸디캡 추정
                        if let hcp = stats.handicapEstimate {
                            heroSection(hcp: hcp)
                        }

                        // ② 요약 3카드
                        summarySection(stats: stats)

                        // ③ 스코어 분포
                        scoreDistributionSection(stats: stats)

                        // ④ Par별 평균 + 일관성
                        parAndConsistencySection(stats: stats)

                        // ⑤ 지역별 라운드 (NEW)
                        regionSection(stats: regionStats, locations: mapLocations, unmatchedCount: unmatchedRoundCount)

                        // ⑥ 베스트 라운드
                        bestRoundSection(stats: stats)

                        // ⑦ 최근 5라운드
                        recentSection(stats: stats)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle("통계")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // CourseRepository 캐시 로드 (지역별 라운드 카드 lookup용)
            if courseCache.isEmpty {
                if let courses = try? await CourseRepository.shared.loadAll() {
                    var cacheDict: [String: GolfCourse] = [:]
                    var nameIndexDict: [String: GolfCourse] = [:]
                    var aliasDict: [String: GolfCourse] = [:]
                    for c in courses {
                        cacheDict[c.id] = c
                        let nameKey = CourseNameMatcher.normalize(c.name)
                        if !nameKey.isEmpty && nameIndexDict[nameKey] == nil {
                            // 첫 매칭 우선 (동일 정규화 키가 여러 골프장에 걸릴 경우 첫 번째 우선)
                            nameIndexDict[nameKey] = c
                        }
                        for alias in c.aliases ?? [] {
                            let ak = CourseNameMatcher.normalize(alias)
                            if !ak.isEmpty && aliasDict[ak] == nil {
                                aliasDict[ak] = c
                            }
                        }
                    }
                    courseCache = cacheDict
                    courseNameIndex = nameIndexDict
                    aliasIndex = aliasDict
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(Color.houseGreen)
                .padding(.bottom, 4)
            Text("아직 완료된 라운드가 없어요")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            Text("라운드를 마치면 통계가 쌓여요")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSoft)
        }
    }

    // MARK: - ① Hero: 핸디캡 추정

    private func heroSection(hcp: HandicapEstimate) -> some View {
        ZStack(alignment: .topTrailing) {
            // 배경 그라디언트
            LinearGradient(
                colors: [Color(red: 0.973, green: 0.984, blue: 0.973), Color(red: 0.933, green: 0.961, blue: 0.937)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // 우상단 서클 장식
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentGreen.opacity(0.10), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .offset(x: 40, y: -40)

            VStack(alignment: .leading, spacing: 0) {
                // eyebrow + badge
                HStack {
                    Text("핸디캡 추정")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                    Spacer()
                    Text("약식 · 최근 8R 中 베스트 3R")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.inkFaint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.houseGreen.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 999)
                                .stroke(Color.houseGreen.opacity(0.12), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 999))
                }

                // 핸디캡 수치
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", hcp.index))
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(Color.houseGreen)
                        .monospacedDigit()
                    Text("HDCP")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.inkSoft)
                }
                .padding(.top, 4)

                // delta 칩
                if let delta = hcp.delta {
                    HStack(spacing: 8) {
                        let isImproved = delta < 0
                        HStack(spacing: 3) {
                            Text(isImproved ? "▼" : "▲")
                            Text(String(format: "%.1f", abs(delta)))
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isImproved ? Color.accentGreen : Color.scoreBirdie)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isImproved ? Color.accentGreen.opacity(0.10) : Color.scoreBirdie.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 999))

                        Text(isImproved ? "지난달 대비 좋아졌어요" : "지난달보다 살짝 어려웠어요")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSoft)
                    }
                    .padding(.top, 10)
                }

                // 태그라인 (dashed divider + 코멘트)
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(Color.cardBorder)
                        .frame(height: 1)
                        .padding(.vertical, 14)

                    Text(handicapCommentary(index: hcp.index))
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSoft)
                        .lineSpacing(4)
                }
                .padding(.top, 6)
            }
            .padding(20)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private func handicapCommentary(index: Double) -> String {
        if index < 17 {
            return "싱글 진입권"
        } else if index <= 22 {
            return "보기 골퍼 안정권"
        } else {
            return "꾸준히 라운드를 쌓아봐요"
        }
    }

    // MARK: - ② 요약 3카드

    private func summarySection(stats: RoundStatisticsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("요약")

            HStack(spacing: 10) {
                miniCard(
                    icon: "⛳",
                    value: "\(stats.totalRounds)",
                    unit: "회",
                    label: "총 라운드"
                )

                let recentAvg = stats.recentAverageScore ?? stats.averageScore
                let recentLabel = stats.recentAverageScore != nil ? "최근 5R 평균" : "평균 타수"
                if let avg = recentAvg {
                    miniCard(
                        icon: "📊",
                        value: String(format: "%.1f", avg),
                        unit: "타",
                        label: recentLabel
                    )
                }

                if let vsPar = stats.averageVsPar {
                    let sign = vsPar >= 0 ? "+" : ""
                    miniCard(
                        icon: "↕",
                        value: "\(sign)\(String(format: "%.1f", vsPar))",
                        unit: "",
                        label: "Even 대비"
                    )
                }
            }
        }
    }

    private func miniCard(icon: String, value: String, unit: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 16))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkSoft)
                }
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - ③ 스코어 분포

    private func scoreDistributionSection(stats: RoundStatisticsResult) -> some View {
        let dist = stats.scoreDistribution
        guard dist.totalHoles > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("스코어 분포")

                VStack(alignment: .leading, spacing: 14) {
                    // 도넛 + 범례
                    HStack(alignment: .center, spacing: 18) {
                        DonutCanvas(distribution: dist)
                            .frame(width: 112, height: 112)

                        // 범례
                        VStack(alignment: .leading, spacing: 6) {
                            legendRow(color: eagleColor, label: "이글", pct: dist.eaglePct)
                            legendRow(color: .scoreBirdie, label: "버디", pct: dist.birdiePct)
                            legendRow(color: .scoreParGreen, label: "파", pct: dist.parPct)
                            legendRow(color: .scoreBogey, label: "보기", pct: dist.bogeyPct)
                            legendRow(color: .scoreDouble, label: "더블+", pct: dist.doublePct)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // 태그 코멘트
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle()
                            .fill(Color.accentGreen)
                            .frame(width: 3)
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Text(distributionTagComment(dist: dist))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.inkPrimary)
                            .lineSpacing(4)
                            .padding(.leading, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.accentGreen.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(16)
                .background(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        )
    }

    private func legendRow(color: Color, label: String, pct: Double) -> some View {
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
            }
            Spacer()
            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
                .monospacedDigit()
        }
    }

    private func distributionTagComment(dist: ScoreDistribution) -> String {
        if dist.parPct >= 0.40 {
            return "파 골퍼 — 안정적이에요. 버디 사냥 가즈아 👀"
        } else if dist.bogeyPct >= 0.35 {
            return "보기 골퍼 — 더블+ 줄이기가 다음 미션"
        } else if dist.doublePct >= 0.30 {
            return "더블이 잦아요 — 한 홀 -1타만 줄여도 큰 변화"
        } else {
            return "이번 분기 분포 확인 — 약점 파악 먼저"
        }
    }

    private var eagleColor: Color {
        Color(hue: 0.75, saturation: 0.6, brightness: 0.6)
    }

    // MARK: - ④ Par별 평균 + 최근 흐름

    private func parAndConsistencySection(stats: RoundStatisticsResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Par별 평균 · 최근 흐름")

            HStack(alignment: .top, spacing: 0) {
                // 좌측: Par 3/4/5 바
                parAveragesColumn(parTypeAverages: stats.parTypeAverages)
                    .frame(maxWidth: .infinity)

                // 구분선
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.cardBorder)
                    .frame(width: 1)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)

                // 우측: 최근 흐름
                recentTrendColumn(trend: stats.recentTrend, sigma: stats.consistencySigma, scoreTrend: stats.scoreTrend)
                    .frame(width: 110)
            }
            .padding(16)
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }

    private func parAveragesColumn(parTypeAverages: [ParTypeAverage]) -> some View {
        VStack(spacing: 8) {
            if parTypeAverages.isEmpty {
                Text("데이터 없음")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkFaint)
            } else {
                let maxScore = parTypeAverages.map { $0.averageScore }.max() ?? 1
                ForEach(parTypeAverages, id: \.par) { item in
                    parBarRow(item: item, maxScore: maxScore)
                }
            }
        }
    }

    private func parBarRow(item: ParTypeAverage, maxScore: Double) -> some View {
        HStack(spacing: 8) {
            // Par 태그
            Text("Par \(item.par)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.houseGreen)
                .frame(width: 40)
                .padding(.vertical, 4)
                .background(Color.tableHeaderBg)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            // 바
            GeometryReader { geo in
                let ratio = maxScore > 0 ? CGFloat(item.averageScore / maxScore) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.paleSageBg)
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentGreen, Color.houseGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * ratio, height: 8)
                }
            }
            .frame(height: 8)

            // 값
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", item.averageScore))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                let sign = item.vsPar >= 0 ? "+" : ""
                Text("\(sign)\(String(format: "%.1f", item.vsPar))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.scoreBogey)
                    .monospacedDigit()
            }
        }
    }

    private func recentTrendColumn(trend: RecentTrend?, sigma: Double?, scoreTrend: [Int]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("최근 흐름")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.inkSoft)
                .kerning(0.5)

            if let t = trend {
                // 방향 화살표 + 평어
                let (directionText, directionColor) = trendDirectionLabel(t.direction)
                Text(directionText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(directionColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                // prev → current + delta
                let prevInt = Int(t.previousAverage.rounded())
                let currInt = Int(t.currentAverage.rounded())
                let (deltaText, deltaColor) = trendDeltaLabel(t.delta)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text("\(prevInt)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkSoft)
                            .monospacedDigit()
                        Text("→")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkFaint)
                        Text("\(currInt)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                            .monospacedDigit()
                    }
                    Text(deltaText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(deltaColor)
                        .monospacedDigit()
                }
                .padding(.top, 4)

                // 평균 편차 (sigma)
                if let s = sigma {
                    let sigmaInt = Int(s.rounded())
                    if sigmaInt > 0 {
                        Text("평균 ±\(sigmaInt)타")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSoft)
                            .padding(.top, 2)
                    }
                }
            } else if scoreTrend.isEmpty {
                // 데이터 없음 placeholder
                Text("최근 6R 이상\n모이면 추세를\n보여드려요")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkFaint)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } else {
                Text("—")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.inkFaint)
                Text("6R 이상 필요")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkFaint)
            }

            // 스파크라인 (항상 scoreTrend 데이터 기준)
            if scoreTrend.count >= 2 {
                SparklineView(values: scoreTrend)
                    .frame(height: 28)
                    .padding(.top, 6)
                Text("최근 10R 추이")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.inkFaint)
            }
        }
    }

    private func trendDirectionLabel(_ direction: TrendDirection) -> (String, Color) {
        switch direction {
        case .improving:  return ("↘ 좋아지는 중", Color.accentGreen)
        case .stable:     return ("→ 비슷한 흐름 유지", Color.inkSoft)
        case .worsening:  return ("↗ 어려워지는 중", Color.scoreBogey)
        }
    }

    private func trendDeltaLabel(_ delta: Int) -> (String, Color) {
        if delta < 0 {
            return ("−\(abs(delta))타", Color.accentGreen)
        } else if delta > 0 {
            return ("+\(delta)타", Color.scoreBogey)
        } else {
            return ("±0타", Color.inkSoft)
        }
    }

    // MARK: - courseFor: 5단 폴백 (courseId → 코스명 → alias exact → alias contains → areSimilar)

    private func courseFor(_ round: Round) -> GolfCourse? {
        // 1차: courseId 직접 매칭
        if let c = courseCache[round.courseId] { return c }

        // 2차: 정규화된 코스명 exact 인덱스 매칭
        let key = CourseNameMatcher.normalize(round.courseName)
        guard !key.isEmpty else { return nil }
        if let c = courseNameIndex[key] { return c }

        // 3차: alias 정규화 exact 인덱스 매칭
        if let c = aliasIndex[key] { return c }

        // 4차: alias 인덱스 양방향 contains 매칭
        for (k, c) in aliasIndex {
            if k.contains(key) || key.contains(k) {
                return c
            }
        }

        // 5차: areSimilar 선형 폴백 (name 만, 최후 수단)
        return courseCache.values.first { CourseNameMatcher.areSimilar($0.name, round.courseName) }
    }

    // MARK: - ⑤ 지역별 라운드

    @ViewBuilder
    private func regionSection(stats: [RegionStats], locations: [RoundLocation], unmatchedCount: Int = 0) -> some View {
        if !stats.isEmpty || !locations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("지역별 라운드")
                VStack(spacing: 0) {
                    // 지도 (좌표 있는 골프장이 있을 때만 표시)
                    if !locations.isEmpty {
                        NavigationLink {
                            StatsMapDetailView(locations: locations, unmatchedCount: unmatchedCount)
                        } label: {
                            locationMapView(locations: locations)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    // Top 3 row
                    if !stats.isEmpty {
                        ForEach(Array(stats.prefix(3).enumerated()), id: \.element.regionKey) { idx, item in
                            if idx > 0 { Divider().padding(.leading, 16) }
                            regionRow(item: item)
                        }
                        // 나머지 합산 row
                        if stats.count > 3 {
                            Divider().padding(.leading, 16)
                            let rest = stats.dropFirst(3)
                            let extraRegions = rest.count
                            let extraRounds = rest.reduce(0) { $0 + $1.roundCount }
                            HStack {
                                Text("외 \(extraRegions)개 지역")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkSoft)
                                Spacer()
                                Text("+\(extraRounds)회")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkSoft)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .background(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    // MARK: - 지도 뷰 (지역별 라운드 카드 상단)

    private func locationMapView(locations: [RoundLocation]) -> some View {
        Map(position: $mapPosition, interactionModes: []) {
            ForEach(locations) { loc in
                Annotation(loc.courseName, coordinate: CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)) {
                    ZStack {
                        Circle()
                            .fill(Color.scoreBirdie)
                            .frame(width: 22, height: 22)
                            .shadow(color: Color.scoreBirdie.opacity(0.3), radius: 2, x: 0, y: 1)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            // 탭 가능 힌트 — 확대 아이콘
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.inkSoft.opacity(0.5))
                .clipShape(Capsule())
                .padding(8)
        }
        .allowsHitTesting(false)
        .onAppear {
            applyMapRegion(locations: locations)
        }
        .onChange(of: locations.map(\.courseId)) { _, _ in
            applyMapRegion(locations: locations)
        }
    }

    private func applyMapRegion(locations: [RoundLocation]) {
        if locations.isEmpty {
            mapPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.8),
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 5.0)
            ))
            return
        }
        let lats = locations.map(\.lat)
        let lngs = locations.map(\.lng)
        let minLat = lats.min()!
        let maxLat = lats.max()!
        let minLng = lngs.min()!
        let maxLng = lngs.max()!
        let centerLat = (minLat + maxLat) / 2
        let centerLng = (minLng + maxLng) / 2
        let latDelta = max((maxLat - minLat) * 1.5, 1.0)
        let lngDelta = max((maxLng - minLng) * 1.5, 1.0)
        mapPosition = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)
        ))
    }

    private func regionRow(item: RegionStats) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentGreen)
            Text(item.displayName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
            Text("\(item.roundCount)회")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - ⑥ 베스트 라운드

    @ViewBuilder
    private func bestRoundSection(stats: RoundStatisticsResult) -> some View {
        if let best = stats.bestRound {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("베스트 라운드")

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(best.courseName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(formattedDate(best.date))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSoft)
                        if stats.isPersonalRecord {
                            Text("PR · 코스 최저")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.scoreBirdie)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.scoreBirdie.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 999)
                                        .stroke(Color.scoreBirdie.opacity(0.2), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 999))
                                .padding(.top, 2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(best.totalScore)")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(Color.accentGreen)
                            .monospacedDigit()
                        Text("타")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.inkSoft)
                    }
                }
                .padding(16)
                .background(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    // MARK: - ⑦ 최근 5라운드

    @ViewBuilder
    private func recentSection(stats: RoundStatisticsResult) -> some View {
        if !stats.recentEntries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("최근 \(stats.recentEntries.count)라운드")

                VStack(spacing: 0) {
                    ForEach(Array(stats.recentEntries.enumerated()), id: \.element.roundId) { idx, entry in
                        if idx > 0 {
                            Divider().padding(.leading, 16)
                        }

                        if let round = displayedRounds.first(where: { $0.id == entry.roundId }) {
                            NavigationLink {
                                RoundDetailView(round: round)
                            } label: {
                                recentRowContent(entry: entry)
                            }
                            .buttonStyle(.plain)
                        } else {
                            recentRowContent(entry: entry)
                        }
                    }
                }
                .background(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.houseGreen.opacity(0.04), radius: 6, x: 0, y: 2)
            }
        }
    }

    private func recentRowContent(entry: RecentRoundEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.courseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(formattedDateCompact(entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSoft)
            }
            Spacer()
            HStack(spacing: 10) {
                if let vp = entry.vsPar {
                    vsParPill(vsPar: vp, holeCount: entry.holeCount)
                }
                Text("\(entry.totalScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func vsParPill(vsPar: Int, holeCount: Int) -> some View {
        let sign = vsPar >= 0 ? "+" : ""
        let (fg, bg) = vsParPillColor(vsPar: vsPar, holeCount: holeCount)
        return Text("\(sign)\(vsPar)")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// 홀당 평균 vsPar 기준으로 색 분기 — 9홀/18홀 모두 의미 있는 임계값
    private func vsParPillColor(vsPar: Int, holeCount: Int) -> (Color, Color) {
        guard holeCount > 0 else {
            return (.scoreParGreen, Color.scoreParGreen.opacity(0.08))
        }
        let perHole = Double(vsPar) / Double(holeCount)
        if perHole <= 0 {
            return (.scoreBirdie, Color.scoreBirdie.opacity(0.10))        // 언더파
        } else if perHole <= 0.7 {
            return (.scoreParGreen, Color.scoreParGreen.opacity(0.08))   // 18홀 ≤ +12
        } else if perHole <= 1.5 {
            return (.scoreBogey, Color.scoreBogey.opacity(0.10))         // 18홀 ≤ +27
        } else {
            return (.scoreDouble, Color.scoreDouble.opacity(0.08))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.inkSoft)
            .textCase(.uppercase)
            .kerning(0.8)
            .padding(.leading, 4)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func formattedDateCompact(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}

// MARK: - DonutCanvas (Canvas 기반 도넛)

private struct DonutCanvas: View {
    let distribution: ScoreDistribution

    private let eagleColor = Color(hue: 0.75, saturation: 0.6, brightness: 0.6)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 7
            let lineWidth: CGFloat = 14

            // 배경 링
            let bgPath = Path { p in
                p.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
            }
            context.stroke(bgPath, with: .color(Color(white: 0.94)), style: StrokeStyle(lineWidth: lineWidth))

            let segments: [(Double, Color)] = [
                (distribution.eaglePct, eagleColor),
                (distribution.birdiePct, .scoreBirdie),
                (distribution.parPct, .scoreParGreen),
                (distribution.bogeyPct, .scoreBogey),
                (distribution.doublePct, .scoreDouble)
            ]

            var currentAngle: Double = -90
            for (pct, color) in segments {
                guard pct > 0 else { continue }
                let sweep = 360.0 * pct
                let endAngle = currentAngle + sweep
                let path = Path { p in
                    p.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(currentAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                currentAngle = endAngle
            }
        }
        .overlay(
            VStack(spacing: 1) {
                Text("\(distribution.totalHoles)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .monospacedDigit()
                Text("총 홀 수")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkSoft)
            }
        )
    }
}

// MARK: - SparklineView

private struct SparklineView: View {
    let values: [Int]

    var body: some View {
        Canvas { context, size in
            guard values.count >= 2 else { return }
            let minVal = Double(values.min() ?? 0)
            let maxVal = Double(values.max() ?? 1)
            let range = maxVal - minVal

            func point(index: Int) -> CGPoint {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let normalized = range > 0 ? (Double(values[index]) - minVal) / range : 0.5
                // 낮을수록 아래 (낮은 점수 = 좋음 = 아래), 높을수록 위
                let y = size.height * CGFloat(normalized)
                return CGPoint(x: x, y: y)
            }

            var path = Path()
            path.move(to: point(index: 0))
            for i in 1..<values.count {
                path.addLine(to: point(index: i))
            }
            context.stroke(path, with: .color(Color.accentGreen), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))

            // 마지막 점 강조
            let last = point(index: values.count - 1)
            let dotPath = Path(ellipseIn: CGRect(x: last.x - 2.4, y: last.y - 2.4, width: 4.8, height: 4.8))
            context.fill(dotPath, with: .color(Color.accentGreen))
        }
    }
}
