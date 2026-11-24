import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    private var active: ShowProject? {
        store.projects.filter { $0.status != .archived && $0.status != .completed }.max { $0.updatedAt < $1.updatedAt }
            ?? store.projects.filter { $0.status != .archived }.max { $0.updatedAt < $1.updatedAt }
    }
    private var allChannels: [InputChannel] { store.projects.filter { $0.status != .archived }.flatMap(\.channels) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if store.projects.isEmpty { welcome } else { content }
            }
            .padding(Theme.pad)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Wordmark()
                Text("\(greeting) · \(Date().formatted(.dateTime.weekday(.wide).month().day()))")
                    .font(.subheadline).foregroundStyle(Theme.text2)
            }
            Spacer()
            Button { router.sheet = .settings } label: {
                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(Theme.text2)
                    .frame(width: 44, height: 44).background(Theme.card, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.mic").font(.system(size: 56, weight: .light)).foregroundStyle(Theme.accent).padding(.top, 30)
            Text("Welcome to StageCheck").font(.title2.weight(.bold)).foregroundStyle(Theme.text)
            Text("Plan your shows, organize input channels and patch, run manual line checks and export professional reports — all offline.")
                .font(.subheadline).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            PrimaryButton(title: "Create First Show", icon: "plus") { router.sheet = .newShow }
            SecondaryButton(title: "Explore Sample Show", icon: "sparkles") {
                let p = store.add(SampleData.project()); router.open([.show(p.id)], in: .home)
            }
        }
        .card()
    }

    @ViewBuilder private var content: some View {
        if let a = active { activeCard(a) }
        stats
        checkOverview
        quickActions
        recent
    }

    private func activeCard(_ p: ShowProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Active Show")
                StatusBadge(p.status)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.displayTitle).font(.title3.weight(.bold)).foregroundStyle(Theme.text).lineLimit(2)
                    Text(p.venue.ifEmpty("No venue")).font(.subheadline).foregroundStyle(Theme.text2)
                    Text(p.showDate.shortDate).font(.mono(.caption, weight: .medium)).foregroundStyle(Theme.text2)
                    Text("\(p.channels.count) input channels").font(.mono(.caption, weight: .medium)).foregroundStyle(Theme.accent)
                }
                Spacer()
                ProgressRing(progress: p.checkProgress, lineWidth: 8, tint: Theme.success).frame(width: 76, height: 76)
            }
            HStack(spacing: 8) {
                SecondaryButton(title: "Open") { router.open([.show(p.id)], in: .home) }
                SecondaryButton(title: "Inputs") { router.open([.show(p.id), .inputs(p.id)], in: .home) }
                PrimaryButton(title: "Check") { router.startCheck(p.id) }
            }
        }
        .card(Theme.elevated)
    }

    private var stats: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.spacing), GridItem(.flexible())], spacing: Theme.spacing) {
            MetricCard(title: "Total Shows", value: "\(store.projects.count)", icon: "music.mic", tint: Theme.accent)
            MetricCard(title: "Total Channels", value: "\(allChannels.count)", icon: "slider.vertical.3", tint: Theme.accent)
            MetricCard(title: "Passed Checks", value: "\(allChannels.filter { $0.checkStatus == .passed }.count)", icon: "checkmark.circle.fill", tint: Theme.success)
            MetricCard(title: "Open Issues", value: "\(allChannels.reduce(0) { $0 + $1.openIssues.count })", icon: "exclamationmark.triangle.fill", tint: Theme.error)
        }
    }

    private var checkOverview: some View {
        let c = allChannels
        let n = { (s: CheckStatus) in c.filter { $0.checkStatus == s }.count }
        let done = c.isEmpty ? 0 : Double(c.count - n(.notChecked)) / Double(c.count)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Line Check Overview")
                Text("\(Int((done * 100).rounded()))%").font(.mono(.headline, weight: .bold)).foregroundStyle(Theme.text)
            }
            SegmentedStatusBar(passed: n(.passed), failed: n(.failed), skipped: n(.skipped), pending: n(.notChecked))
            HStack {
                legend("Passed", n(.passed), Theme.success); Spacer()
                legend("Failed", n(.failed), Theme.error); Spacer()
                legend("Pending", n(.notChecked), Theme.text2); Spacer()
                legend("Skipped", n(.skipped), Theme.warning)
            }
        }
        .card()
    }

    private func legend(_ t: String, _ v: Int, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(v)").font(.mono(.headline, weight: .bold)).foregroundStyle(c)
            Text(t).font(.caption2).foregroundStyle(Theme.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Quick Actions")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                quick("Create Show", "plus.rectangle.fill") { router.sheet = .newShow }
                quick("Add Input", "plus.circle.fill") { if let a = active { router.sheet = .newChannel(a.id) } }.disabled(active == nil)
                quick("Line Check", "checklist") { if let a = active { router.startCheck(a.id) } else { router.tab = .check } }
                quick("Reports", "doc.text.fill") { router.tab = .reports }
            }
        }
    }

    private func quick(_ t: String, _ i: String, _ a: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); a() } label: {
            VStack(spacing: 8) {
                Image(systemName: i).font(.title3).foregroundStyle(Theme.accent)
                Text(t).font(.caption2.weight(.medium)).foregroundStyle(Theme.text).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(PressStyle())
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent Shows", action: "See All") { router.tab = .shows }
            ForEach(store.projects.sorted { $0.updatedAt > $1.updatedAt }.prefix(3)) { p in
                Button { router.open([.show(p.id)], in: .home) } label: { ShowCard(project: p) }.buttonStyle(PressStyle())
            }
        }
    }
}
