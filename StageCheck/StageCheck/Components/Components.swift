import SwiftUI

struct MetricCard: View {
    let title: String, value: String, icon: String, tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 30, height: 30).background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            Text(value).font(.mono(.title2, weight: .bold)).foregroundStyle(Theme.text).minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(Theme.text2)
        }
        .card()
        .accessibilityElement(children: .ignore).accessibilityLabel("\(title): \(value)")
    }
}

struct StatusBadge: View {
    let text: String, color: Color
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .foregroundStyle(color).background(color.opacity(0.15), in: Capsule())
    }
    init(_ s: CheckStatus) { text = s.rawValue; color = Theme.color(s); icon = Theme.icon(s) }
    init(_ s: ShowStatus) { text = s.rawValue; color = Theme.color(s) }
    init(text: String, color: Color, icon: String? = nil) { self.text = text; self.color = color; self.icon = icon }
}

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.accent
    var body: some View {
        ZStack {
            Circle().stroke(Theme.divider, lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
            Text("\(Int((progress * 100).rounded()))%").font(.mono(.headline, weight: .bold)).foregroundStyle(Theme.text)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Progress \(Int((progress * 100).rounded())) percent")
    }
}

struct ProgressBar: View {
    let progress: Double
    var tint: Color = Theme.accent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.divider)
                Capsule().fill(tint).frame(width: g.size.width * max(0, min(progress, 1)))
            }
        }
        .frame(height: 6)
        .accessibilityElement().accessibilityLabel("\(Int((progress * 100).rounded())) percent")
    }
}

/// Segmented bar for passed / failed / skipped / pending.
struct SegmentedStatusBar: View {
    let passed: Int, failed: Int, skipped: Int, pending: Int
    var body: some View {
        let total = max(passed + failed + skipped + pending, 1)
        GeometryReader { g in
            HStack(spacing: 2) {
                ForEach(Array([(passed, Theme.success), (failed, Theme.error), (skipped, Theme.warning), (pending, Theme.divider)].enumerated()), id: \.offset) { _, s in
                    if s.0 > 0 { RoundedRectangle(cornerRadius: 3).fill(s.1).frame(width: max(4, (g.size.width - 6) * CGFloat(s.0) / CGFloat(total))) }
                }
            }
        }
        .frame(height: 10)
        .accessibilityElement().accessibilityLabel("Passed \(passed), failed \(failed), skipped \(skipped), pending \(pending)")
    }
}

struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Theme.text2)
            Spacer()
            if let action, let onAction { Button(action, action: onAction).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent) }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct EmptyStateView: View {
    let icon: String, title: String, message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 44, weight: .light)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.text)
            Text(message).font(.subheadline).foregroundStyle(Theme.text2).multilineTextAlignment(.center)
            if let actionTitle, let action { PrimaryButton(title: actionTitle, icon: "plus", action: action).frame(maxWidth: 260).padding(.top, 4) }
        }
        .padding(32).frame(maxWidth: .infinity)
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt = "Search"
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.text2)
            TextField(prompt, text: $text).foregroundStyle(Theme.text).autocorrectionDisabled().submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.text2) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct FilterChip: View {
    let title: String
    var count: Int? = nil
    let selected: Bool
    var tint: Color = Theme.accent
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 5) {
                Text(title)
                if let count { Text("\(count)").font(.mono(.caption)).opacity(0.8) }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(selected ? Theme.bg : Theme.text)
            .background(selected ? tint : Theme.card, in: Capsule())
            .overlay(Capsule().stroke(selected ? .clear : Theme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ChipBar<T: Hashable>: View {
    let items: [(T, String, Int?)]
    @Binding var selection: T
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    FilterChip(title: item.1, count: item.2, selected: selection == item.0) { selection = item.0 }
                }
            }
            .padding(.horizontal, Theme.pad)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.accent
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Label { Text(title) } icon: { if let icon { Image(systemName: icon) } }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
                .foregroundStyle(Theme.bg).background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    var tint: Color = Theme.accent
    let action: () -> Void
    var body: some View {
        Button { Haptics.tap(); action() } label: {
            Label { Text(title).lineLimit(1).minimumScaleFactor(0.8) } icon: { if let icon { Image(systemName: icon) } }
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 11)
                .foregroundStyle(tint).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Destructive confirmation dialog modifier.
struct ConfirmDialog: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    var confirmTitle = "Delete"
    let onConfirm: () -> Void
    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(confirmTitle, role: .destructive) { Haptics.warning(); onConfirm() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(message) }
    }
}

extension View {
    func confirmDialog(_ title: String, message: String, isPresented: Binding<Bool>, confirmTitle: String = "Delete", onConfirm: @escaping () -> Void) -> some View {
        modifier(ConfirmDialog(title: title, message: message, isPresented: isPresented, confirmTitle: confirmTitle, onConfirm: onConfirm))
    }
}

struct TechnicalInfoCard: View {
    let title: String
    let rows: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
            ForEach(rows, id: \.0) { r in
                HStack(alignment: .firstTextBaseline) {
                    Text(r.0).font(.subheadline).foregroundStyle(Theme.text2)
                    Spacer(minLength: 12)
                    Text(r.1.trimmed.isEmpty ? "—" : r.1).font(.mono(.subheadline, weight: .medium)).foregroundStyle(Theme.text).multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
