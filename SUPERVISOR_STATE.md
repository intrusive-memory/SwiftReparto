---
type: supervisor-state
feature_name: OPERATION TROUPE MARSHAL
iteration: 1
---

# SUPERVISOR_STATE.md — OPERATION TROUPE MARSHAL

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Metadata

- Operation: **OPERATION TROUPE MARSHAL**
- Iteration: 1
- Plan: `EXECUTION_PLAN.md`
- Project root: `/Users/stovak/Projects/package-collection/pkg/SwiftReparto`
- Started at: 2026-08-02T01:24:14Z
- Starting point commit: **none** — the SwiftReparto git repository is itself a deliverable (Sortie 1 runs `git init`; Sortie 1a makes the first commit)
- Mission branch: **`main`** (created by Sortie 1) — no supervisor mission branch, see D-SUP-1
- max_retries: 3
- Pre-build clean: skipped (no `Package.swift` and no `*.xcodeproj` at mission start — nothing to clean)
- Dependency graph: untouched (no floor bumps, no `Package.resolved` deletion, no SPM cache clear)

---

## Plan Summary

- Work units: 6
- Total sorties: 22
- Dependency structure: layers (0 → 5, strict gates)
- Dispatch mode: dynamic (no dispatch template in the plan)
- Critical path: 20 sorties
- Concurrency ceiling: 1 supervising agent + 2 sub-agents (working-tree bound, not graph bound)

## Work Units

| Name | Directory | Layer | Sorties | Sortie IDs | Dependencies |
|------|-----------|-------|---------|-----------|-------------|
| WU-1 Repository Buildout | `.` | 0 | 5 | 1, 1a, 2, 3, 4 | none |
| WU-2 Core Model | `Sources/SwiftReparto/` | 1 | 3 | 5, 6, 7 | WU-1 |
| WU-3 Parse, Serialize, Import | `Sources/SwiftReparto/` | 2 | 5 | 8, 9, 10, 11, 12 | WU-2 |
| WU-4 Acceptance Gates | `Tests/`, `.github/` | 3 | 4 | 13, 14, 15, 16 | WU-3 |
| WU-5 CLI | `Sources/RepartoCLICore/`, `Sources/reparto/` | 4 | 2 | 17, 18 | WU-4 |
| WU-6 Beta Release | `.` | 5 | 3 | 19, 19a, 20 | WU-5 |

---

## Work Unit State

### WU-1 Repository Buildout
- Work unit state: RUNNING
- Current sortie: 2 of 5 (IDs: 1 ✅, 1a ✅, **2 — PARTIAL, continuation dispatched**, 3, 4)
- Sortie state: PARTIAL → DISPATCHED (continuation)
- Sortie type: code
- Model: sonnet
- Complexity score: 11
- Attempt: 1 of 3 — **not incremented**; partial work is progress, not failure
- Last verified: **Sortie 1a COMPLETED** — all 7 exit criteria re-verified by the supervisor independently of the agent's report (commit `5c5da3d` is the sole commit; `git status --porcelain` empty; both forbidden greps return 0; `IOS_DESTINATION` defined once at line 44 as `'platform=iOS Simulator,name=iPhone 17,OS=26.5'`; `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` pinned; all nine targets present — build, test, test-ios, release, install, resolve, clean, format, help; `bin` ignored; `Package.resolved` tracked; 13 files tracked, nothing from `.build/` or `bin/`).
- Notes: Repo now has its build interface and its recovery point. Every later exit criterion phrased as a `make` target has something real to call.

#### Sortie 1 — closed
- Sortie state: COMPLETED
- Model: opus / score 21 / attempt 1 of 3
- Deviation accepted: built via raw `xcodebuild` rather than XcodeBuildMCP (see D-SUP-2).

#### Sortie 1a — closed
- Sortie state: COMPLETED
- Model: opus / score 19 / attempt 1 of 3
- Commit: `5c5da3d` — `feat: initial package scaffold, build interface, and license`
- Carried forward: `release`/`install` locate the built binary by globbing `DerivedData/SwiftReparto-*/Build/Products/<Config>` (newest dir wins, `-x` check before copy) because `xcodebuild -showBuildSettings` emits nothing for SPM package schemes here. **If Sortie 3's `release.yml` runs `xcodebuild` with a non-default `-derivedDataPath`, both targets break.** Sortie 3 must either leave DerivedData at its default or fix these two targets.
- Carried forward: `.gitignore` uses `/bin/`, not the plan's `./bin/` — git does not honor a leading `./` in ignore patterns, and `/bin/` is what makes `git check-ignore -q bin` pass. The plan text is wrong here, harmlessly.
- Carried forward: benign `xcodebuild` noise on every package-scheme invocation (`IDERunDestination: Supported platforms … is empty`, `IDELogStore: Failed to move log store`). Neither affects exit status. Expect them in CI logs; do not chase them.

