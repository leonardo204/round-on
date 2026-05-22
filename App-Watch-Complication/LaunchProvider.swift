import WidgetKit
import SwiftUI

struct LaunchEntry: TimelineEntry {
    let date: Date
}

struct LaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> LaunchEntry {
        LaunchEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (LaunchEntry) -> Void) {
        completion(LaunchEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LaunchEntry>) -> Void) {
        let entry = LaunchEntry(date: Date())
        let next = Date().addingTimeInterval(60 * 60 * 24)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
