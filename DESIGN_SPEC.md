# LotusScribe — "Lotus Bloom" Design Spec

Brand-first dark UI for the LotusScribe macOS dictation app. Dark is the default appearance; light mode is supported. Visual reference mockups: `LotusScribe Bloom.dc.html` (screens 2a onboarding, 2b settings dark+light, 2c HUD states).

## 1. Brand

- **Wordmark:** "LotusScribe" set in Chakra Petch SemiBold, +6% letter spacing.
- **Lotus mark ("two-tone", chosen icon direction 1c):** three petals — a vertical center petal flanked by two petals rotated ±40°, anchored at a shared base point (`transform-origin` bottom-center). Each petal is a tall rounded shape (roughly `RoundedRectangle`/capsule with 70/30 vertical corner asymmetry — wide round top, narrow base). **Two-tone fill (1c):** left petal solid `#FF5CA8`, right petal solid `#C438F0`, center petal the accent gradient (`#FF5CA8 → #C438F0`, vertical) — all petals full opacity. The menu bar icon uses this same full-color mark (NOT a monochrome template image).

### Icon assets (chosen: variation 1c — see `LotusScribe Icons.dc.html`)

- **Menu bar status icon:** the two-tone mark, always full-color, drawn ~16×15pt (petals ≈6×11pt, border-radius 50%/70% 70% 30% 30% equivalent). `isTemplate = false`. **Listening state:** petals gain a soft magenta glow (shadow `#FF5CA8` ~55% opacity, 8pt blur) and a 5pt pink dot (`#FF5CA8`, glowing) appears to the right of the mark. **Processing:** keep the glow, pulse the dot's opacity (900ms loop). Idle: no glow, no dot.
- **App icon:** dark rounded-square (macOS squircle), background = radial bloom gradient `#2B1332` (origin ~85% x / −10% y) → `#171019` at 60%, subtle 1px inner white border at 8% opacity. Two-tone mark centered, sized ~55% of icon width. Render at all required sizes (16→512@2x); use as `NSApplication.applicationIconImage` and in onboarding hero.

## 2. Color tokens

### Dark (default)

| Token | Value | Use |
|---|---|---|
| `bgWindow` | radial gradient, `#2B1332` (top-right, ~85% x / −20% y origin) → `#171019` at 60% | window background |
| `bgHUD` | `rgba(30,20,36,0.92)` | HUD pill fill |
| `surface` | `rgba(255,255,255,0.045)` | cards / grouped sections |
| `surfaceBorder` | `rgba(255,255,255,0.07)` | card stroke |
| `divider` | `rgba(255,255,255,0.06)` | row separators |
| `textPrimary` | `#F6EFF9` | headings, values |
| `textSecondary` | `#9D93A8` | row labels, body |
| `textTertiary` | `#7C7386` | hints, footnotes |
| `accentPink` | `#FF5CA8` | gradient start, waveform, mic dot |
| `accentPurple` | `#C438F0` | gradient end |
| `accentGradient` | linear 90°, `#FF5CA8 → #C438F0` | primary buttons, toggles ON, petals, checkmark chip |
| `accentText` | `#FF7CB9` | links, highlighted values, section-kicker text, "Granted" |
| `sectionLabel` | `#CBA3DC` | section headers |
| `controlFill` | `rgba(255,255,255,0.06–0.08)` | ghost buttons, steppers, pills |

### Light

| Token | Value |
|---|---|
| `bgWindow` | linear `#FDFAFE → #F5EEF7` |
| `surface` | `#FFFFFF`, border `rgba(30,15,40,0.08)`, shadow `0 2 10 rgba(60,20,80,0.05)` |
| `divider` | `rgba(30,15,40,0.06)` |
| `textPrimary` | `#241B2A` |
| `textSecondary` | `#6D6076` |
| `textTertiary` | `#8D8096` |
| `accentText` | `#B8368F` |
| `sectionLabel` | `#9A56B8` |
| `pill` | fill `rgba(154,86,184,0.08)`, border `rgba(154,86,184,0.18)`, text `#5E3A70` |
| accent gradient | unchanged |

## 3. Typography

| Role | Font | Size / weight | Notes |
|---|---|---|---|
| Display (onboarding heroes) | **Chakra Petch** SemiBold | 38pt, line-height 1.08 | "Talk. It types." |
| Display small | Chakra Petch SemiBold | 26pt | steps 2–3 headings |
| Section label | Chakra Petch Medium | 11.5pt, UPPERCASE, +12% tracking | replaces native section headers |
| Body / rows | SF Pro (system) | 13pt | labels, descriptions |
| Caption / hint | SF Pro | 11pt | footnotes, helper text |
| Step kicker | SF Mono / JetBrains Mono | 11pt, UPPERCASE, +14% tracking | "STEP 1 OF 3" |
| Technical values | SF Mono | 12pt | endpoint URLs, model names, bundle IDs |

Bundle Chakra Petch (SIL OFL — free to embed; download from Google Fonts) in the app bundle; fall back to system if load fails.

## 4. Shape & spacing

- 4pt base grid.
- Window content padding: 28pt (onboarding), 20–22pt (settings).
- Card radius **16pt**; row padding 11pt vertical / 14pt horizontal; row min-height 40pt.
- Buttons & pills are **capsules** (full-round). Primary = accent gradient, white semibold 12.5pt text. Ghost = `controlFill` + `surfaceBorder` stroke.
- Toggle: 38×22 capsule, gradient fill when on, white 18pt knob.
- Steppers/remove: 18pt circles in `controlFill`.
- Onboarding window: 480pt wide, fixed, not resizable; settings ~560pt.
- Traffic lights native; onboarding zoom button disabled.

## 5. Screens

- **Onboarding (3 steps):** Welcome (lotus mark 52pt, kicker, hero, Skip / Get Started) → Permissions (3 rows: 26pt outlined circle check + name + description + "Granted" in mono accent) → Try it (fn keycap 54pt + live HUD preview, keyboard-settings footnote, Back / Finish). Progress: three 6pt dots, active = accentText.
- **Settings:** four sections (Speech to Text, Cleanup LLM, App Categories, Dictionary) as cards; footer Test / Cancel / Save (Save = primary gradient).
- **HUD:** floating non-activating capsule panel, bottom-center. States: Listening (mic dot + 12-bar gradient waveform + "LISTENING" + fn key chip) → Processing (3 fading dots + "Cleaning up…") → Inserted (gradient check chip + "Inserted", auto-dismiss ~900ms).
- **Menu bar:** stays native NSMenu. Full-color two-tone lotus glyph (spec §1 icon assets); glow + pink dot while listening.

## 6. Motion (moderate)

- Standard control transitions: 180ms ease-out.
- HUD appear/disappear: fade + scale 0.96→1.0, ~220ms spring (response 0.3, damping 0.8).
- Waveform bars: driven by live audio level, 90ms per-bar animation.
- Processing dots: opacity pulse 1 → .55 → .25 cycling, 900ms loop.
- State swaps inside HUD: crossfade 150ms.
- No animation on settings rows; instant.

