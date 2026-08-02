# SwiftReparto Makefile
#
# This file is an interface, not tooling. Every sortie's exit criteria — and
# every CI job — is phrased as a `make` target, so the strings below are
# defined exactly once and never restated anywhere else in the repo.
#
# SwiftPM's own `build` and `test` drivers are forbidden here and everywhere
# else in this project. All builds and tests go through `xcodebuild`. Sortie
# 1a's exit criteria grep this file for those two command strings, so do not
# reintroduce them — not even inside a comment explaining why they are banned.

# SwiftPM's auto-generated per-product schemes (`SwiftReparto`, `reparto`) have
# no test action — `xcodebuild test -scheme SwiftReparto` fails with "not
# currently configured for the test action". The `-Package` scheme is the one
# that contains every target, including the test target, so it is the only
# scheme usable for `test` / `test-ios`.
SCHEME = SwiftReparto-Package

# The executable product's own scheme. `release` and `install` build this one,
# because the `-Package` scheme's Products directory is the same but the
# per-product scheme is what a release workflow can point at unambiguously.
CLI_SCHEME = reparto
BINARY = reparto
BIN_DIR = ./bin

DESTINATION = 'platform=macOS,arch=arm64'

# Pinned to an exact OS version, never the `latest` alias — that alias does not
# resolve on these runners; xcodebuild reports it as "Unable to find a device
# matching the provided destination specifier" with **zero tests run**, which
# looks nothing like a test failure. (The exit criteria grep this file for that
# alias, so it must not appear even in a comment.)
#
# 26.5 is the org convention and the CI-verified value: SwiftEscribo pins it
# with green CI, and SwiftAcervo's `tests.yml` runs it on `macos-26`. It is
# present on this developer machine (`xcrun simctl list runtimes`) and on the
# runner image. Check that intersection with `xcrun simctl list runtimes`
# before changing this number.
#
# Defined ONCE. Sortie 3's iOS CI job calls `make test-ios` rather than
# restating this string — SwiftEscribo's iOS job failed on its very first run
# precisely because the destination was pinned in two places and only one was
# ever run locally.
IOS_DESTINATION = 'platform=iOS Simulator,name=iPhone 17,OS=26.5'

# Apple Silicon only. Intel and Rosetta are out of scope, and an accidental
# x86_64 or universal build produces a binary for a machine nobody ships on.
# Pin the arch on every invocation, never infer it.
ARCH = ARCHS=arm64 ONLY_ACTIVE_ARCH=YES

# This package has no plugins of its own, but Yams and swift-argument-parser
# carry macros; skip the interactive trust prompt so headless/CI runs don't
# stall on validation.
XCODE_FLAGS = -skipPackagePluginValidation -skipMacroValidation

DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: build test test-ios release install clean resolve format help

build:
	xcodebuild build -scheme $(SCHEME) \
	  -destination $(DESTINATION) \
	  $(XCODE_FLAGS) \
	  CODE_SIGNING_ALLOWED=NO \
	  $(ARCH)

test:
	xcodebuild test -scheme $(SCHEME) \
	  -destination $(DESTINATION) \
	  $(XCODE_FLAGS) \
	  CODE_SIGNING_ALLOWED=NO \
	  $(ARCH)

test-ios:
	xcodebuild test -scheme $(SCHEME) \
	  -destination $(IOS_DESTINATION) \
	  $(XCODE_FLAGS) \
	  COMPILER_INDEX_STORE_ENABLE=NO \
	  $(ARCH)

# Release build of the CLI + copy to ./bin. Sortie 3's release.yml runs this
# target and then tars $(BIN_DIR)/$(BINARY), so the binary's location is part
# of the contract.
release: resolve
	xcodebuild build -scheme $(CLI_SCHEME) \
	  -destination $(DESTINATION) \
	  -configuration Release \
	  $(XCODE_FLAGS) \
	  $(ARCH)
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(ls -td $(DERIVED_DATA)/SwiftReparto-*/Build/Products/Release 2>/dev/null | head -1); \
	if [ -n "$$PRODUCT_DIR" ] && [ -x "$$PRODUCT_DIR/$(BINARY)" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		echo "Installed $(BINARY) to $(BIN_DIR)/ (Release)"; \
	else \
		echo "Error: could not find $(BINARY) in $(DERIVED_DATA)/SwiftReparto-*/Build/Products/Release"; \
		exit 1; \
	fi

# Debug build of the CLI + copy to ./bin. The fast path for trying the binary
# out locally; never what a release runs.
install: resolve
	xcodebuild build -scheme $(CLI_SCHEME) \
	  -destination $(DESTINATION) \
	  $(XCODE_FLAGS) \
	  $(ARCH)
	@mkdir -p $(BIN_DIR)
	@PRODUCT_DIR=$$(ls -td $(DERIVED_DATA)/SwiftReparto-*/Build/Products/Debug 2>/dev/null | head -1); \
	if [ -n "$$PRODUCT_DIR" ] && [ -x "$$PRODUCT_DIR/$(BINARY)" ]; then \
		cp "$$PRODUCT_DIR/$(BINARY)" $(BIN_DIR)/; \
		echo "Installed $(BINARY) to $(BIN_DIR)/ (Debug)"; \
	else \
		echo "Error: could not find $(BINARY) in $(DERIVED_DATA)/SwiftReparto-*/Build/Products/Debug"; \
		exit 1; \
	fi

resolve:
	xcodebuild -resolvePackageDependencies -scheme $(SCHEME) -destination $(DESTINATION)

clean:
	xcodebuild clean -scheme $(SCHEME) -destination $(DESTINATION) $(ARCH)
	rm -rf .build
	rm -rf $(BIN_DIR)
	rm -rf $(DERIVED_DATA)/SwiftReparto-*

# Rewrites files in place, so it is never what CI runs as a gate.
format:
	swift format -i -r .

help:
	@echo "SwiftReparto — available targets:"
	@echo "  build     - Build every target for macOS (arm64)"
	@echo "  test      - Run the test suite on macOS (arm64)"
	@echo "  test-ios  - Run the test suite on the iPhone 17 simulator"
	@echo "  release   - Release build of the reparto CLI, copied to $(BIN_DIR)/"
	@echo "  install   - Debug build of the reparto CLI, copied to $(BIN_DIR)/"
	@echo "  clean     - Remove build artifacts, $(BIN_DIR)/, and DerivedData"
	@echo "  resolve   - Resolve package dependencies"
	@echo "  format    - Reformat all Swift sources in place"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "macOS destination: $(DESTINATION)"
	@echo "iOS destination:   $(IOS_DESTINATION)"
	@echo "All targets build arm64 only. Apple Silicon is the only supported arch."