### WU-2 Core Model
- Work unit state: NOT_STARTED
- Current sortie: 5 of 3 sorties (IDs: 5, 6, 7)
- Sortie state: PENDING
- Attempt: 0 of 3
- Notes: Gated on WU-1 COMPLETED (layer 0 → 1).

### WU-3 Parse, Serialize, Import
- Work unit state: NOT_STARTED
- Current sortie: 8 of 5 sorties (IDs: 8, 9, 10, 11, 12)
- Sortie state: PENDING
- Attempt: 0 of 3
- Notes: Gated on WU-2 COMPLETED. Parallel Group 1 (Sorties 11 + 12) opens after Sortie 10.

### WU-4 Acceptance Gates
- Work unit state: NOT_STARTED
- Current sortie: 13 of 4 sorties (IDs: 13, 14, 15, 16)
- Sortie state: PENDING
- Attempt: 0 of 3
- Notes: Gated on WU-3 COMPLETED. Parallel Group 2 (Sortie 15 fixtures + Sortie 16 script) opens after Sortie 13.

### WU-5 CLI
- Work unit state: NOT_STARTED
- Current sortie: 17 of 2 sorties (IDs: 17, 18)
- Sortie state: PENDING
- Attempt: 0 of 3
- Notes: Gated on WU-4 COMPLETED.

### WU-6 Beta Release
- Work unit state: NOT_STARTED
- Current sortie: 19 of 3 sorties (IDs: 19, 19a, 20)
- Sortie state: PENDING
- Attempt: 0 of 3
- Notes: Gated on WU-5 COMPLETED. Supervising agent only (git, `gh`, release APIs).

---

## Active Agents

| Work Unit | Sortie | Sortie State | Attempt | Model | Complexity Score | Task ID | Dispatched At |
|-----------|--------|-------------|---------|-------|-----------------|---------|---------------|
| WU-1 | 1 | COMPLETED | 1/3 | opus | 21 | a9c37ce6e07657bdb | 2026-08-02T01:24:14Z |
| WU-1 | 1a | COMPLETED | 1/3 | opus | 19 | a7c6f732dbc35f2e1 | 2026-08-02T01:35Z |
| WU-1 | 2 | PARTIAL | 1/3 | sonnet | 11 | a1b1c3abab6f5076a | 2026-08-02T01:48Z |
| WU-1 | 2 (cont.) | DISPATCHED | 1/3 | sonnet | 11 | (pending) | 2026-08-02T02:05Z |

---

## Decisions Log

