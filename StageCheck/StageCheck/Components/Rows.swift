import SwiftUI

struct ShowCard: View {
    let project: ShowProject
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(project.displayTitle).font(.headline).foregroundStyle(Theme.text).lineLimit(2)
                        if project.isSample { StatusBadge(text: "SAMPLE", color: Theme.warning) }
                    }
                    Text([project.artist, project.venue].filter { !$0.trimmed.isEmpty }.joined(separator: " · ").ifEmpty("No venue set"))
                        .font(.subheadline).foregroundStyle(Theme.text2).lineLimit(1)
                }
                Spacer()
                StatusBadge(project.status)
            }
            HStack(spacing: 14) {
                Label(project.showDate.shortDate, systemImage: "calendar")
                Label("\(project.channels.count) CH", systemImage: "slider.vertical.3")
                if project.openIssueCount > 0 {
                    Label("\(project.openIssueCount)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.error)
                }
            }
            .font(.mono(.caption, weight: .medium)).foregroundStyle(Theme.text2)
            ProgressBar(progress: project.checkProgress, tint: project.count(.failed) > 0 ? Theme.warning : Theme.success)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

struct ChannelRow: View {
    let channel: InputChannel
    var warn = false
    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", channel.channelNumber))
                .font(.mono(.headline, weight: .bold)).foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.elevated, in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .leading) {
                    if channel.colorTag != .none { RoundedRectangle(cornerRadius: 2).fill(Theme.color(channel.colorTag)).frame(width: 4).padding(.vertical, 6) }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: channel.inputType.icon).font(.caption).foregroundStyle(Theme.accent)
                    Text(channel.name.ifEmpty("Unnamed")).font(.body.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    if channel.phantomPowerRequired { Text("48V").font(.mono(.caption2, weight: .bold)).foregroundStyle(Theme.warning) }
                }
                Text(channel.sourceName.ifEmpty(channel.inputType.rawValue)).font(.caption).foregroundStyle(Theme.text2).lineLimit(1)
                HStack(spacing: 4) {
                    if warn || !channel.isPatchComplete { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning) }
                    Text(channel.patchSummary).foregroundStyle(channel.isPatchComplete ? Theme.text2 : Theme.warning)
                }
                .font(.mono(.caption2, weight: .medium)).lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: Theme.icon(channel.checkStatus)).font(.title3).foregroundStyle(Theme.color(channel.checkStatus))
                .accessibilityLabel(channel.checkStatus.rawValue)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { trimmed.isEmpty ? fallback : self }
}
