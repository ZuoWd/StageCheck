import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

enum Theme {
    static let bg = Color(hex: 0x0B0D12)
    static let bg2 = Color(hex: 0x131722)
    static let card = Color(hex: 0x191F2B)
    static let elevated = Color(hex: 0x202838)
    static let accent = Color(hex: 0x55B8FF)
    static let success = Color(hex: 0x32C98A)
    static let warning = Color(hex: 0xFFB84D)
    static let error = Color(hex: 0xFF5D68)
    static let text = Color(hex: 0xF3F5F9)
    static let text2 = Color(hex: 0x929BAA)
    static let divider = Color(hex: 0x2A3342)

    static let radius: CGFloat = 14
    static let spacing: CGFloat = 12
    static let pad: CGFloat = 16

    static func color(_ s: CheckStatus) -> Color {
        switch s { case .passed: return success; case .failed: return error; case .skipped: return warning; case .notChecked: return text2 }
    }
    static func icon(_ s: CheckStatus) -> String {
        switch s { case .passed: return "checkmark.circle.fill"; case .failed: return "xmark.octagon.fill"; case .skipped: return "forward.fill"; case .notChecked: return "circle.dashed" }
    }
    static func color(_ s: ShowStatus) -> Color {
        switch s { case .planning: return text2; case .preparing: return accent; case .soundcheck: return warning; case .completed: return success; case .archived: return Color(hex: 0x5D6676) }
    }
    static func color(_ t: ColorTag) -> Color {
        switch t {
        case .none: return divider; case .blue: return accent; case .green: return success; case .orange: return Color(hex: 0xFF8A3D)
        case .red: return error; case .purple: return Color(hex: 0xA98BFF); case .yellow: return Color(hex: 0xFFD84D); case .gray: return text2
        }
    }

    /// Applies dark UIKit appearance for navigation and tab bars.
    static func applyAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(bg)
        nav.shadowColor = UIColor(divider)
        nav.titleTextAttributes = [.foregroundColor: UIColor(text)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(text)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(bg2)
        tab.shadowColor = UIColor(divider)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(accent)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(bg)], for: .selected)
    }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true }
    static func tap() { guard enabled else { return }; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error() { guard enabled else { return }; UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

extension Font {
    static func mono(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font { .system(style, design: .monospaced).weight(weight) }
}

extension Date {
    var shortDate: String { formatted(date: .abbreviated, time: .omitted) }
    var dateTime: String { formatted(date: .abbreviated, time: .shortened) }
}

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Theme.bg.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
    func card(_ color: Color = Theme.card) -> some View {
        padding(Theme.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.divider.opacity(0.6), lineWidth: 0.5))
    }
    /// Dark-styled Form/List background (iOS 16+).
    func darkList() -> some View {
        scrollContentBackground(.hidden).background(Theme.bg.ignoresSafeArea())
    }
    func rowBG() -> some View { listRowBackground(Theme.card) }
}
