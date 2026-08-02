#!/usr/bin/env bash
#
# check-public-docs.sh — Sortie 19a's doc-comment gate (EXECUTION_PLAN.md
# Sortie 19a, task 4).
#
# WHY THIS SCRIPT EXISTS
# -----------------------
# Sortie 19a's job is to give every public declaration a doc comment stating
# the invariant it carries. A doc comment nobody re-checks drifts the moment
# the next public declaration is added without one — the whole point of a
# gate is that "add a comment" becomes a build-time fact, not a habit. This
# script fails when any `public` declaration under `Sources/` lacks a `///`
# comment immediately above it (attribute lines excepted — see below).
#
# WHAT THIS SCRIPT DOES NOT CHECK
# --------------------------------
# It checks for the *presence* of a `///` comment, not its content. A doc
# comment that restates the declaration's name rather than its invariant
# passes this gate; that judgment call is Sortie 19a's own review, not
# something a grep can verify. This script is the floor, not the ceiling.
#
# WHERE THIS RUNS
# ----------------
# This script is a step inside the existing "Lint" job in lint.yml, not a
# new job. Branch protection on this repo is frozen at exactly
# ["Test on macOS", "Test on iOS Simulator"] (Sortie 4) — Lint is not a
# required status check, and this guard deliberately does not become one. A
# missing doc comment is not the class of defect that should block a merge,
# and moving this check into a required job would make it one without
# re-PUTting branch protection to add a new context. Do not move it.
#
# ONLY Sources/ IS SCANNED. Tests/ carries no public API surface this
# guard is responsible for, and Sortie 19a's task list explicitly scopes the
# sweep to Sources/.
#
# HOW A DECLARATION IS RECOGNIZED, AND HOW FALSE POSITIVES ARE AVOIDED
# -----------------------------------------------------------------------
# A line counts as a public declaration's opening line only when, after
# stripping *leading* whitespace, it starts with the literal token `public`
# followed by one of the shapes this codebase actually uses: `struct`,
# `class`, `enum`, `protocol`, `actor`, `func`, `var`, `let`, `init`,
# `subscript`, `typealias`, `associatedtype` — optionally preceded by
# `private(set)` and/or `static`/`mutating`/`class` modifiers.
#
# This line-start requirement is what keeps a `///` comment's own prose safe:
# a doc comment sentence such as "this is public API" begins with `///`, not
# `public`, so it can never match the declaration pattern no matter what
# words follow. It is also what keeps a mid-line mention of `public` inside
# an attribute argument (there are none in this codebase, but the shape is
# `@available(*, deprecated, ...)`, never `@available(... public ...)`) from
# being mistaken for a declaration: the check runs on the whole line, and
# `public` has to be the first token.
#
# String literals are the other named risk (directive D). This codebase's
# only multi-line string literals are `CommandConfiguration`'s
# `discussion: """ ... """` blocks, and this script tracks that state
# explicitly: it counts `"""` occurrences on each line and toggles an
# in-string flag on every odd count, and while that flag is set (including
# on the line that flips it in either direction) the line participates in
# neither role below — not as a candidate declaration, and not as a
# candidate doc comment. A future help-text line that happened to start with
# the word "public" could not be mistaken for either.
#
# THE @available SHIM CASE (directive E)
# -----------------------------------------
# `CastMember.voiceDescription`'s deprecation shim puts an attribute line
# between its doc comment and the `public var` it documents:
#
#     /// ...doc comment...
#     @available(*, deprecated, renamed: "voicePrompt")
#     public var voiceDescription: String? { ... }
#
# Walking upward from a candidate declaration, this script transparently
# skips blank lines and lines whose first non-whitespace character is `@`
# (attribute lines) before checking whether the next real line is a `///`
# comment. A bare `// MARK: -` section header does NOT count as
# documentation and does not get skipped — only blank lines and attributes
# are transparent, so a declaration preceded by nothing but a MARK header is
# correctly reported as undocumented.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

FAILURES=0
DECLARATIONS_CHECKED=0

fail() {
  echo "FAIL: $1" >&2
  FAILURES=$((FAILURES + 1))
}

# A public declaration's opening line, matched against a line already
# stripped of leading whitespace by `read` (see below). Modifiers this
# codebase actually combines with `public`: `private(set)`, `static`,
# `mutating`. `class` is included for a `class func`/`class var` this
# codebase does not currently use, so the gate does not need a rewrite the
# day one appears.
DECL_REGEX='^public[[:space:]]+(private\(set\)[[:space:]]+)?(static[[:space:]]+|mutating[[:space:]]+|class[[:space:]]+)*(struct|class|enum|protocol|actor|func|var|let|init|subscript|typealias|associatedtype)([^A-Za-z0-9_]|$)'

while IFS= read -r -d '' file; do
  in_string=0
  last_kind="none"  # "doc" | "other" | "none"
  lineno=0

  # Deliberately NOT `IFS= read -r line`: leaving IFS at its default makes
  # `read` strip leading (and trailing) whitespace for us, which is exactly
  # the normalization this check needs and saves a separate trim step.
  while read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))

    # Toggle triple-quoted-string state. A line with an odd number of `"""`
    # occurrences flips it; such a line, and every line while the flag is
    # set, is excluded from both roles below.
    quote_count=$(grep -o '"""' <<<"$line" 2>/dev/null | wc -l | tr -d ' ')
    was_in_string=$in_string
    if [ $((quote_count % 2)) -ne 0 ]; then
      in_string=$((1 - in_string))
    fi
    if [ "$was_in_string" -eq 1 ] || [ "$in_string" -eq 1 ]; then
      continue
    fi

    if [ -z "$line" ]; then
      continue  # blank lines are transparent when walking upward
    fi

    if [[ "$line" == "@"* ]]; then
      continue  # attribute lines are transparent (the voiceDescription shim)
    fi

    if [[ "$line" == "///"* ]]; then
      last_kind="doc"
      continue
    fi

    if [[ "$line" =~ $DECL_REGEX ]]; then
      DECLARATIONS_CHECKED=$((DECLARATIONS_CHECKED + 1))
      if [ "$last_kind" != "doc" ]; then
        fail "${file}:${lineno}: public declaration has no preceding '///' doc comment: ${line}"
      fi
    fi

    # Any other non-blank, non-attribute, non-doc-comment line — including a
    # plain `//` comment such as a `// MARK: -` header — resets the pending
    # doc-comment state. It is real content, and it is not documentation.
    last_kind="other"
  done <"$file"
done < <(find Sources -name '*.swift' -print0)

echo ""
echo "Checked ${DECLARATIONS_CHECKED} public declaration(s) under Sources/."

if [ "$FAILURES" -ne 0 ]; then
  echo "check-public-docs: FAILED (${FAILURES} declaration(s) missing a doc comment)" >&2
  exit 1
fi

echo "check-public-docs: OK — every public declaration under Sources/ has a preceding '///' comment."
exit 0
