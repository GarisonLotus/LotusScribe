import SwiftUI

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
        }
    }

    /// Persist + live re-bind (D83/D84).
    private func commit(_ newOption: HotkeyOption) {
        option = newOption
        HotkeySetting.set(newOption)
    }
}

extension HotkeyOption {
    /// Short label for menus and the HUD chip: "F5" or the raw custom string.
    var displayLabel: String {
        switch self {
        case .functionKey(let n): return "F\(n)"
        case .custom(let string): return string
        }
    }
}
