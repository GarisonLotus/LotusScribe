# Reviewer Observations — LotusScribe (Phase 9)

Numbered forward-looking items. Newest at bottom; drop resolved rows.

| ID | Sub-phase | Item | Status |
|----|-----------|------|--------|
| R9A-1 | 9A | Reviewed clean: `handleCombo` untouched (diff shows no edits; D30 pair-balance preserved), F1–F12 keycodes match HIToolbox kVK, `parse`/`resolved`/`HotkeyOption` logic + `persisted!` unwrap all correct. APPROVE. | Resolved |
| R9A-2 | 9A | Minor test nit: bare-digit rejection wasn't explicitly asserted. Fixed — added `"5"`/`"9"` to `parseRejectsGarbage` arguments. | Resolved |
