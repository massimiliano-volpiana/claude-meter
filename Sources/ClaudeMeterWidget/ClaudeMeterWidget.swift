import WidgetKit
import SwiftUI
import Shared

// MARK: - Timeline Entry

struct ClaudeEntry: TimelineEntry {
    let date: Date
    let limits: [UsageLimit]
    let lastUpdated: Date?
}

// MARK: - Provider

struct ClaudeMeterProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClaudeEntry {
        ClaudeEntry(date: .now,
                    limits: [
                        UsageLimit(id: "5h",     label: "5-hour limit", percent: 13, resetsAt: Date().addingTimeInterval(3 * 3600)),
                        UsageLimit(id: "weekly", label: "Weekly · all models", percent: 34, resetsAt: Date().addingTimeInterval(3 * 86400))
                    ],
                    lastUpdated: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [readEntry()], policy: .after(next)))
    }

    private func readEntry() -> ClaudeEntry {
        var limits: [UsageLimit] = []
        var updated: Date? = nil

        if let data = try? Data(contentsOf: kSharedDataURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let ts = json["last_updated"] as? Double {
                updated = Date(timeIntervalSince1970: ts)
            }
            if let arr = json["limits"] as? [[String: Any]] {
                limits = arr.compactMap { dict in
                    guard let id    = dict["id"]      as? String,
                          let label = dict["label"]   as? String,
                          let pct   = dict["percent"] as? Double else { return nil }
                    let ts = dict["resetsAt"] as? Double ?? 0
                    let date = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
                    return UsageLimit(id: id, label: label, percent: pct, resetsAt: date)
                }
            }
        }

        return ClaudeEntry(date: Date(), limits: limits, lastUpdated: updated)
    }
}

// MARK: - Widget View

struct ClaudeMeterWidgetView: View {
    var entry: ClaudeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default:           mediumView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Claude", systemImage: "speedometer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)

            if entry.limits.isEmpty {
                Spacer()
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.limits.prefix(2)) { limit in
                    limitRow(limit, compact: true)
                }
            }

            Spacer(minLength: 0)

            if let lu = entry.lastUpdated {
                Text(lu, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Claude Usage", systemImage: "speedometer")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)

            if entry.limits.isEmpty {
                Spacer()
                Text("Open the app and set up Session Key")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.limits) { limit in
                    limitRow(limit, compact: false)
                }
            }

            Spacer(minLength: 0)

            if let lu = entry.lastUpdated {
                Text("Updated \(lu, style: .offset)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.windowBackgroundColor))
    }

    // MARK: Shared row

    private func limitRow(_ limit: UsageLimit, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.label)
                    .font(.system(size: compact ? 9 : 11, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%%", limit.percent))
                    .font(.system(size: compact ? 10 : 12, weight: .bold))
                    .foregroundStyle(SegmentedBar.color(for: limit.percent))
                if !compact && !limit.resetsInText.isEmpty {
                    Text(limit.resetsInText)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            SegmentedBar(percent: limit.percent, cellHeight: compact ? 5 : 7)
        }
    }
}

// MARK: - Widget

struct ClaudeMeterWidget: Widget {
    let kind = "ClaudeMeterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeMeterProvider()) { entry in
            ClaudeMeterWidgetView(entry: entry)
        }
        .configurationDisplayName("ClaudeMeter")
        .description("Claude.ai usage limits in real time.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

struct ClaudeMeterWidget_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeMeterWidgetView(entry: ClaudeEntry(
            date: .now,
            limits: [
                UsageLimit(id: "5h",     label: "5-hour limit",      percent: 31, resetsAt: Date().addingTimeInterval(3 * 3600)),
                UsageLimit(id: "weekly", label: "Weekly · all models", percent: 39, resetsAt: Date().addingTimeInterval(3 * 86400))
            ],
            lastUpdated: .now
        ))
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