| Timestamp | Work Unit | Sortie | Decision | Rationale |
|-----------|-----------|--------|----------|-----------|
| 2026-08-02T01:24:14Z | — | — | THE RITUAL: **OPERATION TROUPE MARSHAL** | Generated with haiku per the naming sub-skill. Validated: `OPERATION` prefix, ALL CAPS, 2 words. |
| 2026-08-02T01:24:14Z | — | — | **D-SUP-1: no supervisor mission branch created** | `pkg/` is gitignored by the enclosing `package-collection` repo, so `git rev-parse HEAD` inside `pkg/SwiftReparto` resolves to *package-collection*'s HEAD (`dc38325`). Creating `mission/troupe-marshal/01` there would branch the wrong repository and place the mission's commits nowhere near the code. The SwiftReparto repository is itself a deliverable: Sortie 1 runs `git init`, Sortie 1a makes the first commit, Sortie 3 establishes the `main`/`development` topology. There is no pre-mission commit to roll back to — the rollback point for this mission is "remove the working directory and the GitHub repo." Branch topology for this mission is therefore governed by the plan (Sortie 3), not by the supervisor. |
| 2026-08-02T01:24:14Z | — | — | Pre-build clean **skipped** | No `Package.swift` and no `*.xcodeproj` exist at mission start — the manifest is Sortie 1's deliverable. Nothing to clean. Dependency graph untouched. |
| 2026-08-02T01:24:14Z | WU-1 | 1 | Model: **opus** | Complexity score 21 = task complexity 7 (≈20–35 turns, 5 files) + ambiguity 0 (exit criteria fully machine-verifiable) + foundation 10 (foundation sortie, 21 dependents) + risk 4 (unverified Yams/toolchain combination). Also hits the **Force Opus** override: foundation_score = 1 AND dependency_depth ≥ 5. |
| 2026-08-02T01:24:14Z | WU-1 | 1 | Sortie 1 agent is authorized to **build**, but **not to commit** | The plan's "sub-agents never build" rule exists because two agents committing in one working tree collide (Parallelism Structure). Sortie 1 runs alone, so that rationale does not apply, and Sortie 1's central deliverable — the AR-1 Yams probe — *is* a build. Committing is still withheld: the first commit is Sortie 1a's deliverable and its recovery point. |
| 2026-08-02T01:35Z | WU-1 | 1 | **Sortie 1 COMPLETED** — AR-1 cleared | Yams 6.2.2 (tools 5.7, vendored C target `CYaml`) builds and round-trips clean under tools 6.2 / `.v26` / `swiftLanguageModes: [.v6]` / strict concurrency, on macOS and iOS Simulator. SwiftPM compiled Yams at its own `arm64-apple-macos12.0` floor while our targets compiled at `arm64-apple-macos26.0` — the dependency never has to satisfy our floor, which is exactly why the probe passed. **D-1 stands.** None of the three forbidden workarounds was applied. All exit criteria re-verified by the supervisor. |
| 2026-08-02T01:35Z | WU-1 | 1 | **D-SUP-2: raw `xcodebuild` accepted in place of XcodeBuildMCP** | XcodeBuildMCP is **not connected in this session** — the supervisor independently confirmed no XcodeBuild tools exist in the deferred-tool roster. The plan mandates XcodeBuildMCP for Sortie 1 only, because Sortie 1 predates the Makefile. The agent used raw `xcodebuild` and correctly did **not** fall back to the actually-forbidden `swift build`/`swift test`. From Sortie 1a onward every build goes through `make`, which shells to `xcodebuild` anyway — so this deviation is confined to Sortie 1 and leaves no residue. Artifacts on disk are identical either way. |
| 2026-08-02T01:35Z | — | — | **D-SUP-3: `test-ios` pins `OS=26.5`; the agent's `OS=26.0` recommendation is REJECTED** | Sortie 1 recommended pinning `OS=26.0` on the speculation that the `macos-26` runner image ships only iOS 26.0/26.1. **Refuted by evidence.** `SwiftAcervo/.github/workflows/tests.yml` spells out `OS=26.5` and its `Tests` workflow passed on `macos-26` on 2026-08-01 — the runner has 26.5. `SwiftEscribo/Makefile` also pins `IOS_DESTINATION = 'platform=iOS Simulator,name=iPhone 17,OS=26.5'` with green CI. 26.5 is therefore both the org convention and the CI-verified value. Sortie 1a pins `'platform=iOS Simulator,name=iPhone 17,OS=26.5'`. |
| 2026-08-02T02:05Z | WU-1 | 2 | **Sortie 2 → PARTIAL.** All 10 exit criteria pass; the document is nonetheless self-contradictory | Commit `b911a7e`. Every criterion verified independently by the supervisor and every one passes. But the criteria are greps for specific strings, and four passages that contradict the amendments are not any of those strings. `REQUIREMENTS.md:15` still reads *"Ships as a Swift **library** only. No CLI, no GUI…"* — the exact position D-6 reverses, and criterion 6 misses it because it greps for `No CLI target`, not `No CLI`. `REQUIREMENTS.md:17` and `README.md:15` still carry a **"Status: pre-alpha / design. This repo currently contains design docs only"** callout, two lines below the `status: beta` frontmatter the sortie itself just wrote, and now factually false — the repo has a manifest, sources, tests, and a Makefile. `README.md:13` repeats the library-only claim. Task 8 asked for one status value "in both files"; changing frontmatter alone did not achieve that. **This is incomplete execution of tasks 6 and 8, not scope creep**, so it is a continuation rather than a new sortie. |
| 2026-08-02T02:05Z | WU-1 | 2 | Continuation also fixes `REQUIREMENTS.md:157` | §3.2's `CastMember` fields table still declares `` | `appearance` | `Appearance?` | **New, reserved.** See §3.3 | `` while §3.3 (as amended) says `Appearance` "is not defined as a type in the beta, and `appearance` is not a declared `CodingKey`". **Sortie 6 implements `CastMember` from that table** — left alone it would declare an `Appearance?` field that D-3 forbids and that no later gate greps for. The Sortie 2 agent flagged this and correctly declined to touch it under the plan's "make exactly these and nothing else" directive; the supervisor is widening the authorization because the downstream consequence is concrete. |
| 2026-08-02T02:05Z | WU-1 | 2 | Agent catch recorded: **the plan undercounted the dependency rename's blast radius** | RQ-INV-1's prose carried a second, unlisted `marcprux/universal` reference (*"The only permitted dependency is marcprux/universal for YAML (RQ-16)"*). The plan's task list named only RQ-16. The agent found it because exit criterion 1 is a whole-document grep and updated it consistently with D-1/D-6. Good catch — without it the sortie would have failed its own first criterion. |
| 2026-08-02T01:48Z | WU-1 | 1a | **Sortie 1a COMPLETED** | Commit `5c5da3d`. All 7 exit criteria re-verified by the supervisor. Build interface established; `IOS_DESTINATION` defined once per D-SUP-3. |
| 2026-08-02T01:48Z | — | — | **Plan defect recorded (for the brief): two Sortie 1a exit criteria are blind to intent** | `grep -cE 'swift (build\|test)' Makefile` and `grep -c 'OS=latest' Makefile` scan the whole file, comments included. The agent's first draft failed both — not in any recipe, but in header comments *explaining that those strings are banned*. It reworded the comments to pass. The criteria are therefore satisfiable only by a Makefile that cannot document its own prohibitions in the obvious words. Harmless here, but any later sortie adding prose to the Makefile must re-run both greps. Worth tightening to a recipe-only match in a future plan revision. |
| 2026-08-02T01:48Z | — | — | **D-SUP-4: the supervisor commits `SUPERVISOR_STATE.md` before each dispatch** | Sortie 1a's commit tracked `SUPERVISOR_STATE.md`, so every supervisor state write now dirties the working tree. Left alone, a later sortie committing with a broad `git add` would sweep a half-written state file into its commit, and any sortie gated on a clean tree would fail through no fault of its own. The supervisor therefore commits its own state file as bookkeeping immediately before dispatching, so every sortie starts from a clean tree. These commits touch `SUPERVISOR_STATE.md` only. |
| 2026-08-02T01:48Z | WU-1 | 2 | Model: **sonnet** (not opus) | Complexity score 11 = task complexity 5 (8 surgical edits, ~20–30 turns, 2 files) + ambiguity 0 (every exit criterion is a grep; the plan names exact RQ ids and line numbers) + foundation 5 (19 dependents) + risk 1 (prose editing, no code) + type 0. **The Force-Opus override was evaluated and deliberately not applied**: it requires the sortie to establish *core architectural patterns*, and amending a requirements document establishes no pattern any later sortie copies — it only removes a contradiction. Sorties 1 and 1a earned opus because they set the manifest and build interface every later gate greps; this one does not. Failure is fully grep-detectable, and a retry escalates to opus under the standard BACKOFF rule. |
| 2026-08-02T01:35Z | — | — | **Supervisor preflight error, corrected** | The preflight runtime list was produced with a truncating `grep -i iOS \| tail -5` and wrongly reported that `OS=26.1` was not installed. Full list is 18.4, 18.5, 26.0, 26.1, 26.3, 26.5, 27.0 — 26.0 and 26.1 **are** installed. Caught by the Sortie 1 agent. The user had already updated the global instruction from 26.1 → 26.5 on the strength of the bad finding; that edit is independently correct per D-SUP-3, but it was made for the wrong reason and the user has been told. |

