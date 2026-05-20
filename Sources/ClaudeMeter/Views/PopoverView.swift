import SwiftUI
import Shared

struct PopoverView: View {
    @EnvironmentObject var service: UsageService

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "speedometer")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
            Text("ClaudeMeter")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Group {
                if service.isLoading {
                    ProgressView().scaleEffect(0.65)
                } else {
                    Button { service.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Refresh")
                }
            }
            .frame(width: 24, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let err = service.errorMessage, service.limits.isEmpty {
            errorView(err)
        } else if service.limits.isEmpty && !service.isLoading {
            emptyView
        } else {
            limitsView
        }
    }

    private var limitsView: some View {
        VStack(spacing: 10) {
            ForEach(service.limits) { limit in
                limitRow(limit)
            }
        }
        .padding(12)
    }

    private func limitRow(_ limit: UsageLimit) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(format: "%.0f%%", limit.percent))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SegmentedBar.color(for: limit.percent))
            }
            SegmentedBar(percent: limit.percent)
            if !limit.resetsInText.isEmpty {
                Text("Resets \(limit.resetsInText)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "key")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Set up Session Key\nin settings")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let updated = service.lastUpdated {
                Text("Updated \(updatedText(updated))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button { openSettings() } label: {
                Image(systemName: "gear")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func updatedText(_ date: Date) -> String {
        let secs = Date().timeIntervalSince(date)
        if secs < 60 { return "just now" }
        let m = Int(secs / 60)
        if m < 60 { return "\(m)m ago" }
        let h = m / 60; let rem = m % 60
        return rem == 0 ? "\(h)h ago" : "\(h)h \(rem)m ago"
    }
}
