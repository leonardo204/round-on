import WidgetKit
import SwiftUI

struct LaunchComplicationView: View {
    let entry: LaunchEntry
    @Environment(\.widgetFamily) var family

    // ⛳ 이모지 — Apple Color Emoji 시스템 폰트, watchOS 모든 버전 안전.
    private let iconEmoji = "⛳"

    var body: some View {
        // watchOS 10+ widget은 반드시 .containerBackground 필요 (없으면 placeholder)
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            Text(iconEmoji)
                .font(.system(size: 22))
        case .accessoryCorner:
            Text(iconEmoji)
                .font(.system(size: 24))
                .widgetLabel("라운드온")
        case .accessoryInline:
            Text("\(iconEmoji) 라운드온")
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Text(iconEmoji)
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text("라운드온")
                        .font(.headline)
                    Text("탭하여 시작")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        @unknown default:
            Text(iconEmoji)
        }
    }
}
