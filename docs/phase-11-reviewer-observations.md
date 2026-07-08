# Reviewer Observations — LotusScribe (Phase 11)

Numbered forward-looking items. id | item | status | sub-phase first raised.

| ID | Item | Status | Raised |
|----|------|--------|--------|
| R10A-2 | `keyName(for:)` does a linear `.first(where:)` scan of both maps per call. Fine for label rendering; revisit only if it ever lands in a per-frame path. (Carried from Phase 10; unrelated to mic selection.) | Open (inherited) | 10A |
| R10E2-1 | Onboarding Try-it hint/focus gating is IMPLICIT via the `stepIndex` switch, not a literal `stepIndex==3 &&` guard. Correct today; cheap to harden if `tryItStep` is ever reused. (Carried from Phase 10; unrelated to mic selection.) | Open (inherited) | 10E2 |
| R11A-1 | `defaultInputDevice()` calls `inputDevices()` a second full time (every device's UID/name/channel-count read again) just to map the default id → its entry. Harmless at menu-open cadence; revisit only if it ever lands in a hot path (e.g. per-frame or per-dictation). | Open | 11A |
| R11A-2 | `AudioInputMenuModel.defaultLabel` degrades to a bare "System Default" when the resolved name is nil/empty — an additive form not in spec §11A (which specified only "System Default (<name>)"); tested. Also handoff §3 uses "System Default (follow)" wording vs the spec's "(<name>)". Routed to architect for a copy round-trip. Non-blocking. | Open (→architect) | 11A |
| R11A-3 | `allDeviceIDs()` has a benign TOCTOU: device count can shrink between the size read and the data read, leaving trailing `0` (kAudioObjectUnknown) ids in the buffer. Safe today — those ids fail the downstream channel/UID/name reads and are `compactMap`-dropped — but worth a note if the read path is ever restructured. | Open | 11A |
