---
type: docs
feature_name: OPERATION TROUPE MARSHAL
iteration: 1
state: complete
updated: 2026-08-02
---

# TEST_CLEANUP_REPORT.md — OPERATION TROUPE MARSHAL

> **Mission** — A definable, testable scope of work. **Sortie** — An atomic agent task within it.

**Verdict: nothing pruned. No test in this suite is CI-hostile.**

## Scope

This mission created the repository, so the diff against `starting_point_commit` is the entire history and **all 241 tests were added during the mission**. Every test file was audited.

## Audit results

| Pattern | Hits | Assessment |
|---|---|---|
| Hardcoded absolute paths (`/Users/`, `/home/`) | **0** | Enforced by an exit criterion on every sortie from 12 onward |
| Network access (`URLSession`, `http://`, `NWConnection`) | **0** | The library declares no network capability |
| `sleep` / `Thread.sleep` / `asyncAfter` / `XCTWaiter` / `expectation(` | **0** | No asynchronous or timing-dependent test exists |
| Wall-clock reads (`Date()`, `Date.now`) | **0** | No test depends on the current time |
| Env-var-only gating (`ProcessInfo.environment`, `getenv`) | **0** | No test silently skips itself |
| Subprocess spawning (`Process(`, `posix_spawn`, `NSTask`) | **0** | Required by Sortie 18; the CLI is tested through its injectable sink |
| Performance blocks (`measure {`, `XCTMetric`) | **0** | No timing-sensitive assertion to flake on a shared runner |
| `write(to:)` sites | 8 | **All** under `NSTemporaryDirectory()` / `URL.temporaryDirectory` |
| Randomness (`UUID()`) | 6 | **All** naming temp directories — the correct collision-avoidance pattern, plus one explanatory comment |

Every one of the five file-writing test files declares teardown that removes its scratch directory.

## Why the fixtures are safe

`Tests/SwiftRepartoTests/Fixtures/` holds eleven pinned files loaded through `Bundle.module` via `resources: [.copy("Fixtures")]` — `.copy`, not `.process`, so no resource rule may transform bytes that are under test. Two of them (`confessions-CAST.md`, `all-fields-CAST.md`) are SHA-256 anchors. An exit criterion on Sorties 13, 14, 15, 17, and 18 verified that no test writes under `Fixtures/`.

**Three fixtures deliberately lack `type:` frontmatter** — `reject-cast-only.md`, `reject-neither.md`, `reject-no-frontmatter.md`. That absence is precisely what those tests assert. Any markdown-hygiene tool run over this repository must exclude `Tests/`.

## Strongest evidence

The suite is not merely *believed* to be CI-clean — **it ran green in CI**. Pull request #5 (`development → main`, the release PR) executed all 241 tests on `macos-26` across both `Test on macOS` and `Test on iOS Simulator`, first attempt, no retries.

Several sorties additionally ran `make test` in three or four **separate processes** to defeat per-process hash seeding, after two ordering defects (`AnyCodable` nested mappings, `voices` provider keys) were found that would have passed a single run by luck.

## Borderline cases

None.
