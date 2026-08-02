#!/usr/bin/env bash
#
# check-leaf-invariant.sh — RQ-INV-1 acceptance gate (EXECUTION_PLAN.md Sortie 16)
#
# WHY THIS SCRIPT EXISTS
# -----------------------
# RQ-INV-1 says SwiftReparto declares no dependency on any first-party
# `intrusive-memory` package, ever. That is not a style preference: SwiftPM
# detects package-level dependency cycles at *manifest load*, before a single
# line of Swift is type-checked, and there is no target-level escape from it.
# `SwiftProyecto -> SwiftEchada` is exactly that cycle in this org's own
# history. RQ-INV-1 is what makes every consumer relationship acyclic *by
# construction* rather than by discipline — nobody has to remember the rule if
# the manifest cannot express a violation of it.
#
# The standing temptation is Sortie 12 (`ProjectCastImporter`):
# `SwiftProyecto.ProjectMarkdownParser` already parses `PROJECT.md`, and reusing
# it would be the shortest path to reintroducing the exact cycle this package
# exists to make impossible. Sortie 12 parses `PROJECT.md`'s front matter
# itself, through this package's own `YAMLCoding.swift`, specifically so that
# temptation has nowhere to go. This script is what notices if someone takes
# the shortcut later, on a manifest or an import line a human reviewer might
# skim past.
#
# The second failure mode this script guards is newer and easier to miss:
# since Sortie 17/D-6, SwiftReparto ships a CLI, and the CLI's `RepartoCLICore`
# target legitimately depends on `ArgumentParser`. But the `SwiftReparto`
# *library* target must not — a consumer that only wants to read a cast list
# should not link an argument parser to do it, and `swift-argument-parser`
# leaking onto the library target is INVISIBLE in a green build: the package
# still compiles, every test still passes, and only `swift package
# dump-package`'s resolved target-dependency list (not a grep of the manifest
# text, which cannot see what SwiftPM actually resolved) exposes it.
#
# WHERE THIS RUNS
# ----------------
# This script is a step inside the existing "Test on macOS" job in
# tests.yml, not a new job. Branch protection on this repo is frozen at
# exactly ["Test on macOS", "Test on iOS Simulator"] (Sortie 4). A guard
# living in a job that is not a required status check can go red on a PR
# that still merges green — decoration, not a gate. Do not move this into a
# new job without also re-PUTting branch protection to add its context.
#
# `swift package dump-package` is a manifest-dump command, not a build — it is
# permitted here. `swift build` / `swift test` remain forbidden everywhere in
# this repository, including in this script.

set -uo pipefail

# Resolve the repository root regardless of the caller's working directory,
# so this script behaves identically run via `make`, via CI, or by hand from
# any subdirectory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

FAILURES=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

ok() {
  echo "OK:   $1"
}

# ---------------------------------------------------------------------------
# Check 1 — Package.swift names no `intrusive-memory` package (RQ-INV-1,
# acceptance criterion 9). This is the cheapest possible check and the one a
# reviewer is least likely to catch by eye in a large diff.
# ---------------------------------------------------------------------------
if grep -q 'intrusive-memory' Package.swift; then
  fail "Package.swift names an 'intrusive-memory' package. RQ-INV-1 forbids any first-party org dependency in this manifest — see the comment block at the top of this script for why (SwiftProyecto -> SwiftEchada cycle)."
else
  ok "Package.swift names no 'intrusive-memory' package (RQ-INV-1)."
fi

# ---------------------------------------------------------------------------
# Check 2 — Package.resolved holds exactly two pins, identities `yams` and
# `swift-argument-parser` (D-6). A third pin of any kind — first-party or
# not — means something is resolving that this package's two declared
# dependencies do not by themselves require, which is worth a hard stop
# rather than a shrug.
# ---------------------------------------------------------------------------
if [ ! -f Package.resolved ]; then
  fail "Package.resolved does not exist. Run 'make resolve' first."
else
  PIN_IDENTITIES="$(jq -r '.pins | map(.identity) | sort | join(",")' Package.resolved 2>/dev/null)"
  PIN_COUNT="$(jq -r '.pins | length' Package.resolved 2>/dev/null)"
  EXPECTED_IDENTITIES="swift-argument-parser,yams"

  if [ -z "${PIN_COUNT}" ]; then
    fail "Could not parse Package.resolved as JSON."
  elif [ "${PIN_COUNT}" != "2" ]; then
    fail "Package.resolved holds ${PIN_COUNT} pin(s), expected exactly 2 (yams, swift-argument-parser). D-6 caps this leaf package at two dependencies."
  elif [ "${PIN_IDENTITIES}" != "${EXPECTED_IDENTITIES}" ]; then
    fail "Package.resolved pins are [${PIN_IDENTITIES}], expected [${EXPECTED_IDENTITIES}]."
  else
    ok "Package.resolved holds exactly two pins: yams, swift-argument-parser (D-6)."
  fi
