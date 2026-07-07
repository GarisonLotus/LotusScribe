import AppKit
import CoreText
import SwiftUI
import os

// ============================================================================
// LotusTheme — the "Lotus Bloom" brand system (DESIGN_SPEC.md).
//
// Single source of every color, font, gradient, shape, and reusable control
// used by the reskinned UI. Views must pull ALL visual values from here — no
// raw hex or ad-hoc fonts in view code (project rule). Dark is the default
// appearance; light is fully supported. Every token below is dynamic on the
// resolved NSAppearance so a single `Color` renders correctly in both.
// ============================================================================

// MARK: - Hex helpers (private — the ONLY place literals live)

private extension NSColor {
    /// Opaque color from a 24-bit `0xRRGGBB` literal.
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha)
    }
}

/// A `Color` that resolves to `dark` under a dark appearance and `light`
/// otherwise. This is how every token carries both spec variants in one value.
private func dynamicColor(dark: NSColor, light: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
    })
}

// MARK: - Color tokens (spec §2)

extension Color {
    /// Card / grouped-section fill.
    static let lotusSurface = dynamicColor(
        dark: NSColor(rgb: 0xFFFFFF, alpha: 0.045),
        light: NSColor(rgb: 0xFFFFFF))
    /// Card stroke.
    static let lotusSurfaceBorder = dynamicColor(
        dark: NSColor(rgb: 0xFFFFFF, alpha: 0.07),
        light: NSColor(rgb: 0x1E0F28, alpha: 0.08))
    /// Row separators.
    static let lotusDivider = dynamicColor(
        dark: NSColor(rgb: 0xFFFFFF, alpha: 0.06),
        light: NSColor(rgb: 0x1E0F28, alpha: 0.06))
    /// Ghost buttons, steppers, pills.
    static let lotusControlFill = dynamicColor(
        dark: NSColor(rgb: 0xFFFFFF, alpha: 0.07),
        light: NSColor(rgb: 0x9A56B8, alpha: 0.08))

    /// Headings, values.
    static let lotusTextPrimary = dynamicColor(
        dark: NSColor(rgb: 0xF6EFF9), light: NSColor(rgb: 0x241B2A))
    /// Row labels, body.
    static let lotusTextSecondary = dynamicColor(
        dark: NSColor(rgb: 0x9D93A8), light: NSColor(rgb: 0x6D6076))
    /// Hints, footnotes.
    static let lotusTextTertiary = dynamicColor(
        dark: NSColor(rgb: 0x7C7386), light: NSColor(rgb: 0x8D8096))

    /// Gradient start / waveform / mic dot.
    static let lotusAccentPink = Color(nsColor: NSColor(rgb: 0xFF5CA8))
    /// Gradient end.
    static let lotusAccentPurple = Color(nsColor: NSColor(rgb: 0xC438F0))
    /// Links, highlighted values, section-kicker text, "Granted".
    static let lotusAccentText = dynamicColor(
        dark: NSColor(rgb: 0xFF7CB9), light: NSColor(rgb: 0xB8368F))
    /// Section headers.
    static let lotusSectionLabel = dynamicColor(
        dark: NSColor(rgb: 0xCBA3DC), light: NSColor(rgb: 0x9A56B8))

    /// HUD pill fill — dark both modes (the HUD is a brand overlay, spec §2).
    static let lotusHUDFill = Color(nsColor: NSColor(rgb: 0x1E1424, alpha: 0.92))
}

// MARK: - Accent gradient (spec §2)

extension LinearGradient {
    /// Primary buttons, toggles ON, petals, checkmark chip. 90° = horizontal,
    /// #FF5CA8 → #C438F0.
    static let lotusAccent = LinearGradient(
        colors: [.lotusAccentPink, .lotusAccentPurple],
        startPoint: .leading, endPoint: .trailing)
}

// MARK: - Window background (spec §2)

private struct LotusWindowBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if scheme == .dark {
            // Radial bloom: warm magenta origin top-right, folding to near-black.
            RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(nsColor: NSColor(rgb: 0x2B1332)), location: 0),
                    .init(color: Color(nsColor: NSColor(rgb: 0x171019)), location: 0.6),
                    .init(color: Color(nsColor: NSColor(rgb: 0x171019)), location: 1),
                ]),
                center: UnitPoint(x: 0.85, y: -0.2),
                startRadius: 0, endRadius: 900)
        } else {
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(rgb: 0xFDFAFE)),
                    Color(nsColor: NSColor(rgb: 0xF5EEF7)),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension View {
    /// Fills the window behind content with the spec §2 bloom gradient.
    func lotusWindowBackground() -> some View {
        background(LotusWindowBackground().ignoresSafeArea())
    }
}

// MARK: - Typography (spec §3)

