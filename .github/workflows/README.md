---
type: doc
updated: 2026-08-01
status: current
---

# CI workflows

Three workflows, and three standing rules that are easy to undo by accident.

| Workflow | Trigger | Jobs |
|---|---|---|
| `tests.yml` | `pull_request` → `main`, `development` | `Test on macOS`, `Test on iOS Simulator` |
| `lint.yml` | `pull_request` → `main`, `development`; `workflow_dispatch` | `Lint` |
| `release.yml` | `release: published`; `workflow_dispatch` | `Build and Upload Binary` |

The three job names above are branch-protection contexts. Protection matches
contexts by name, so renaming a job silently removes the gate rather than
breaking it. If you rename one, update the branch protection in the same change.

> **A note on the wording below.** Three of the rules here forbid a specific
> literal string, and this repository's exit criteria enforce them by grepping
> `.github/` for exactly those strings. So the forbidden spellings are described
> rather than written out. That is not coyness — writing one down, even inside a
> comment explaining why it is banned, fails the check. The Makefile's header
> does the same thing for the `latest`-OS destination alias.

## Every job runs a `make` target, never a spelled-out `xcodebuild`

The scheme names, both destination strings, the arch pins, and the
package-plugin flags live in the `Makefile` and are defined exactly once. A
workflow that restates any of them creates a second copy that only CI ever
exercises, which is how SwiftEscribo's iOS job failed on its very first run.

If a destination stops resolving on the runner image, **fix `Makefile:44`, not
the workflow.** The iOS simulator OS is pinned there and nowhere else.

The one deliberate exception is `lint.yml`, which calls `swift format` directly.
`make format` is an in-place rewrite — as a CI gate it would lint whatever it had
just written and always pass. The `Lint` job's final step asserts the checkout
was not modified, precisely so nobody can point it back at the in-place target.

## 1. `release: published` fires for prereleases, and that is intended

SwiftReparto ships a beta line before 1.0. A prerelease tag therefore gets a
built tarball attached, exactly like a stable one. This is not an oversight and
does not want an `if:` guard on `github.event.release.prerelease`.

It is also harmless downstream: the Homebrew tap resolves versions through
`releases/latest`, which excludes prereleases, so a beta asset can never be
picked up as a formula version.

## 2. Do not notify the Homebrew tap from here, and do not add a tap formula for this repo

The organisation's Homebrew tap is **pull**-based. `intrusive-memory/homebrew-tap`
runs its reconcile workflow on a six-hour cron using only its own
`GITHUB_TOKEN`. That script iterates the formulae the tap already has and
re-resolves each one's version; it never discovers a repo that has no formula.

The push direction is dead. The pattern you may remember — a final job step that
fires a cross-repo dispatch event at the tap to regenerate a formula — needed the
organisation's deploy-token PAT, and that PAT expired and was deleted in July
2026. Any such step added here would reference a secret that no longer exists,
and would either fail the release or, worse, be papered over with
`continue-on-error` and fail silently forever.

The division of labour is: **a source repo builds its tarball and attaches it to
the release. The tap decides when to consume it.** There is no formula for
SwiftReparto during the beta; one is created at the first stable release
(EXECUTION_PLAN.md § D-6).

This is the rule most likely to be undone from muscle memory, because every
other repo in the collection used to have that dispatch step. Do not restore it.

## 3. Never redirect DerivedData from a workflow

`xcodebuild -showBuildSettings` returns nothing for SwiftPM package schemes on
this toolchain, so `make release` and `make install` locate the built binary by
globbing `~/Library/Developer/Xcode/DerivedData/SwiftReparto-*/Build/Products/<Config>`.

Passing `xcodebuild`'s custom-derived-data-path flag from a workflow makes that
glob find nothing and the target exits 1 — in a release job, long after the
change was written and reviewed. If a custom location is ever genuinely needed,
change the Makefile targets in the same commit and re-verify `make release`
locally.

## Benign log noise

`xcodebuild` on these runners emits `IDERunDestination: Supported platforms for
the buildables in the current scheme is empty` and `IDELogStore: Failed to move
log store`. Neither affects exit status. They are not worth chasing and do not
want a workaround.