---

## Preflight Findings (handed to sortie agents)

Verified by the supervisor before dispatch:

- `gh` authenticated as `stovak`; scopes include `repo` and `workflow` (Sorties 3, 4, 20 will need both).
- `intrusive-memory/SwiftReparto` **does not exist** on GitHub — matches the plan's premise (RQ-18).
- Latest published Yams release: **6.2.2** (2026-05-26) — the version the plan names. `.upToNextMajor(from: "6.2.2")`.
- Local toolchain: Apple Swift **6.4**, target `arm64-apple-macosx27.0.0`.
- Installed iOS Simulator runtimes: **26.3, 26.5, 27.0**. The global instructions previously pinned `OS=26.1`, which is **not installed**; the user updated the global standard to **`OS=26.5`** on 2026-08-02.
- **Mission standard iOS destination: `'platform=iOS Simulator,name=iPhone 17,OS=26.5'`.** Verified: `iPhone 17` exists on the 26.5 runtime locally. **Sortie 1a must pin exactly this string** in the Makefile's `test-ios` target, regardless of which destination Sortie 1 used for its one-off probe build. Never `OS=latest`.
  - Carry-forward risk for Sortie 3: the `macos-26` GitHub runner image may not ship the iOS 26.5 runtime. If the CI iOS job fails on destination resolution, the fix per the plan (Sortie 3, task 5) is to **change the Makefile, not the workflow**, so local and CI stay one string.
- Reference files the plan cites all exist: `SwiftProyecto/Sources/SwiftProyecto/Models/AnyCodable.swift`, `.../CastMember.swift`, `SwiftEscribo/.github/workflows/tests.yml`, `SwiftProyecto/.github/workflows/release.yml`.

---

## Overall Status

**RUNNING** — 0 of 22 sorties complete. WU-1 Sortie 1 dispatched (opus). Layers 1–5 gated.