fi

# ---------------------------------------------------------------------------
# Check 3 — the `SwiftReparto` target's dependencies, read from
# `swift package dump-package` (NOT a grep of the manifest text, which cannot
# see what SwiftPM actually resolved a target's dependency list to be), are
# exactly [Yams]. This is the check that matters most now that a CLI exists:
# `ArgumentParser` leaking onto the library target is invisible in a green
# build and silently puts an argument parser in every consumer's link line.
# ---------------------------------------------------------------------------
DUMP_JSON="$(swift package dump-package 2>/dev/null)"
if [ -z "${DUMP_JSON}" ]; then
  fail "'swift package dump-package' produced no output; cannot verify target dependencies."
else
  SWIFTREPARTO_DEPS="$(echo "${DUMP_JSON}" | jq -r '
    [.targets[] | select(.name == "SwiftReparto") | .dependencies[] | (.product[0] // .byName[0])]
    | sort | join(",")
  ' 2>/dev/null)"

  if [ "${SWIFTREPARTO_DEPS}" != "Yams" ]; then
    fail "The SwiftReparto target's resolved dependencies are [${SWIFTREPARTO_DEPS}], expected exactly [Yams]. If ArgumentParser appears here, it has leaked onto the library target (D-6) — move it to RepartoCLICore."
  else
    ok "The SwiftReparto target's resolved dependencies are exactly [Yams] (D-6)."
  fi
fi

# ---------------------------------------------------------------------------
# Check 4 — `import Yams` appears only in
# Sources/SwiftReparto/YAMLCoding.swift, and `import ArgumentParser` only
# under Sources/RepartoCLICore/ and Sources/reparto/. YAMLCoding.swift is the
# one file permitted to import Yams so the dependency stays swappable behind
# a single seam; ArgumentParser is CLI plumbing and must never reach the
# library target's source files even if Check 3's manifest-level guard were
# somehow satisfied by coincidence.
# ---------------------------------------------------------------------------
EXPECTED_YAMS_FILE="Sources/SwiftReparto/YAMLCoding.swift"
YAMS_IMPORT_FILES="$(grep -rl 'import Yams' Sources/ 2>/dev/null || true)"
YAMS_IMPORT_COUNT=0
if [ -n "${YAMS_IMPORT_FILES}" ]; then
  YAMS_IMPORT_COUNT="$(echo "${YAMS_IMPORT_FILES}" | wc -l | tr -d ' ')"
fi

if [ "${YAMS_IMPORT_COUNT}" != "1" ] || [ "${YAMS_IMPORT_FILES}" != "${EXPECTED_YAMS_FILE}" ]; then
  fail "'import Yams' appears in [${YAMS_IMPORT_FILES:-<nowhere>}], expected exactly one file: ${EXPECTED_YAMS_FILE}."
else
  ok "'import Yams' appears only in ${EXPECTED_YAMS_FILE}."
fi

ARGPARSER_IMPORT_FILES="$(grep -rl 'import ArgumentParser' Sources/ 2>/dev/null || true)"
ARGPARSER_VIOLATIONS=""
if [ -n "${ARGPARSER_IMPORT_FILES}" ]; then
  while IFS= read -r f; do
    case "$f" in
      Sources/RepartoCLICore/*|Sources/reparto/*)
        ;;
      *)
        ARGPARSER_VIOLATIONS="${ARGPARSER_VIOLATIONS}${f}\n"
        ;;
    esac
  done <<< "${ARGPARSER_IMPORT_FILES}"
fi

if [ -n "${ARGPARSER_VIOLATIONS}" ]; then
  fail "'import ArgumentParser' appears outside Sources/RepartoCLICore/ and Sources/reparto/: $(echo -e "${ARGPARSER_VIOLATIONS}" | tr '\n' ' ')"
else
  ok "'import ArgumentParser' (if present) is confined to Sources/RepartoCLICore/ and Sources/reparto/."
fi

# ---------------------------------------------------------------------------
echo ""
if [ "${FAILURES}" -ne 0 ]; then
  echo "check-leaf-invariant: FAILED (${FAILURES} check(s) failed)" >&2
  exit 1
fi

echo "check-leaf-invariant: OK — RQ-INV-1 and D-6's target split both hold."
exit 0
