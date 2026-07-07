import AppKit
import SwiftUI

/// Known collisions between pickable hotkeys and macOS system shortcuts
/// (9E, D86). Pure lookup — headless-testable; the picker renders the warning
/// inline with deep links to the pane(s) that own the colliding shortcut.
/// There is NO API to reassign Apple's shortcuts from an app (D86), so the
/// most we can do is put the user one click from the right toggle.
enum HotkeyCollision {
    struct SettingsLink: Equatable {
        let label: String
        let url: String
    }

    struct Warning: Equatable {
        let message: String
        let links: [SettingsLink]
    }

    private static let keyboardPane =
        "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
    private static let siriPane =
        "x-apple.systempreferences:com.apple.Siri-Settings.extension"

    /// The collision warning for `option`, or nil when the choice is clean.
    /// Matches on the RESOLVED chord, not the spelling (R9E-2/3): a custom
    /// "f5" is the same physical key as the F5 menu pick and must warn too.
    /// F5 is claimed twice on stock macOS: the Keyboard → Dictation shortcut
    /// AND Siri's "Hold Dictation key" (live-tested: holding F5 opened Siri).
    static func warning(for option: HotkeyOption) -> Warning? {
        switch option.chord {
        case .combo(keyCode: 96, modifiers: []):
            return Warning(
                message: "F5 is claimed by macOS: the Dictation shortcut (Keyboard) and Siri's “Hold Dictation key”. Turn both off so F5 reaches LotusScribe.",
                links: [
                    SettingsLink(label: "Open Siri Settings…", url: siriPane),
                    SettingsLink(label: "Open Keyboard Settings…", url: keyboardPane),
                ])
        case .fnHold:
            return Warning(
                message: "The fn/globe key is claimed by macOS (emoji, input sources, Siri). Set “Press 🌐 key to” → “Do Nothing”.",
                links: [
                    SettingsLink(label: "Open Keyboard Settings…", url: keyboardPane)
                ])
        default:
            return nil
        }
    }
}

/// The Phase 9 hotkey picker (D85): a capsule menu of F1–F12 plus a custom
/// modifier-combo field. Writes live through `HotkeySetting.set` (persist +
/// post → live re-bind, D84). LotusTheme only. Shared by Settings and
/// onboarding — it owns its own state, seeded from the persisted hotkey.
struct HotkeyPicker: View {
    @State private var option: HotkeyOption
    @State private var customText: String

    init() {
        let opt = HotkeyOption.from(persisted: SettingsStore().hotkeyChord)
        _option = State(initialValue: opt)
        if case .custom(let string) = opt {
            _customText = State(initialValue: string)
        } else {
            _customText = State(initialValue: "")
        }
    }

    private var isCustom: Bool {
        if case .custom = option { return true }
        return false
    }

    /// Non-empty text that doesn't parse — show the hint, keep the old chord.
    private var customInvalid: Bool {
        !customText.isEmpty && HotkeyChord.parse(customText) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(1...12, id: \.self) { n in
                    Button("F\(n)") { commit(.functionKey(n)) }
                }
                Divider()
                // Reveal the custom field; commit happens once it parses.
                Button("Custom…") { option = .custom(customText) }
            } label: {
                HStack(spacing: 6) {
                    Text(isCustom ? "Custom" : option.displayLabel)
                        .font(.lotusMono(12))
                        .foregroundStyle(Color.lotusTextPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.lotusTextSecondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.lotusControlFill, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if isCustom {
                TextField("e.g. ctrl+alt+cmd+9 or fn", text: $customText)
                    .textFieldStyle(.plain)
                    .font(.lotusMono(12))
                    .foregroundStyle(Color.lotusTextPrimary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.lotusControlFill, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.lotusSurfaceBorder, lineWidth: 1))
                    .frame(maxWidth: 240)
                    .onChange(of: customText) { _, text in
                        // Live-commit only a parseable combo (D84) — partial
                        // typing keeps the previously-bound hotkey.
                        if HotkeyChord.parse(text) != nil { commit(.custom(text)) }
                    }
                if customInvalid {
                    Text("Not a valid hotkey yet — e.g. ctrl+alt+cmd+9, shift+f5, or fn")
                        .font(.lotusCaption)
                        .foregroundStyle(.orange)
                }
            }

            // 9E (D86): the selected key collides with a macOS shortcut —
            // warn inline and deep-link the pane(s) that own it.
            if let collision = HotkeyCollision.warning(for: option) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(collision.message)
                        .font(.lotusCaption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        ForEach(collision.links, id: \.url) { link in
                            Button(link.label) {
                                if let url = URL(string: link.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(LotusButtonStyle(.ghost))
                        }
                    }
                }
            }
        }
    }

    /// Persist + live re-bind (D83/D84).
    private func commit(_ newOption: HotkeyOption) {
        option = newOption
        HotkeySetting.set(newOption)
    }
}

extension HotkeyOption {
    /// Short label for menus and the HUD chip (D89): "F5" for a function key,
    /// or the resolved chord spelled out ("Command + F5") — falling back to the
    /// raw custom string when it doesn't parse yet.
    var displayLabel: String {
        switch self {
        case .functionKey(let n): return "F\(n)"
        case .custom(let string): return chord?.spelledLabel ?? string
        }
    }
}
