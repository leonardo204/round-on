import WidgetKit
import SwiftUI

struct LaunchComplication: Widget {
    let kind: String = "kr.zerolive.golf.roundon.watchkitapp.complication.launch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LaunchProvider()) { entry in
            LaunchComplicationView(entry: entry)
        }
        .configurationDisplayName("라운드온")
        .description("워치 페이스에서 라운드온 앱을 바로 실행합니다.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
