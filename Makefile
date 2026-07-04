# Build recipes — see docs/phase-0-spec.md §"Makefile recipe".
.PHONY: generate build test

generate:
	xcodegen generate

build: generate
	xcodebuild -project LotusScribe.xcodeproj -scheme LotusScribe -configuration Debug build

test: generate
	xcodebuild test -project LotusScribe.xcodeproj -scheme LotusScribe -destination 'platform=macOS'
