import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    let finish: () -> Void
    @State private var page = 0

    private let pages: [(String, String, String)] = [
        ("music.mic", "Prepare your show", "Create shows from templates with venue, date and engineer details."),
        ("slider.vertical.3", "Organize your input channels", "Manage inputs, stage box and console patch assignments with duplicate warnings."),
        ("checklist", "Run your line check", "Manually verify every channel, record failures and corrective actions, and retest."),
        ("doc.richtext", "Export your report", "Generate print-ready PDF reports and CSV lists, fully offline.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark()
                Spacer()
                if page < pages.count - 1 { Button("Skip") { withAnimation { page = pages.count - 1 } }.foregroundStyle(Theme.text2) }
            }
            .padding(Theme.pad)
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    VStack(spacing: 22) {
                        Spacer()
                        Image(systemName: pages[i].0).font(.system(size: 64, weight: .light)).foregroundStyle(Theme.accent)
                            .frame(width: 140, height: 140).background(Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.accent.opacity(0.3), lineWidth: 1))
                        Text(pages[i].1).font(.title.weight(.bold)).foregroundStyle(Theme.text).multilineTextAlignment(.center)
                        Text(pages[i].2).font(.body).foregroundStyle(Theme.text2).multilineTextAlignment(.center).padding(.horizontal, 32)
                        Spacer()
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            VStack(spacing: 10) {
                if page == pages.count - 1 {
                    PrimaryButton(title: "Create First Show", icon: "plus") { finish(); router.sheet = .newShow }
                    SecondaryButton(title: "Explore Sample Show", icon: "sparkles") {
                        let p = store.add(SampleData.project())
                        finish(); router.open([.show(p.id)], in: .shows)
                    }
                } else {
                    PrimaryButton(title: "Continue") { withAnimation { page += 1 } }
                }
            }
            .padding(Theme.pad)
        }
        .screenBackground()
    }
}

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform").font(.headline.weight(.bold)).foregroundStyle(Theme.accent)
            (Text("Stage").foregroundColor(Theme.text) + Text("Check").foregroundColor(Theme.accent))
                .font(.title3.weight(.heavy))
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("StageCheck")
    }
}
