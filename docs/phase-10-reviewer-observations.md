# Reviewer Observations — LotusScribe (Phase 10)

Numbered forward-looking items. id | item | status | sub-phase first raised.

| ID | Item | Status | Raised |
|----|------|--------|--------|
| R10A-1 | `HotkeyPicker` menu row (line 90) still prints the literal `"Custom"` for `.custom` options, so the new spelled label surfaces only on function-key rows + the onboarding copy/HUD — not inside the Settings picker dropdown for a custom chord. If a future request wants the spelling visible there too, that call site needs its own change. | Open | 10A |
| R10A-2 | `keyName(for:)` does a linear `.first(where:)` scan of both maps per call. Fine for label rendering; revisit only if `spelledLabel` ever lands in a per-frame path (e.g. live HUD redraw). | Open | 10A |
| R10B | Clean.Renumber consistent (stepContent/progressDots 0..<4/navBar); kickers STEP 1-4 OF 4 correct; case 2 Continue always enabled, case 3 Finish keeps D67 gate + defaultAction; setupStep ScrollView+LotusCard, theme fonts only (13pt). Build green. | Clean | 10B |
| R10C | Clean. `var … = nil` on suggested models is CONFIRMED sound — a defaulted `let` is dropped from the synthesized memberwise init, so `var` is required for the named featured entries to pass values (init source-compat kept; `.all`/tests compile, 258/24 green). Speaches→whisper-large-v3, Ollama→llama3.2:3b, vLLM nil. `apply(to:)` unchanged, never touches models (asserted L102-108). Controller owns its own draft; `commitSetup()`=`draft.save()` is the sole write, `reload()` on show — D26 untouched, no per-keystroke store write.Continue commits THEN advances (ungated). `applyRecommended` prefill test asserts all 4 fields.Local field builders are byte-exact mirrors of SettingsForm's private idioms (LotusTheme only; `.orange` hint mirrors Settings). ≥12pt.Only the 4 files staged. | Clean | 10C |
