# Build recipes — see docs/phase-0-spec.md §"Makefile recipe".
.PHONY: generate build test

generate:
	xcodegen generate

build: generate
	xcodebuild -project LotusScribe.xcodeproj -scheme LotusScribe -configuration Debug build

test: generate
	xcodebuild test -project LotusScribe.xcodeproj -scheme LotusScribe -destination 'platform=macOS'

# Release recipes (D71) — dry-run clean without creds. Developer ID enters only
# here: SIGN_IDENTITY re-signs inside scripts/make-dmg.sh; NOTARY_PROFILE gates
# notarize/staple. Homebrew cask deferred (Q7-3) — needs a notarized artifact
# at a public URL first.
.PHONY: release dmg notarize staple

release: generate
	xcodebuild -project LotusScribe.xcodeproj -scheme LotusScribe -configuration Release -derivedDataPath build build

dmg: release
	./scripts/make-dmg.sh

notarize:
	@test -n "$$NOTARY_PROFILE" || { echo "make notarize: NOTARY_PROFILE is not set. Enroll in the paid Apple Developer Program, run 'xcrun notarytool store-credentials <profile>', then rerun with NOTARY_PROFILE=<profile>." >&2; exit 1; }
	@ls dist/LotusScribe-*.dmg >/dev/null 2>&1 || { echo "make notarize: no DMG in dist/ — run 'make dmg' first." >&2; exit 1; }
	xcrun notarytool submit dist/LotusScribe-*.dmg --keychain-profile "$$NOTARY_PROFILE" --wait

staple:
	@test -n "$$NOTARY_PROFILE" || { echo "make staple: NOTARY_PROFILE is not set. Enroll in the paid Apple Developer Program, run 'xcrun notarytool store-credentials <profile>', then rerun with NOTARY_PROFILE=<profile>." >&2; exit 1; }
	@ls dist/LotusScribe-*.dmg >/dev/null 2>&1 || { echo "make staple: no DMG in dist/ — run 'make dmg' first." >&2; exit 1; }
	xcrun stapler staple dist/LotusScribe-*.dmg