extension Font {
    /// Onboarding heroes / display headings — Chakra Petch SemiBold.
    /// Falls back to a bold system font if registration failed (Font.custom
    /// resolves to the system font automatically when the face is absent).
    static func lotusDisplay(_ size: CGFloat) -> Font {
        .custom("ChakraPetch-SemiBold", size: size)
    }
    /// Section labels — Chakra Petch Medium (uppercase/tracking applied by
    /// `LotusSectionHeader`).
    static let lotusSectionLabel = Font.custom("ChakraPetch-Medium", size: 11.5)
    /// Technical values / step kickers — SF Mono.
    static func lotusMono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
    /// Body / rows.
    static let lotusBody = Font.system(size: 13)
    /// Caption / hint.
    static let lotusCaption = Font.system(size: 11)
}

// MARK: - Font registration (spec §1 — bundle, register, fall back)

enum LotusFonts {
    private static let logger = Logger(
        subsystem: "com.garisonlotus.LotusScribe", category: "LotusFonts")

    /// Register the bundled Chakra Petch faces with CoreText at launch. Safe to
    /// call more than once; a face already registered logs and is skipped.
    /// Registration failure is non-fatal — `Font.custom` falls back to system.
    static func register() {
        for name in ["ChakraPetch-SemiBold", "ChakraPetch-Medium"] {
            guard let url = Bundle.main.url(
                forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            else {
                logger.error("font resource missing: \(name, privacy: .public) — using system fallback")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                logger.error(
                    "font register failed for \(name, privacy: .public): \(String(describing: error?.takeRetainedValue()), privacy: .public)")
            }
        }
    }
}

// MARK: - Appearance (spec §1 — dark default, user can follow the system)

/// User's chosen app appearance. Dark is the default (brand-first).
enum LotusAppearanceMode: String, CaseIterable {
    case dark, light, system

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .dark: return NSAppearance(named: .darkAqua)
        case .light: return NSAppearance(named: .aqua)
        case .system: return nil  // nil = follow the system
        }
    }
}

/// UserDefaults-backed appearance preference. Self-contained (does not touch
/// SettingsStore) so the reskin adds this one new setting without disturbing
/// the app's persistence contract.
enum LotusAppearance {
    private static let key = "appearanceMode"

    static var mode: LotusAppearanceMode {
        get {
            (UserDefaults.standard.string(forKey: key)
                .flatMap(LotusAppearanceMode.init(rawValue:))) ?? .dark
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    /// Persist `newMode` and push it onto NSApp. Main-actor: NSApp only.
    @MainActor static func set(_ newMode: LotusAppearanceMode) {
        mode = newMode
        apply()
    }

    /// Push the stored preference onto NSApp. Call at launch and on change.
    @MainActor static func apply() {
        NSApp.appearance = mode.nsAppearance
    }
}

// MARK: - Section header (spec §3)

/// Uppercase, tracked Chakra Petch Medium — replaces native section headers.
struct LotusSectionHeader: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.lotusSectionLabel)
            .tracking(1.4)  // ~+12%
            .foregroundStyle(Color.lotusSectionLabel)
    }
}

// MARK: - Card & row (spec §4)

/// 16pt-radius surface card with border (and a soft shadow in light mode).
struct LotusCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.vertical, 4)
            .background(Color.lotusSurface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
            .shadow(
                color: scheme == .light
                    ? Color(nsColor: NSColor(rgb: 0x3C1450, alpha: 0.05)) : .clear,
                radius: 10, y: 2)
    }
}

/// One settings/checklist row: leading label, trailing control, spec paddings
/// and 40pt min height. `showDivider` draws the row separator below.
struct LotusRow<Trailing: View>: View {
    let label: String
    var showDivider: Bool = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.lotusBody)
                    .foregroundStyle(Color.lotusTextSecondary)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            if showDivider {
                Rectangle()
                    .fill(Color.lotusDivider)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
        }
    }
}

// MARK: - Toggle (spec §4)

/// 38×22 capsule; gradient fill when on, controlFill when off; white 18pt knob.
struct LotusToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.lotusBody)
                .foregroundStyle(Color.lotusTextSecondary)
            Spacer(minLength: 8)
            ZStack {
                Capsule()
                    .fill(configuration.isOn
                        ? AnyShapeStyle(LinearGradient.lotusAccent)
                        : AnyShapeStyle(Color.lotusControlFill))
                    .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .offset(x: configuration.isOn ? 8 : -8)
            }
            .onTapGesture {
                if reduceMotion {
                    configuration.isOn.toggle()
                } else {
                    withAnimation(.easeOut(duration: 0.18)) { configuration.isOn.toggle() }
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Buttons (spec §4)

/// Capsule button. `.primary` = accent gradient + white semibold 12.5pt text;
/// `.ghost` = controlFill + surfaceBorder stroke.
struct LotusButtonStyle: ButtonStyle {
    enum Kind { case primary, ghost }
    let kind: Kind

    init(_ kind: Kind = .ghost) { self.kind = kind }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.white : Color.lotusTextPrimary)
            .padding(.vertical, 7)
            .padding(.horizontal, 16)
            .background {
                switch kind {
                case .primary:
                    Capsule().fill(LinearGradient.lotusAccent)
                case .ghost:
                    Capsule().fill(Color.lotusControlFill)
                        .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}
