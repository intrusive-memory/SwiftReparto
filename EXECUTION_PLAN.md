---
type: execution-plan
feature_name: OPERATION TROUPE MARSHAL
iteration: 1
starting_point_commit: none — the SwiftReparto git repository does not exist until Sortie 1
mission_branch: main — see SUPERVISOR_STATE.md Decisions Log (D-SUP-1)
---

# EXECUTION_PLAN.md — SwiftReparto

Derived from [REQUIREMENTS.md](REQUIREMENTS.md), as amended by the Decisions below. **Target is an initial beta release, not 1.0** (D-3) — `REQUIREMENTS.md`'s `target_version: 1.0.0` frontmatter is superseded.

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| WU-1 Repository Buildout | `.` | 5 | 0 | none |
| WU-2 Core Model | `Sources/SwiftReparto/` | 3 | 1 | WU-1 |
| WU-3 Parse, Serialize, Import | `Sources/SwiftReparto/` | 5 | 2 | WU-2 |
| WU-4 Acceptance Gates | `Tests/`, `.github/` | 4 | 3 | WU-3 |
| WU-5 CLI | `Sources/RepartoCLICore/`, `Sources/reparto/` | 2 | 4 | WU-4 |
| WU-6 Beta Release | `.` | 3 | 5 | WU-5 |

Sorties 1a and 19a were added by refinement Pass 2 (oversized splits). They are sub-lettered rather than renumbered deliberately: this plan carries 78 by-number sortie cross-references, and a full renumber would rewrite ~72 of them for no gain in clarity.

Layers are strict gates: no sortie in layer N+1 dispatches until every sortie in layer N is `COMPLETED`.

---

## Parallelism Structure

**Critical path**: 1 → 1a → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 12 → 13 → 14 → 15 → 17 → 18 → 19 → 19a → 20 (**20 sorties**, down from 22 sequential).

**The binding constraint is not the dependency graph — it is the working tree.** This is one git repository with one checkout, and nearly every sortie ends in a commit. Two sorties that both commit cannot run concurrently in the same tree regardless of what the graph permits. That ceiling is lower than the dependency structure's, and it is what caps useful concurrency at **2 sub-agents**, not 4.

The workable division is therefore: **sub-agents author files; the supervising agent owns every build, every commit, and every verification.** A sub-agent that cannot build also cannot confirm its own exit criteria, so nothing is "done" until the supervisor says so.

**Parallel Execution Groups**:

- **Group 1** — WU-3 tail (after Sortie 10 completes):
  - Sortie 11 `merging(_:)` → `CastMember+Merging.swift`, `MergeTests.swift` (Agent 1) — **NO BUILD** (sub-agent)
  - Sortie 12 Import from `PROJECT.md` → `ProjectCastImporter.swift`, `ProjectCastImportTests.swift` (Agent 2) — **NO BUILD** (sub-agent)
  - File sets are disjoint. Supervisor builds once both land, then verifies each sortie's exit criteria separately, attributing any failure by file path.

- **Group 2** — WU-4 (after Sortie 13 completes):
  - Sortie 15's seven rejection fixtures (Agent 1) — **NO BUILD** (sub-agent); pure fixture authoring, no dependency on Sortie 14's assertions
  - Sortie 16's `scripts/check-leaf-invariant.sh` (Agent 2) — **NO BUILD** (sub-agent); the script only reads `Package.swift`, `Package.resolved`, and `Sources/`, all of which are final as of Sortie 8
  - Sortie 14 round-trip gates — **SUPERVISING AGENT ONLY** (build + full test run)
  - Sortie 16's CI verification (observe the guard go red on a scratch PR) — **SUPERVISING AGENT ONLY**

**Agent Constraints**:
- **Supervising agent**: every `make build`, `make test`, `make release`, every `git commit`, every `gh` call, and every CI wait. All of WU-1 and WU-6 — those sorties are almost entirely build, git, and external-API work with nothing left over to delegate.
- **Sub-agents (2 concurrent, never more)**: authoring source files, test files, fixtures, and scripts whose exit criteria the supervisor will verify afterward.

**Missed opportunities — real, and deliberately not taken**:
- **Sortie 16 could start right after Sortie 8**, not Sortie 15. Its guard reads only the manifest, the lockfile, and import lines, all stable from Sortie 8 onward. It sits at position 16 purely by layer gate, and it carries the mission's slowest verification (a full observe-it-fail CI round trip). Lifting it earlier would shorten the critical path by more than its own length. **Not taken** because it would put a workflow edit in flight while WU-3 is still committing to the same repo, and Sortie 16 modifies `tests.yml` — the file every other sortie's gate depends on. The serialization is buying safety, not lost to oversight.
- **Sortie 5 does not need Sorties 3 or 4.** `AnyCodable` needs a package that builds (Sortie 1a), not a GitHub repo with branch protection. WU-2 could begin while WU-1's remote work finishes. **Not taken** for the same working-tree reason: Sortie 3 opens and merges a PR, and a concurrent uncommitted `Sources/` change would land in it.
- **Sortie 2 does not block Sortie 3.** Sortie 3 draws its repo description from `README.md`, not `REQUIREMENTS.md`; the real consumers of Sortie 2's amendments are Sorties 12, 17, and 20. **Not taken** — both sorties commit, and these are the repo's first commits, where a merge conflict is most expensive to unpick.
- **Sortie 19's non-CLI sections** (schema, leaf invariant, branch topology, release) are knowable at WU-4 completion and could be drafted during WU-5. **Not taken** — documenting an unbuilt CLI is how docs drift from behavior, and the whole section is one file.

**Honest summary**: this plan is close to inherently sequential. Two groups of two is what the graph and the single working tree jointly allow, saving 2 sorties of wall clock out of 22. Anyone reading this expecting a 4-agent fan-out should read the four missed opportunities above and see that each was declined for a stated reason.

---

## WU-1 — Repository Buildout

`pkg/SwiftReparto` currently has no `.git` directory, and `intrusive-memory/SwiftReparto` does not exist on GitHub (RQ-18). The collection's `.gitignore` excludes `pkg/`, so every package here is its own standalone repo. Nothing else in this plan can be gated on a build until that is true.

### Sortie 1: Package manifest, source stubs, and the Yams probe

**Priority**: 69.4 — blocks all 21 remaining sorties, establishes the target/product shape every later gate greps, and carries the mission's single largest unverified risk (Yams under 6.2 + `.v26` + strict concurrency)

**Entry criteria**:
- [ ] First sortie — no prerequisites

**Tasks**:
1. `git init` in `pkg/SwiftReparto`; set `main` as the initial branch. Do **not** create the GitHub remote in this sortie.
2. Write `Package.swift`: `swift-tools-version: 6.2`, `platforms: [.macOS(.v26), .iOS(.v26)]`, `swiftLanguageModes: [.v6]`, `.enableUpcomingFeature("StrictConcurrency")` on every target. **Four targets, two products** (D-6):

   | Target | Kind | Depends on | Product? |
   |---|---|---|---|
   | `SwiftReparto` | library | **Yams only** | `.library(name: "SwiftReparto")` |
   | `RepartoCLICore` | library | `SwiftReparto`, `ArgumentParser` | **no** — internal, so consumers never see it |
   | `reparto` | executable | `RepartoCLICore` | `.executable(name: "reparto")` |
   | `SwiftRepartoTests` | test | `SwiftReparto`, `RepartoCLICore` | — |

3. Two dependencies, and the split between them is load-bearing: `https://github.com/jpsim/Yams.git` at `.upToNextMajor(from:)` the latest published release (6.2.2 as of 2026-05-26; re-verify with `gh release list --repo jpsim/Yams`), and `https://github.com/apple/swift-argument-parser` at `.upToNextMajor(from: "1.7.1")` — the floor SwiftEchada and SwiftProyecto both use. **`ArgumentParser` must not appear in the `SwiftReparto` target's dependency list**, only `RepartoCLICore`'s; otherwise every library consumer links an arg parser to read a cast list. **Do not add `marcprux/universal`** (D-1). **No `sibling(...)` helper** — RQ-INV-1 means there are no `intrusive-memory` deps to make sibling-aware, so the helper must not appear at all.
4. Write `Sources/reparto/main.swift` as a stub that compiles and prints nothing meaningful, plus an empty `Sources/RepartoCLICore/` placeholder type. WU-5 fills them in. The targets exist from Sortie 1 so `make release` and `release.yml` have something to build long before the commands are real.
5. Write `Sources/SwiftReparto/SwiftReparto.swift` containing only a module doc comment and no public API, so the target compiles.
6. **Prove Yams builds under this package's floor, before anything depends on it.** Add a temporary `import Yams` plus a one-line `YAMLEncoder`/`YAMLDecoder` round-trip inside the smoke test, and build for **both** `platform=macOS,arch=arm64` and the iOS Simulator destination. Yams is `swift-tools-version:5.7` with a C target (`CYaml`); this package is 6.2 tools, `.macOS(.v26)`/`.iOS(.v26)`, `swiftLanguageModes: [.v6]`, strict concurrency. That combination is expected to work — SwiftPM compiles a lower-tools dependency under its own settings — but it is unverified, and it is the one result that could reopen D-1. Finding out here costs one sortie; finding out at Sortie 8 costs WU-2 as well.
7. If Yams fails to build, or produces concurrency diagnostics that cannot be contained inside `YAMLCoding.swift`, **stop and escalate rather than working around it.** Do not lower the platform floor, do not drop to `swiftLanguageModes: [.v5]`, do not add `@preconcurrency`. Each silently trades RQ-15 for a dependency choice, which is the requirements author's call, not a sortie's.
8. Write `Tests/SwiftRepartoTests/PackageSmokeTests.swift` holding the task-6 round-trip. Sortie 8 replaces it with the real coding tests.
9. **There is no `Makefile` yet** — it is Sortie 1a's deliverable, and it cannot be written before the manifest it drives exists. Build and test through **XcodeBuildMCP** (`swift_package_build`, `swift_package_test` for macOS; `build_sim` for the iOS Simulator destination). Do not shell out to raw `swift build` / `swift test`.

**Exit criteria**:
- [ ] `git -C pkg/SwiftReparto rev-parse --show-toplevel` prints `.../pkg/SwiftReparto` (not the collection root)
- [ ] The package builds clean for `platform=macOS,arch=arm64` **and** for the iOS Simulator destination, both via XcodeBuildMCP
- [ ] `Package.swift` declares `swift-tools-version: 6.2`, `platforms: [.macOS(.v26), .iOS(.v26)]`, and `swiftLanguageModes: [.v6]` — verified by grep, since every later gate assumes them
- [ ] `swift package dump-package` shows products `SwiftReparto` (library) and `reparto` (executable), and **no** product named `RepartoCLICore`
- [ ] The `SwiftReparto` target's dependency list contains `Yams` and does **not** contain `ArgumentParser`, verified against `swift package dump-package`
- [ ] A test importing Yams performs an encode→decode round-trip and passes on both destinations
- [ ] The build emits no concurrency errors, and no `@preconcurrency` or `@unchecked Sendable` appears in `Sources/`
- [ ] The test run reports at least 1 test executed and 0 failures
- [ ] `grep -c 'intrusive-memory' Package.swift` returns 0, and `grep -c 'sibling' Package.swift` returns 0
- [ ] `Package.resolved` holds exactly two pins, identities `yams` and `swift-argument-parser`
- [ ] If task 7's escalation fired, the sortie reports **BLOCKED** with the diagnostic output and makes none of the three forbidden workarounds — this is a legitimate terminal state for this sortie, not a failure to retry

---

### Sortie 1a: Makefile, ignore rules, license, first commit

**Priority**: 64.9 — blocks 20 sorties; every later exit criterion is phrased as a `make` target, so the Makefile is an interface, not tooling — and this is the repo's first commit, the recovery point for everything after

**Entry criteria**:
- [ ] Sortie 1 exit criteria met (the manifest resolves and both destinations build, so the Makefile has something real to drive)

**Tasks**:
1. Write `Makefile` with targets `build`, `test`, `test-ios`, `release`, `install`, `clean`, `resolve`, `format`, `help`. The test scheme is `SwiftReparto-Package` (the per-product scheme has no test action — see SwiftEscribo's Makefile comment); `release` and `install` build the `reparto` scheme and copy the binary to `./bin`, modeled on `SwiftProyecto/Makefile`. Destination `'platform=macOS,arch=arm64'` with `ARCHS=arm64 ONLY_ACTIVE_ARCH=YES` pinned on every invocation. **No `swift build` / `swift test` anywhere in the file.**
2. Pin the iOS Simulator destination in `test-ios` to an exact OS version, verified against `xcrun simctl list runtimes`. Never `OS=latest` — it does not resolve, and Sortie 3's CI job inherits this target rather than duplicating the string.
3. Write `.gitignore` covering `.build/`, `.swiftpm/`, `DerivedData/`, `*.profraw`, `.DS_Store`, and `./bin/`. **Track `Package.resolved`** — the `spm-package-audit` convention exempts library packages, but this package ships an executable, and a binary built by CI from an unpinned graph is not reproducible. SwiftProyecto, which also ships a CLI, tracks it for the same reason.
4. Write `LICENSE` (MIT, "Intrusive Memory"), matching the header block in `SwiftProyecto/Sources/SwiftProyecto/Models/CastMember.swift`.
5. Commit everything on `main`. This is the repo's first commit and the recovery point for every sortie after it.

**Exit criteria**:
- [ ] `make build`, `make test`, and `make test-ios` each exit 0; `make test` reports at least 1 test executed
- [ ] `make release` exits 0 and produces an executable at `./bin/reparto`
- [ ] `make help` exits 0 and lists all nine targets
- [ ] `grep -cE 'swift (build|test)' Makefile` returns 0
- [ ] `grep -c 'OS=latest' Makefile` returns 0
- [ ] `git ls-files --error-unmatch Package.resolved` exits 0 (it is tracked), and `git check-ignore -q bin` exits 0 (the binary is not)
- [ ] `git log --oneline | wc -l` is at least 1 and `git status --porcelain` is empty

---

### Sortie 2: Requirements amendments

**Priority**: 61.2 — blocks 19 sorties; Sorties 12, 17 and 20 are *forbidden by the requirements as written* until these amendments land, so this is a gate rather than paperwork

**Entry criteria**:
- [ ] Sortie 1a exit criteria met (repo has a first commit, so these edits land on a clean tree)

**Tasks**:
1. `REQUIREMENTS.md` is the human's document and Mission Supervisor does not rewrite its body. The edits below are individually authorized by the Decisions, and each is a single localized change. **Make exactly these and nothing else.**
2. **RQ-16 (§6, line 283)** — name Yams instead of `marcprux/universal`; replace the "Pure Swift, no heavy transitive graph" justification with the accurate one: zero package dependencies, one resolved pin, libyaml vendored as an internal C target. (D-1)
3. **RQ-INV-3 (§2, lines 84-88) and the §2 table row for SwiftReparto (line 57)** — narrow the `PROJECT.md` prohibition to a write prohibition plus a read prohibition on everything except the `cast:` key. Record the dividing line verbatim: **Reparto imports the cast data; it does not own, resolve, or write `PROJECT.md`.** (D-4)
4. **RQ-Q3 (§9, lines 331-332)** — reverse it. `CAST.md` carries a schema version on every document this library emits. (D-5)
5. **RQ-5 / §3.3 (lines 168-181) and acceptance criterion 6 (§8)** — mark `Appearance` deferred out of the beta, not removed from the design. Record that an `appearance:` key in existing data still round-trips verbatim through `extraKeys` in the meantime. (D-3)
6. **RQ-17 (§6, line 286) and the §5 non-goals row "Any CLI | None — SwiftReparto is a library"** — reverse both. The package ships two products: the `SwiftReparto` library and the `reparto` executable. Record the CLI's bounded purpose from D-6: validate a cast document, and import cast data from `PROJECT.md`. Record that the CLI is a shell over the library and performs no parsing or serialization of its own, so RQ-INV-2's one-writer rule still holds with the binary in the picture. (D-6)
7. **RQ-16 again** — it now permits exactly two dependencies, and says which target may use which: Yams for `SwiftReparto`, `swift-argument-parser` for `RepartoCLICore` only. (D-6)
8. Update the frontmatter `target_version` to reflect a beta line rather than `1.0.0`, and set `status` to match the beta (README.md currently says `pre-alpha`; pick one value and use it in both files).
9. **RQ-13 (§?, the "two copies" passage)** — add one sentence recording that a **third** copy of the cast model exists at `SwiftEscribo/Sources/EscriboProject/CastMember.swift` (with its own `AnyCodable.swift`), and that folding it in is a follow-on outside this mission. (D-9) Do not change RQ-13's substance otherwise — the count is the only thing that is wrong.
10. Do **not** renumber requirements, do not reflow unrelated prose, and do not touch any other section. The diff should be legible as a short list of surgical edits.

**Exit criteria**:
- [ ] `grep -c 'marcprux/universal' REQUIREMENTS.md` returns 0, and `grep -c 'Yams' REQUIREMENTS.md` returns at least 1
- [ ] RQ-16's text contains both `Yams` and `swift-argument-parser`, and names `SwiftReparto` and `RepartoCLICore` as their respective targets — all four strings present in the RQ-16 block, verified by `sed -n '/RQ-16/,/^RQ-/p'` piped to grep
- [ ] The RQ-INV-3 block contains `cast:` and does **not** contain the bare prohibition `read PROJECT.md`, verified by grep on that block
- [ ] `grep -c 'schemaVersion' REQUIREMENTS.md` returns at least 1 and appears within the RQ-Q3 block
- [ ] The §3.3 block contains the word `deferred` and `grep -c 'appearance' REQUIREMENTS.md` still returns at least 1 — deferred, not deleted (D-3)
- [ ] RQ-17's block contains both `SwiftReparto` and `reparto`, and `grep -c 'No CLI target' REQUIREMENTS.md` returns 0
- [ ] `grep -cE '\| *Any CLI *\|' REQUIREMENTS.md` returns 0 — the §5 non-goals row is gone
- [ ] RQ-13 names `SwiftEscribo/Sources/EscriboProject/CastMember.swift` as a third copy, verified by `grep -c 'EscriboProject' REQUIREMENTS.md` returning at least 1
- [ ] `git diff --stat REQUIREMENTS.md` shows one file changed and no other file touched
- [ ] The document still parses as valid YAML frontmatter + markdown, and `type: requirements` is intact

---

### Sortie 3: GitHub repo, branch topology, CI

**Priority**: 60.4 — blocks 18 sorties and owns three external-API surfaces (repo creation, branch topology, CI); Sorties 4, 16 and 18 all attach to the job names minted here

**Entry criteria**:
- [ ] Sortie 2 exit criteria met

**Tasks**:
1. Create `intrusive-memory/SwiftReparto` via `gh repo create` — public, no auto-generated README/LICENSE/gitignore, description drawn from README.md's opening line.
2. Add the remote as `origin`, push `main`, set upstream tracking. Create `development` from `main`, push it, and set it as the repository default branch. Mission branches use `mission/<slug>/<NN>` and target `development`; `development` targets `main`; releases are tagged from `main`.
3. Add repo topics matching `collection.json`'s keyword vocabulary (`swift`, `intrusive-memory`, plus `cast`, `markdown`, `yaml`).
4. Write `.github/workflows/tests.yml` modeled on `SwiftEscribo/.github/workflows/tests.yml`: trigger `pull_request` on `[main, development]`, `runs-on: macos-26`, `actions/checkout@v7`, concurrency group on `github.ref` with `cancel-in-progress: true`. Two jobs named exactly `Test on macOS` and `Test on iOS Simulator` — these become branch-protection contexts in Sortie 4.
5. Both jobs invoke `make test` / `make test-ios` rather than spelling out `xcodebuild`; a duplicated destination string drifts, and SwiftEscribo's iOS job failed its first run on exactly that. The simulator OS is already pinned in Sortie 1a's `test-ios` target — **do not restate it in the workflow**. If the `macos-26` runner image lacks that runtime, change the Makefile, not the workflow, so local and CI stay one string.
6. Declare `timeout-minutes` on both jobs (30 macOS / 45 iOS). A hung job burns the six-hour default and reports nothing.
7. Write `.github/workflows/lint.yml`: run `swift format` in lint mode and fail if the checkout is modified (`git diff --exit-code` plus `git status --porcelain`). Job name `Lint`. `make format` is in-place and must never be what CI runs.
8. **Write `.github/workflows/release.yml`** (D-6 — this reverses the "library-only, no release workflow" position that held before the CLI was in scope). Model it on `SwiftProyecto/.github/workflows/release.yml`: trigger on `release: types: [published]` plus `workflow_dispatch` with a `tag` input, `permissions: contents: write`, `runs-on: macos-26`. Run `make release`, verify `./bin/reparto --version` exits 0, tar the binary as `reparto-<version>-arm64-macos.tar.gz`, compute its SHA-256, and upload it to the release with `softprops/action-gh-release@v3`.
9. The `release: published` trigger fires for **prereleases** too, so the beta gets a tarball. That is intended — it makes `gh release download` work for the beta even though Homebrew will not track it (see Sortie 20).
10. **Do not add a `formula-update` repository-dispatch step, and do not create a tap formula from this repo.** The org's Homebrew tap is **pull**-based: `intrusive-memory/homebrew-tap` runs `reconcile-formulas.yml` on a 6-hour cron using only its own `GITHUB_TOKEN`. The push direction is dead — the org `DEPLOY_TOKEN` PAT expired and was deleted in July 2026, and the dispatch step referenced a secret that no longer exists. A source repo builds and attaches its tarball; the tap decides when to consume it.
11. Record tasks 9 and 10 in a short `.github/workflows/README.md` so the next person adding CI does not restore the dispatch pattern from muscle memory.
12. Open a PR from a throwaway branch into `development` to prove `tests.yml` and `lint.yml` trigger and pass, then merge it. `release.yml` cannot be exercised until Sortie 20 cuts a release; note that in the completion report rather than claiming it verified.
13. **Bound the fix-push-wait loop to three CI runs.** A red run gets one diagnosis and one fix. If the third run is still red, stop and report the failing job's log rather than continuing — a workflow-debugging spiral is the single most likely way this sortie exhausts its context, and it exhausts it *before* the repo has protection or a merged PR, which is a worse state to hand back than a clean BLOCKED.

**Exit criteria**:
- [ ] `gh api repos/intrusive-memory/SwiftReparto/branches --jq '.[].name'` lists `main` and `development`
- [ ] `gh repo view intrusive-memory/SwiftReparto --json defaultBranchRef --jq .defaultBranchRef.name` prints `development`
- [ ] `gh run list` shows a completed Tests run with `conclusion: success`
- [ ] `gh api repos/intrusive-memory/SwiftReparto/commits/main/check-runs --jq '.check_runs[].name'` includes `Test on macOS` and `Test on iOS Simulator`
- [ ] `grep -c 'OS=latest' .github/workflows/tests.yml Makefile` returns 0
- [ ] `grep -c 'macos-15\|macos-14\|macos-13' .github/workflows/*.yml` returns 0
- [ ] `.github/workflows/release.yml` exists, triggers on `release: published`, and names `./bin/reparto`
- [ ] `grep -rc 'formula-update\|DEPLOY_TOKEN\|repository_dispatch' .github/` returns 0
- [ ] `actionlint .github/workflows/*.yml` exits 0, or the sortie records that `actionlint` is unavailable and the YAML was parsed instead

---

### Sortie 4: Branch protection

**Priority**: 54.9 — blocks 17 sorties; low complexity but pure external-API risk, and the contexts frozen here constrain Sortie 16's guard for the rest of the mission

**Entry criteria**:
- [ ] Sortie 3 exit criteria met (both check-run contexts have reported at least once, so protection can reference them by their real names)

**Tasks**:
1. Apply protection to `main` via `gh api --method PUT repos/intrusive-memory/SwiftReparto/branches/main/protection --input <json>` with `required_status_checks.strict: true` and `contexts: ["Test on macOS", "Test on iOS Simulator"]`.
2. Set `required_pull_request_reviews` with `required_approving_review_count: 0` — forces changes through a PR without blocking a solo maintainer on a second human.
3. Set **`enforce_admins: false`** (D-11). Set `allow_force_pushes: false` and `allow_deletions: false`.
4. Apply the same protection to `development`, minus `enforce_admins`, so mission work still lands quickly.
5. **Verify by reading the protection state back from the API, not by attempting a push.** With `enforce_admins: false`, an admin — which the sole maintainer is — bypasses required checks and required reviews, so a direct `git push origin main` **succeeds** and proves nothing. The enforcement that matters here is `strict: true` plus non-empty `contexts`, and that is an API-state assertion. (D-11)

**Exit criteria**:
- [ ] `gh api repos/intrusive-memory/SwiftReparto/branches/main/protection --jq '.required_status_checks.contexts'` returns exactly `["Test on macOS","Test on iOS Simulator"]`
- [ ] `... --jq '.required_status_checks.strict'` returns `true`
- [ ] `... --jq '.enforce_admins.enabled'` returns `false`
- [ ] `... --jq '.allow_force_pushes.enabled'` and `... --jq '.allow_deletions.enabled'` both return `false`
- [ ] `... --jq '.required_pull_request_reviews.required_approving_review_count'` returns `0`
- [ ] `gh api repos/intrusive-memory/SwiftReparto/branches/development/protection --jq '.required_status_checks.contexts | length'` returns `2`
- [ ] The completion note records that no direct-push test was run, and why (D-11)

---

## WU-2 — Core Model

### Sortie 5: Vendored `AnyCodable`

**Priority**: 51.7 — blocks 16 sorties; `AnyCodable` is the substrate under `extraKeys`, which means it is the substrate under RQ-4, D-3's deferral, and D-8's accessors

**Entry criteria**:
- [ ] WU-1 complete (repo exists, CI green, protection applied)

**Tasks**:
1. Copy `SwiftProyecto/Sources/SwiftProyecto/Models/AnyCodable.swift` (156 lines) to `Sources/SwiftReparto/AnyCodable.swift`, preserving the MIT header.
2. Add a file-level doc comment recording that this copy is canonical per RQ-13, that SwiftProyecto holds a twin, and that the twins collapse in the direction `SwiftProyecto → SwiftReparto` only.
3. Make the type `public` and `Sendable`; verify it compiles under `swiftLanguageModes: [.v6]` with strict concurrency and fix any concurrency diagnostics the source module did not have to satisfy.
4. Write `Tests/SwiftRepartoTests/AnyCodableTests.swift` asserting encode→decode identity for: string, int, double, bool, null, nested array, nested dictionary, and a dictionary nested three levels deep. The three-level case is the one that matters — SwiftProyecto issue #55 was a nested structure flattened through `NSDictionary.description`.

**Exit criteria**:
- [ ] `Sources/SwiftReparto/AnyCodable.swift` exists and `make build` exits 0
- [ ] `make test` exits 0 with all `AnyCodableTests` cases passing
- [ ] All eight cases named in task 4 have a corresponding test, verified by counting test functions in `AnyCodableTests.swift`
- [ ] A round-trip of a three-level nested dictionary compares equal, asserted by test
- [ ] `AnyCodable` is declared `public` and `Sendable`, verified by grep, and the file retains its MIT header
- [ ] The file-level doc comment names SwiftProyecto as the twin and `SwiftProyecto → SwiftReparto` as the collapse direction (RQ-13)

---

### Sortie 6: `Gender` and `CastMember`

**Priority**: 50.4 — blocks 15 sorties; `CastMember` is the type every other sortie manipulates, and its `DynamicCodingKey` extras capture is the mechanism RQ-4 depends on

**Entry criteria**:
- [ ] Sortie 5 complete (`AnyCodable` available in-module)

**Tasks**:
1. Write `Sources/SwiftReparto/Gender.swift`: `public enum Gender: String, Codable, Sendable, Equatable, Hashable, CaseIterable` with `M`/`F`/`NB`/`NS` and the `displayName` computed property, ported verbatim from `SwiftProyecto/.../CastMember.swift:32` (RQ-2).
2. Write `Sources/SwiftReparto/CastMember.swift` per RQ-3/RQ-4, porting the custom `init(from:)` / `encode(to:)` pair from SwiftProyecto's implementation (`CastMember.swift:453-514`) — the `DynamicCodingKey` extras capture is the mechanism RQ-4 depends on and must not be re-derived.
3. **Do not define `Appearance`, and do not add `appearance` to `CodingKeys`** (D-3). It is deferred past the beta. Because it is *not* a declared key, an `appearance:` block in existing data is swept into `extraKeys` and re-emitted verbatim — the deferral costs no data. Add a comment saying exactly that, so nobody "fixes" its absence.
4. **Name the stored property `voicePrompt`** (D-2), not `voiceDescription`. The YAML key is unchanged — it is already `voicePrompt` on the wire; only the Swift identifier moves.
5. Declare the migration shim immediately below it:
   ```swift
   @available(*, deprecated, renamed: "voicePrompt")
   public var voiceDescription: String? {
     get { voicePrompt }
     set { voicePrompt = newValue }
   }
   ```
   Both accessors, so a consumer mid-migration can read *and* write through it. Document that it is removed in this package's next major release version. Keep it out of `CodingKeys` — it is a Swift-side alias only, and the decoder already handles the legacy YAML key separately.
6. Declare extras as **`public private(set) var extraKeys: [String: AnyCodable]`**, plus `public subscript(extra key: String) -> AnyCodable?` for reads and `public mutating func setExtra(_ value: AnyCodable?, forKey key: String)` for writes (D-8). Consumers must not be able to replace the dictionary wholesale — that is RQ-INV-2's failure mode with a different name. Do **not** rely on `@testable import` to reach it: acceptance criterion 3 must pass through the same door a consumer has.
7. Do **not** port SwiftProyecto's `MergeStrategy` enum or its three `merge(with:strategy:)` variants. RQ-14 specifies one additive merge on `[CastMember]`, and it lands in Sortie 11.
8. Write `Tests/SwiftRepartoTests/CastMemberCodingTests.swift` covering: `voicePrompt` decode, legacy `voiceDescription` decode, scalar `voices` decode, array `voices` decode, `voices` always emitted as array, unknown key captured and re-emitted, and an `appearance:` block surviving verbatim through `extraKeys`.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] A `CastMember` decoded from `voiceDescription:` re-encodes with key `voicePrompt` and no `voiceDescription` key, asserted by test
- [ ] `grep -c 'var voicePrompt' Sources/SwiftReparto/CastMember.swift` returns 1, and the only `voiceDescription` declaration is the deprecated shim
- [ ] Reading and writing through the deprecated shim both reach `voicePrompt`, asserted by test
- [ ] `grep -c 'struct Appearance' Sources/` returns 0
- [ ] A member carrying a nested `appearance:` block round-trips byte-identically through `extraKeys`, asserted by test
- [ ] A `CastMember` decoded from `voxalta: path.vox` re-encodes as `voxalta: [path.vox]`, asserted by test
- [ ] A member carrying `bio:` re-encodes with `bio:` present and its value byte-identical, asserted by test
- [ ] `extraKeys` is readable and writable from `SwiftRepartoTests` **without** `@testable import`, asserted by a test file that uses a plain `import SwiftReparto` (D-8)
- [ ] `grep -c 'public var extraKeys' Sources/SwiftReparto/CastMember.swift` returns 0 and `grep -c 'public private(set) var extraKeys' ...` returns 1

---

### Sortie 7: `CastDocument`, `CastSchemaVersion`, `CastParseError`

**Priority**: 47.4 — blocks 14 sorties; defines the schema version, the document, and the complete error vocabulary — three interfaces the rest of the mission asserts against

**Entry criteria**:
- [ ] Sortie 6 complete (`CastMember` compiles and round-trips)

**Tasks**:
1. Write `Sources/SwiftReparto/CastSchemaVersion.swift` per D-12. The front-matter key is **`schemaVersion`**. The value is a **monotonic integer starting at 1** — not a string, not semver. Expose `public static let current: Int = 1` and whatever `Comparable` surface the newer-than check needs. Integer ordering is the whole point: `"1.10"` vs `"1.9"` sorts wrong as a string, and this schema has no patch dimension to express.
2. Write `Sources/SwiftReparto/CastDocument.swift`: `public struct CastDocument: Codable, Sendable, Equatable` with `public var cast: [CastMember]`, `public var body: String`, and the schema version (RQ-9, D-5).
3. **A document parsed without a version is legacy, not invalid.** Decode a missing `schemaVersion` to the unversioned sentinel (D-12), accept it, and stamp `current` on the next emit. This is the whole mechanism behind D-5's iterative approach: existing hand-written files keep working, and the first write normalizes them.
4. **A document declaring a version greater than `current` is rejected with a typed error** (D-12): `.unsupportedSchemaVersion(found: Int, supported: Int)`. Never a silent best-effort parse — an older writer that accepts a newer document will confidently rewrite it and drop whatever it did not understand, which is RQ-INV-2's exact failure with a version number attached. A caller who wants best-effort can catch the typed error and decide; a caller handed a silent lossy parse cannot.
5. Write `Sources/SwiftReparto/CastParseError.swift`: `public enum CastParseError: Error, LocalizedError, Equatable` with the five cases RQ-12 names — `noFrontMatter`, `invalidYAML(String)`, `missingTypeCast`, `missingCastKey`, `missingCharacter(index: Int)` — plus `unsupportedSchemaVersion(found: Int, supported: Int)` from task 4. Each gets a distinct `errorDescription`.
6. Include the member index in `missingCharacter` so a caller can point at the offending entry.
7. Add a file-level doc comment stating the RQ-12 contract: a caller must be able to distinguish "this is not a cast document" from "this cast document is empty," and no code path may `fatalError` or fall back to an empty cast.
8. Write `Tests/SwiftRepartoTests/CastParseErrorTests.swift` asserting every case is distinguishable by `==` and has a non-empty `errorDescription`.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] `grep -rc 'fatalError' Sources/SwiftReparto/` returns 0
- [ ] Every `CastParseError` case has a non-empty `errorDescription`, asserted by test
- [ ] A `CastDocument` decoded from input with no `schemaVersion` key carries the unversioned sentinel, asserted by test
- [ ] `CastSchemaVersion.current` is the integer `1`, and `grep -cE 'schemaVersion.*"[0-9]' Sources/` returns 0 — the version is never a string (D-12)
- [ ] A document declaring `schemaVersion: 2` throws `.unsupportedSchemaVersion(found: 2, supported: 1)`, asserted by equality on the error case, not by `throws: Error.self`
- [ ] `make test` exits 0

---

## WU-3 — Parse, Serialize, Import

### Sortie 8: YAML coding layer (Yams)

**Priority**: 45.0 — blocks 13 sorties; the encoder configuration decided here determines whether RQ-11's SHA-256 gate is stable, and the YAML 1.1 resolver behavior it pins is undocumented upstream

**Entry criteria**:
- [ ] WU-2 complete (model types compile and round-trip through `Codable`)

**Tasks**:
1. Write `Sources/SwiftReparto/YAMLCoding.swift` wrapping `YAMLEncoder`/`YAMLDecoder` behind two internal functions. **This is the only file permitted to `import Yams`** — every other file names Foundation types only, which keeps the dependency swappable and gives Sortie 16's guard a single line to check.
2. Configure the encoder explicitly and never rely on a default: `width = -1` (**required** — the default is 0, meaning "best width," which folds long lines and would break THE PRACTITIONER's ~400-character `bio`), `indent`, `lineBreak = .ln`, and `sortKeys` per task 3.
3. **Key order must be deterministic and stable across runs.** `[String: AnyCodable]` iteration order is not. Set **`sortKeys = false`** and guarantee order at the `encode(to:)` layer: declared `CodingKeys` emit in declaration order, then `extraKeys` sorted lexicographically. State this in a comment on the encoder configuration. RQ-11's SHA-256 gate fails *intermittently* otherwise, and an intermittent hash failure reads as a corruption bug.

   **`sortKeys = true` is not an option here, and the reason is not stylistic.** Sortie 10 task 2 requires the front matter to emit `type: cast`, then `schemaVersion`, then `cast:` — a fixed position that keeps the SHA-256 gate stable across the legacy-stamping path. Lexicographic order produces `cast` → `schemaVersion` → `type`, which contradicts it. Declaration order is what satisfies both requirements at once.
4. Construct `YAMLEncoder` inside the function body. It is a `public class` with a mutable `options` property and is **not** `Sendable`; storing it as a property breaks `CastMarkdownParser: Sendable` under RQ-15.
5. Write `Tests/SwiftRepartoTests/YAMLCodingTests.swift` asserting `decode(encode(x)) == x` for ~12 hostile inputs: a string containing `: `, a leading `-`, `#`, a leading `%`, the literal strings `"true"` / `"no"` / `"null"` / `"~"` / `"123"` / `"1.0"`, an empty string, a string with leading and trailing spaces, a 400-character single-line prose string, and a three-level nested mapping.
6. Assert the emitted 400-character string occupies exactly one line — the direct regression test for the `width` default, and the single most likely way this sortie ships a latent RQ-11 failure.
7. **Pin the YAML 1.1 boolean behavior with an explicit regression test** (D-1). Assert `language: no` decodes to the `String` `"no"` and not a boolean, and that an unknown key with the unquoted values `no`, `yes`, `on`, `off`, `y`, `n` is captured by `AnyCodable` as a `String` in each case and re-emits as the same string. This holds only because Yams' `YAMLDecoder` builds its parser with `Resolver([.merge])` rather than `Resolver.default` (`Decoder.swift:147`) — deliberate but undocumented. Name that file and line in the test's comment.

**Exit criteria**:
- [ ] `make build` exits 0 for both macOS and iOS destinations
- [ ] `grep -rl 'import Yams' Sources/` returns exactly `Sources/SwiftReparto/YAMLCoding.swift`
- [ ] Every hostile-input case round-trips to an equal value, asserted by test
- [ ] The 400-character prose string emits on exactly one line, asserted by test
- [ ] Encoding the same value twice in one process produces byte-identical output, asserted by test
- [ ] Encoding a `CastMember` carrying 5+ `extraKeys` produces the extras in lexicographic order, asserted by test — the direct regression test for dictionary iteration order
- [ ] `grep -c 'sortKeys = true' Sources/SwiftReparto/YAMLCoding.swift` returns 0
- [ ] `language: no` decodes to the `String` `"no"`, and unquoted `no`/`yes`/`on`/`off`/`y`/`n` under an unknown key each round-trip as the same string, asserted by test
- [ ] No stored property of any `Sendable` type holds an encoder instance

---

### Sortie 9: `CastMarkdownParser.parse`

**Priority**: 42.2 — blocks 12 sorties; owns the byte-exact body split (D-10) and the shared relativization function (D-7) that Sortie 12 must reuse rather than re-derive

**Entry criteria**:
- [ ] Sortie 8 complete (coding layer passes its own round-trip gate)

**Tasks**:
1. Write `Sources/SwiftReparto/CastMarkdownParser.swift` with `public struct CastMarkdownParser: Sendable`, `public init()`, and the two parse entry points from RQ-10.
2. Split front matter on the leading `---` / closing `---` delimiters. **Do not use SwiftProyecto's `ProjectMarkdownParser.parse` splitting logic** — it does `split(separator: "\n")` + `joined(separator: "\n")` + `trimmingCharacters(in: .whitespacesAndNewlines)`, which normalizes CRLF to LF and eats the trailing newline. Both are byte changes, and RQ-8 requires byte-for-byte body preservation.
3. Capture the body as the exact substring following the closing delimiter's line terminator, with no trimming and no line-ending normalization (D-10). Locate that terminator **by index** and take everything after it untouched — roughly 20 lines of index arithmetic instead of a familiar helper, and the helper is what silently converts CRLF→LF and eats the trailing newline.
4. Parse the front matter through the decode side of `YAMLCoding`. Do **not** `import Yams` in this file (D-1).
5. Enforce RQ-1: reject unless **both** `type: cast` and a `cast:` key are present. Missing front matter → `.noFrontMatter`; present-but-unparseable → `.invalidYAML`; `cast:` without `type: cast` → `.missingTypeCast`; `type: cast` without `cast:` → `.missingCastKey`; a member without `character` → `.missingCharacter(index:)`.
6. Read `schemaVersion` per Sortie 7's rules: absent → unversioned sentinel; `> CastSchemaVersion.current` → throw `.unsupportedSchemaVersion(found:supported:)` (D-12).
7. Implement `parse(fileURL:)` as read → `parse(content:)` → **relativize** (D-7). Together with Sortie 12's importer, these are the only filesystem reads in the library, and each touches only the URL it is handed.
8. Write the relativization as one internal function, `relativizingPaths(in:to directory: URL)`, shared verbatim with Sortie 12's importer. It strips the base directory's prefix from any absolute path string and leaves everything else untouched. **Pure string work** — it must not stat, resolve symlinks, canonicalize, or ask the filesystem anything (RQ-7). A path that does not carry the base prefix is left exactly as-is; do not synthesize `../` chains to reach outside the project directory.
9. `parse(content:)` has no directory and therefore does **not** relativize. Document that on the method: a document parsed from a string carries whatever path strings it was given, and normalizing them is the caller's job.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] Parsing content with CRLF line endings in the body yields a `body` whose `\r\n` sequences are intact, asserted by byte comparison
- [ ] Parsing content whose body ends without a trailing newline yields a `body` that also ends without one, asserted by byte comparison
- [ ] Each `CastParseError` case is produced by a corresponding malformed input, asserted by test
- [ ] A document with `type: cast` and `cast: []` parses successfully to an empty `cast` array — it does **not** throw
- [ ] `parse(fileURL:)` on a document whose `voices` entry is an absolute path under the file's own directory yields a **relative** path, asserted by test (D-7)
- [ ] `parse(fileURL:)` on an absolute path *outside* the file's directory leaves it verbatim — no `../` chain is synthesized, asserted by test
- [ ] `parse(content:)` on the same absolute-path input leaves it verbatim, asserted by test
- [ ] The relativization function is reachable by both `CastMarkdownParser` and `ProjectCastImporter` and is declared exactly once, verified by grep

---

### Sortie 10: `generate`, `write`, and round-trip identity

**Priority**: 38.2 — blocks 11 sorties; `generate`/`write` are the one-writer surface RQ-INV-2 protects, and the version-stamping path lands here

**Entry criteria**:
- [ ] Sortie 9 complete (parse produces a `CastDocument` and rejects correctly)

**Tasks**:
1. Implement `generate(document:) throws -> String`: emit `---`, the front matter, `---`, then the body verbatim.
2. **Always stamp `schemaVersion: 1` on emission** (D-5, D-12), regardless of what the input carried. Emit the front matter in exactly this order — `type: cast`, `schemaVersion`, `cast:` — so key order is stable for the SHA-256 gate. This ordering is what Sortie 8 task 3's `sortKeys = false` decision exists to make possible; do not reintroduce lexicographic sorting here.
3. Implement `write(document:to:) throws` as `generate` + atomic write with `.utf8`.
4. Normalize `voices` to the array form on emission (RQ-3).
4a. **Neither `generate` nor `write` performs any path logic** (D-7). RQ-6's "absolute paths decode but are never emitted" is already satisfied by Sortie 9's boundary normalization, so emission writes exactly the strings the document holds. Do not add a relativization pass here: `generate(document:)` has no directory to relativize against, and if `write` did it while `generate` did not, the two would produce different bytes — and RQ-11's gate asserts on `generate`, i.e. on the string that never reached disk.
5. Write `Tests/SwiftRepartoTests/RoundTripTests.swift` asserting `generate(parse(x)) == x` by SHA-256 for ~8 self-generated documents (RQ-11). SHA-256 rather than string equality, per the requirement.
6. Assert the mutate-and-write cycle: parse, mutate `cast[0].voices`, generate, and confirm `body` is byte-identical to the original (acceptance criterion 4).
7. Assert the version-stamping path explicitly: an unversioned input, once written, carries the current version; re-parsing and re-writing that output is then byte-stable.
8. Confirm no code path resolves, stats, or canonicalizes a path string, and none reads any file other than the URL passed in.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] For all 8 documents, `SHA256(generate(parse(x))) == SHA256(x)`, asserted by test
- [ ] After a mutate-and-write cycle, the body's SHA-256 is unchanged, asserted by test
- [ ] An unversioned document, written once, carries `schemaVersion: 1`; written twice, is byte-stable, asserted by test
- [ ] The emitted front matter's first three keys are `type`, `schemaVersion`, `cast` in that order, asserted by test on the generated string (D-12)
- [ ] **`write(document:to:)` produces bytes byte-identical to `generate(document:)` for the same document**, asserted by test on a document containing an absolute path — the direct regression test for D-7
- [ ] `grep -cE 'FileManager|\.standardized|\.resolvingSymlinksInPath|URLResourceKey' Sources/SwiftReparto/CastMarkdownParser.swift` returns 0
- [ ] `make test` exits 0

---

### Sortie 11: `merging(_:)`

**Priority**: 28.9 — blocks 9 sorties by layer gate only; a leaf API with no downstream interface — the lowest-leverage sortie in WU-3

**Entry criteria**:
- [ ] Sortie 10 complete (round-trip identity gate passes)

**Tasks**:
1. Implement `public func merging(_ discovered: [CastMember]) -> [CastMember]` as an extension on `[CastMember]` per RQ-14.
2. Match on `character` case- and whitespace-insensitively. Extract the normalization into one internal function so the merge and any future lookup cannot drift.
3. Members present in the receiver keep **every** field — the discovered version never overwrites an existing `voicePrompt`, `bio`, `voices`, or any `extraKeys` entry.
4. Members in `discovered` and not in the receiver are appended, in `discovered` order, after the receiver's members.
5. **Never prune.** The result count is always `>=` the receiver count. Add a doc comment naming Produciesta's `CastWriter` as the failure this exists to prevent.
6. Write `Tests/SwiftRepartoTests/MergeTests.swift` covering: additive append, no-overwrite of an existing field, case-insensitive match (`narrator` vs `NARRATOR`), whitespace-insensitive match (`THE  PRACTITIONER` vs `THE PRACTITIONER`), merge with an empty `discovered`, and merge of a 12-member receiver against a 1-member `discovered`.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] Merging a 12-member roster against a 1-member `discovered` yields exactly 12 members, asserted by test (acceptance criterion 7)
- [ ] Merging a member carrying `bio` against a same-named member without one leaves `bio` present and unchanged, asserted by test
- [ ] `narrator` and `NARRATOR` merge to one member, not two, asserted by test
- [ ] `make test` exits 0

---

### Sortie 12: Import cast from `PROJECT.md`

**Priority**: 32.2 — blocks 9 sorties; higher leverage than Sortie 11 despite the same layer position, because Sorties 14 and 17 both build on the importer, and this is the sortie most likely to breach RQ-INV-1

**Entry criteria**:
- [ ] Sortie 10 complete (a `CastDocument` can be produced and written)
- [ ] Sortie 2 complete (RQ-INV-3 and the §2 table amended — this sortie is otherwise forbidden by the requirements as originally written)

**Tasks**:
1. Write `Sources/SwiftReparto/ProjectCastImporter.swift`: `public struct ProjectCastImporter: Sendable`, `public init()`, with entry points taking `PROJECT.md` content and a file URL, each returning a `CastDocument` (D-4).
2. **Parse `PROJECT.md`'s front matter directly, through `YAMLCoding`.** Do **not** depend on SwiftProyecto to do it. This is the sortie most likely to break RQ-INV-1: `ProjectMarkdownParser` already exists and does most of this, and reaching for it would add an `intrusive-memory` dependency and create the exact package cycle this library exists to make impossible.
3. **Read the `cast:` key and nothing else.** Do not read `title`, `tts`, `episodes_index`, `variants`, `languages`, or any other project field, and do not carry them into the result. That is the dividing line the amendment records: Reparto imports the cast data; it does not own, resolve, or write `PROJECT.md`.
4. Do **not** require `type: cast` on import — a `PROJECT.md` declares `type: project`. Require only a well-formed front matter block containing `cast:`. A `PROJECT.md` with no `cast:` key is a typed error, not an empty roster.
5. Decode each member through the same `CastMember` decoder used by `parse`, so every RQ-3 leniency (legacy `voiceDescription`, scalar `voices`) and RQ-4 guarantee (`extraKeys`, including any `appearance:` block) applies identically on the import path. **No second decoder.**
6. Set `body` to the empty string on the produced document. `PROJECT.md`'s body is project prose, not cast prose, and RQ-8 forbids this library from generating body content. The human writes the `# Cast` narrative afterward.
7. Stamp the current schema version on the produced document, so the first write of an imported roster is a versioned `CAST.md`.
7a. Apply Sortie 9's relativization against the `PROJECT.md`'s own directory, using the **same** shared function — not a copy (D-7). Because `CAST.md` is written beside `PROJECT.md`, both files share a base directory, so a path already relative in `PROJECT.md` needs no adjustment; the pass exists for the absolute-path case and so there is one rule rather than a rule plus an exception. The content-taking entry point has no directory and does not relativize, matching `parse(content:)`.
8. **Never write `PROJECT.md`.** Import is read-only with respect to the source file. Removing the now-migrated `cast:` block from `PROJECT.md` is **out of scope for this mission entirely** — see D-13. Do not write it, do not warn about it, and do not add a `--prune` flag to the CLI in Sortie 17.
9. Write `Tests/SwiftRepartoTests/ProjectCastImportTests.swift` covering: import from a real `PROJECT.md` fixture, `extraKeys` (`bio`) surviving the import, scalar `voices` surviving, a `PROJECT.md` with no `cast:` producing the typed error, and the produced document emitting as valid versioned `CAST.md` that `parse` accepts.

**Exit criteria**:
- [ ] `make build` exits 0
- [ ] `grep -c 'intrusive-memory\|SwiftProyecto' Package.swift Sources/SwiftReparto/ProjectCastImporter.swift` returns 0
- [ ] Importing the pinned `PROJECT.md` fixture yields all its members with `bio` and scalar `voices` intact, asserted by test
- [ ] The fixture's already-relative `voices` paths come through the import **unchanged**, asserted by string comparison (D-7 — same base directory, so nothing to rewrite)
- [ ] An absolute `voices` path under the `PROJECT.md`'s directory is relativized on import, asserted by test
- [ ] `ProjectCastImporter` calls the shared relativization function rather than declaring its own, verified by grep
- [ ] No project-level key from the fixture (`title`, `tts`, `episodes_index`) appears anywhere in the produced document, asserted by test
- [ ] `generate` on the imported document produces output that `parse` accepts and that carries the current schema version, asserted by test
- [ ] The source `PROJECT.md` fixture's SHA-256 is unchanged after an import, asserted by test
- [ ] A `PROJECT.md` with front matter but no `cast:` key produces a typed error, not an empty roster

---

## WU-4 — Acceptance Gates

### Sortie 13: Pin the fixtures

**Priority**: 29.2 — blocks 8 sorties; the fixtures pinned here are the SHA-256 anchors for every acceptance gate in WU-4 and the inputs to Sorties 17 and 18

**Entry criteria**:
- [ ] WU-3 complete (parse, generate, merge, and import all pass their own gates)

**Tasks**:
1. Vendor `~/Projects/podcasts/confessions/PROJECT.md` as `Tests/SwiftRepartoTests/Fixtures/confessions-PROJECT.md` — the import-path fixture. Its `cast:` block (lines 16-29) carries three members with scalar `voices`, multi-sentence `voicePrompt` values, and THE PRACTITIONER's ~400-character `bio`.
2. Derive `Fixtures/confessions-CAST.md` from that import, **in the exact form this library emits** — versioned front matter, array-form `voices`. Then hand-write the body (`# Cast`, `## Major Characters`, an `###` heading per character).
3. **Commit both as bytes and never regenerate them.** The CAST.md fixture is the SHA-256 anchor for RQ-11; a fixture the test suite can rewrite proves nothing.
4. Add `Fixtures/all-fields-CAST.md` exercising every declared field: `actor`, `gender`, `language`, array-form `voices`, an unknown key, and a nested `appearance:` block — the last one present specifically to prove D-3's deferral is lossless.
5. Add `Fixtures/legacy-unversioned-CAST.md`: a valid cast document with **no** `schemaVersion` key, to exercise D-5's legacy path.
6. Declare `resources: [.copy("Fixtures")]` on the test target — `.copy`, not `.process`. A resource rule entitled to transform the file would launder away exactly what is under test.
7. Write a fixture-loading helper reaching all fixtures through `Bundle.module`. No test may name a path outside the package.

**Exit criteria**:
- [ ] All four fixtures exist under `Tests/SwiftRepartoTests/Fixtures/` and are tracked by git
- [ ] `Package.swift` declares `resources: [.copy("Fixtures")]` and contains no `.process("Fixtures")`
- [ ] A test loads every fixture through `Bundle.module`; the three CAST.md fixtures parse without throwing and the PROJECT.md fixture imports without throwing
- [ ] `confessions-CAST.md` satisfies `generate(parse(x)) == x` byte-for-byte — i.e. it is already in emitted form, so Sortie 14's SHA-256 gate is asserting against a fixture the library agrees with
- [ ] `confessions-CAST.md` and `all-fields-CAST.md` both carry `schemaVersion: 1`; `legacy-unversioned-CAST.md` carries no `schemaVersion` key, verified by grep
- [ ] `all-fields-CAST.md` contains an `appearance:` block and `grep -c 'struct Appearance' Sources/` still returns 0 — the fixture exercises the deferral (D-3)
- [ ] No test writes to, regenerates, or rewrites any file under `Fixtures/`, verified by grep for write APIs in the test target
- [ ] `grep -rc '/Users/' Tests/` returns 0

---

### Sortie 14: Round-trip and preservation gates

**Priority**: 22.9 — blocks 7 sorties by layer gate; pure verification, no downstream interface, but it is where five separate acceptance criteria are actually proven

**Entry criteria**:
- [ ] Sortie 13 complete (all fixtures load through `Bundle.module`)

**Tasks**:
1. Assert `SHA256(generate(parse(confessions-CAST.md))) == SHA256(confessions-CAST.md)` (acceptance criterion 2).
2. Assert `extraKeys` preservation on `bio` **by name**, not by count: parse, locate THE PRACTITIONER, read `bio` back out, and compare to the fixture's literal value (acceptance criterion 3).
3. Assert the body survives a mutate-and-write cycle byte-for-byte against the fixture (acceptance criterion 4).
4. Assert the `appearance:` block in `all-fields-CAST.md` round-trips byte-identically through `extraKeys`, and that a member with no `appearance:` gains none on re-emit. This is the standing proof that D-3's deferral costs no data.
5. Assert legacy `voiceDescription` decoding and scalar-`voices` decoding, each on its own small fixture (acceptance criterion 5).
6. Assert the legacy-unversioned path end to end: `legacy-unversioned-CAST.md` parses, carries the unversioned sentinel, emits with the current version stamped, and the emitted output is byte-stable on a second round trip.
7. Assert the full import pipeline: `confessions-PROJECT.md` → import → generate produces bytes equal to `confessions-CAST.md` modulo the hand-written body. Pin whichever portion is mechanically derived by SHA-256.

**Exit criteria**:
- [ ] The confessions CAST fixture's SHA-256 is unchanged across a parse→generate cycle, asserted by test
- [ ] A test named for `bio` reads THE PRACTITIONER's `bio` back and compares it to the literal fixture value
- [ ] Body SHA-256 is unchanged across a mutate-and-write cycle, asserted by test
- [ ] The `appearance:` block round-trips byte-identically, asserted by test
- [ ] The unversioned fixture gains the current version on first write and is byte-stable on the second, asserted by test
- [ ] The import→generate front matter matches the pinned CAST fixture's front matter by SHA-256, asserted by test
- [ ] `make test` exits 0

---

### Sortie 15: Rejection gates

**Priority**: 22.2 — blocks 6 sorties; the seven rejection fixtures it authors are reused by Sortie 17's exit criteria and Sortie 18's exit-code tests

**Entry criteria**:
- [ ] Sortie 14 complete (round-trip gates green)

**Tasks**:
1. `Fixtures/reject-type-only.md`: `type: cast` present, `cast:` absent → `.missingCastKey`.
2. `Fixtures/reject-cast-only.md`: `cast:` present, `type:` absent or not `cast` → `.missingTypeCast`.
3. `Fixtures/reject-neither.md`: valid front matter with neither key — the arbitrary-prose case RQ-1's dual check exists to reject → `.missingTypeCast`.
4. `Fixtures/reject-no-frontmatter.md`: plain markdown → `.noFrontMatter`.
5. `Fixtures/reject-malformed-yaml.md`: delimiters present, contents not valid YAML → `.invalidYAML`.
6. `Fixtures/reject-missing-character.md`: a member lacking `character` → `.missingCharacter(index: 0)`.
7. `Fixtures/reject-future-version.md`: `schemaVersion: 2` → `.unsupportedSchemaVersion(found: 2, supported: 1)` (D-12).
8. Each test asserts the **specific** case, never merely that something was thrown (acceptance criterion 8).

**Exit criteria**:
- [ ] `ls Tests/SwiftRepartoTests/Fixtures/reject-*.md | wc -l` returns 7
- [ ] The rejection test file contains 7 test functions, and each names its expected `CastParseError` case in an equality assertion — verified by `grep -c 'CastParseError\.' ` returning at least 7
- [ ] `grep -c 'throws: Error.self' Tests/` returns 0 — no rejection test asserts merely that something was thrown
- [ ] A document with `type: cast` and an empty `cast:` array parses successfully, asserted by a test adjacent to the rejection suite
- [ ] `make test` exits 0

---

### Sortie 16: Leaf-invariant guard

**Priority**: 18.9 — blocks 5 sorties; low complexity, high risk — it must be observed *failing* on a real PR, and it modifies a workflow that branch protection already depends on

**Entry criteria**:
- [ ] Sortie 15 complete (rejection gates green)

**Tasks**:
1. Write `scripts/check-leaf-invariant.sh`, and add it as a **step inside the existing `Test on macOS` job** in `tests.yml` — not as a new job. Sortie 4 froze branch protection at exactly `["Test on macOS", "Test on iOS Simulator"]`, so a new job would not be a required context and a violating PR would merge green. A guard that does not gate is decoration. (If a separate job is preferred instead, this sortie must also re-`PUT` the branch protection to add its context — do one or the other, never neither.)
2. The script fails if `Package.swift` names any `intrusive-memory` package (RQ-INV-1, acceptance criterion 9).
3. It fails unless `Package.resolved` holds exactly **two** pins, identities `yams` and `swift-argument-parser` (D-6).
4. It fails unless the `SwiftReparto` target's dependencies — read from `swift package dump-package`, not from a grep of the manifest text — are exactly `[Yams]`. **This is the check that matters most now that a CLI exists**: `ArgumentParser` leaking onto the library target is invisible in a green build and silently puts an argument parser in every consumer's link line.
5. It fails unless `import Yams` appears only in `Sources/SwiftReparto/YAMLCoding.swift`, and `import ArgumentParser` only under `Sources/RepartoCLICore/` and `Sources/reparto/`.
6. Comment the script with *why*: `SwiftProyecto → SwiftEchada` is a package-level cycle SwiftPM detects at manifest load, there is no target-level escape, and RQ-INV-1 is what makes every consumer relationship acyclic by construction rather than by discipline. Note that Sortie 12 is the standing temptation — `ProjectMarkdownParser` already parses `PROJECT.md`, and importing it would be the shortest path to a cycle.
7. Confirm the guard actually fires. Push a scratch branch carrying a deliberate violation **and open a PR against `development`** — `tests.yml` triggers on `pull_request`, so a branch with no PR runs nothing and proves nothing. Watch the check go red, then close the PR and delete the branch. A gate that has never failed is not known to work.

**Exit criteria**:
- [ ] `scripts/check-leaf-invariant.sh` exits 0 on `development`
- [ ] The script runs as a step within a job whose name is already a required status check, verified against `gh api .../branches/main/protection --jq '.required_status_checks.contexts'`
- [ ] The guard was observed failing on a PR carrying a deliberate violation; the run URL is recorded in the sortie's completion note
- [ ] The script also fails when `ArgumentParser` is added to the `SwiftReparto` target, verified on the same scratch PR
- [ ] `grep -c 'intrusive-memory' Package.swift` returns 0
- [ ] `Package.resolved` holds exactly two pins, identities `yams` and `swift-argument-parser`
- [ ] `grep -rl 'import Yams' Sources/` returns exactly one path

---

## WU-5 — CLI

The binary exists for two jobs (D-6): **validate** a cast document, and **import** cast data out of `PROJECT.md` into a canonical `CAST.md`. It is a shell over the library — it parses no YAML and serializes no markdown of its own, so RQ-INV-2's one-writer rule survives the binary's existence.

### Sortie 17: `reparto validate` and `reparto import`

**Priority**: 17.2 — blocks 4 sorties; the CLI surface Sortie 18 tests, and task 6a's output sink is a design constraint that Sortie 18 cannot retrofit

**Entry criteria**:
- [ ] WU-4 complete (the library's acceptance gates all pass — the CLI must not be the first thing to exercise a code path)

**Tasks**:
1. Write `Sources/RepartoCLICore/RepartoCommand.swift`: a root `ParsableCommand` named `reparto`, with `version:` wired to a single version constant and two subcommands.
2. `validate <path>` — calls `CastMarkdownParser.parse(fileURL:)`. Exit **0** when the document parses; exit **1** on any `CastParseError`. Print the error's `errorDescription` to **stderr**, nothing to stdout. Add `--quiet` to suppress the message and rely on the exit code alone.
3. `import <project-md-path>` — calls `ProjectCastImporter`, then `CastMarkdownParser.write(document:to:)`. **`--output` defaults to `<PROJECT.md directory>/CAST.md`** (D-7): the two files share a directory, and that is what makes every relative path in the imported roster still correct.
3a. **Refuse to overwrite an existing file unless `--force` is passed**, exiting non-zero with a distinct message. Cast data is hand-maintained and a silent clobber of a `CAST.md` is the exact class of loss this package exists to prevent.
3b. **Refuse an `--output` in a different directory from the source `PROJECT.md` unless `--force` is passed**, with a message naming the reason. Every path in the document is relative to its own directory (D-7), so writing it elsewhere silently invalidates all of them — the file still parses, and every `.vox` pointer in it is wrong. This failure is invisible until something tries to load a voice, which is why it is refused rather than warned about.
4. Add `--dry-run` to `import`: write nothing, print the `CAST.md` that would be produced to stdout. This is the reviewable path for a first migration.
5. **Every command is a thin shell.** No command may contain YAML handling, front-matter splitting, or string-built markdown. The only calls into the library are `parse`, `generate`, `write`, and `ProjectCastImporter`. If a command needs behavior the library lacks, that is a library change, not a CLI workaround.
6. Map errors to exit codes in exactly one place, so the mapping cannot drift between subcommands. Document the codes in the command's `abstract`/`discussion` so `reparto --help` is the spec.
6a. **Route every byte of command output through an injectable sink** — an `OutputSink` (or equivalent) with separate `stdout`/`stderr` channels, defaulting to the real streams and overridable at construction. Do **not** call `print` or `FileHandle.standardError.write` directly from any command body. This is a design constraint on this sortie, not a later refactor: a command that writes to the global streams cannot be asserted on without spawning a subprocess, and Sortie 18 is forbidden from spawning one. Getting it wrong here means Sortie 18 rewrites this sortie's code instead of testing it.
7. Write `Sources/reparto/main.swift` as the thin entry point that constructs the real sink, calls into `RepartoCLICore`, and does nothing else.
8. Do not add subcommands beyond these two. Everything else — generating prompts, discovering characters, touching `.vox` files — belongs to a named owner in REQUIREMENTS.md §5.

**Exit criteria**:
- [ ] `make release` exits 0 and `./bin/reparto --version` prints a version and exits 0
- [ ] `./bin/reparto validate <valid fixture>` exits 0 and writes nothing to stdout
- [ ] `./bin/reparto validate <each rejection fixture>` exits 1 and writes the matching `errorDescription` to stderr
- [ ] `./bin/reparto import <PROJECT.md fixture>` with **no** `--output` writes `CAST.md` beside the source file, and `./bin/reparto validate` then accepts it
- [ ] `import` against an existing output path exits non-zero without modifying that file, verified by comparing its SHA-256 before and after
- [ ] `import --output` pointing at a different directory exits non-zero and writes nothing, and the message names the relative-path reason (D-7)
- [ ] The same command with `--force` succeeds, so the refusal is a guard rather than a hard block
- [ ] `import --dry-run` writes the document to stdout and creates no file
- [ ] `grep -rcE 'import Yams|"---"|front ?matter' Sources/RepartoCLICore/ Sources/reparto/` returns 0 — the CLI does no parsing or serialization of its own
- [ ] `grep -rcE '^\s*print\(|standardError' Sources/RepartoCLICore/` returns 0 — all output goes through the injectable sink (task 6a)
- [ ] A `RepartoCLICore` command can be constructed with a non-default sink from a test target, verified by compiling one such call
- [ ] `reparto --help` documents the exit codes

---

### Sortie 18: CLI tests and release packaging

**Priority**: 12.0 — blocks 3 sorties; proves the packaging rather than the logic — the only sortie that demonstrates the shipped artifact runs

**Entry criteria**:
- [ ] Sortie 17 complete (both subcommands work when driven by hand)

**Tasks**:
1. Write `Tests/SwiftRepartoTests/CLITests.swift` against `RepartoCLICore` directly — not by spawning the binary. Cover: argument parsing for both subcommands, the error→exit-code mapping for every `CastParseError` case, `--force` refusal, `--dry-run` producing output without a write, and a missing `--output`.
2. Assert stdout and stderr **separately**, through the injectable sink Sortie 17 task 6a built. If any command still writes to the global streams, that is a Sortie 17 defect — report it rather than refactoring it here, so the sortie boundary stays honest about where the bug was.
3. Add one end-to-end binary smoke test to `tests.yml`'s macOS job — `make release`, then run `./bin/reparto validate` against a fixture and assert the exit code. Unit tests prove the mapping; only the binary proves the packaging.
4. Verify `make release` produces a binary that runs on a machine without the build tree present: check with `otool -L ./bin/reparto` that it links nothing from `DerivedData`.
5. Confirm the `reparto` scheme resolves in CI. SwiftPM's per-product scheme is what `make release` builds, and it is generated rather than committed — `xcodebuild -list` after `make resolve` is the check.

**Exit criteria**:
- [ ] `make test` exits 0 with `CLITests` passing
- [ ] Every `CastParseError` case has a test asserting the exit code it maps to
- [ ] `tests.yml`'s macOS job builds the binary and runs `./bin/reparto validate` against a fixture, and the job is red if that exits non-zero
- [ ] `otool -L ./bin/reparto` names no path under `DerivedData`
- [ ] No test in `CLITests.swift` spawns a subprocess

---

## WU-6 — Beta Release

### Sortie 19: Repository documentation set

**Priority**: 8.2 — blocks 2 sorties; no code surface, but `AGENTS.md` is where every standing rule in this plan becomes discoverable to the next agent

**Entry criteria**:
- [ ] WU-5 complete (CLI works and is tested)

**Tasks**:
1. Update `README.md`: adjust the frontmatter `status`, replace the "design docs only" note with an install snippet pinning the beta, and add a usage example showing both paths — import from `PROJECT.md`, and parse → mutate → write `CAST.md`.
2. Write `AGENTS.md` with `type: doc`: the leaf invariant, the one-writer rule, the narrowed no-inference rule (read `cast:` from `PROJECT.md` on the import path only; never write it), the branch topology, the Makefile-only build rule (never `swift build` / `swift test`), and a current-version marker.
3. Add a **Schema** section to `AGENTS.md`: the current schema version, what an unversioned document means, the forward-compatibility policy, and the standing rule that every emitted document is stamped. Record that `appearance` is deferred (D-3) and survives in `extraKeys` until it is declared — and that adding it later moves those keys from `extraKeys` to a typed field, which is exactly the migration the version field exists to make tractable.
4. Add a **CLI** section: `reparto validate` and `reparto import`, the exit-code contract, and the standing rule from D-6 that the binary is a shell over the library and never parses or serializes on its own.
4a. Add a **Release** section: two products, so a release is a tag + GitHub release from `main`, and `release.yml` attaches an arm64 macOS tarball. The Homebrew tap **pulls** on a 6-hour cron and source repos never dispatch to it. Record the two facts that decide when a formula appears: `scripts/reconcile-formulas.sh` iterates `Formula/*.rb` (verified at `:41`), so it will never discover this repo on its own and the first formula must be created by hand in the tap; and it resolves versions through `repos/<owner>/<repo>/releases/latest`, which deliberately excludes prereleases. **Therefore no formula during the beta** — it is created when the first stable release ships.
5. Symlink or copy `CLAUDE.md` and `GEMINI.md` to `AGENTS.md`, matching SwiftEscribo and SwiftProyecto.
6. Write `CHANGELOG.md` with an entry for the initial beta.
7. Record the consumer contract from REQUIREMENTS.md §7 — which package writes which keys — so the boundary is checkable from this side.
8. Update `README.md`'s install section to cover **both** products: SwiftPM for the library, and `gh release download` for the binary. Do not document `brew install` yet — no formula exists during the beta (task 4a).
9. **In-source API documentation is Sortie 19a's deliverable, not this sortie's.** Do not add doc comments to `Sources/` here — a docs sortie that also sweeps every source file is the one that runs out of context halfway through and leaves the set half-written.

**Exit criteria**:
- [ ] `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CHANGELOG.md`, `README.md`, `LICENSE` all exist at the repo root
- [ ] `CLAUDE.md` and `GEMINI.md` resolve to the same content as `AGENTS.md`, verified by comparing SHA-256 (or by `readlink` if symlinked)
- [ ] `README.md` frontmatter no longer says `pre-alpha`, and the install snippet names the beta
- [ ] `AGENTS.md` documents the schema version, the unversioned-document rule, the `appearance` deferral, the CLI exit-code contract, and why no Homebrew formula exists during the beta
- [ ] `README.md` documents both products and does **not** mention `brew install`
- [ ] `git diff --stat` shows no file under `Sources/` was modified by this sortie

---

### Sortie 19a: DocC comments on every public declaration

**Priority**: 5.2 — blocks 1 sortie; comment-only sweep plus a lint gate — deliberately last-but-one because it touches every source file and must not land before the acceptance gates ran

**Entry criteria**:
- [ ] Sortie 19 complete (repo documentation set in place, so the in-source comments can point at it rather than restate it)

**Tasks**:
1. Add DocC-style doc comments to every public declaration: `CastDocument`, `CastMember`, `CastSchemaVersion`, `Gender`, `CastMarkdownParser`, `ProjectCastImporter`, `CastParseError`, `AnyCodable`, `merging(_:)`, and the `RepartoCLICore` command types.
2. Each type's comment states what it owns and what it must never do — the invariant, not a restatement of the name. `CastMarkdownParser` names the one-writer rule; `ProjectCastImporter` names the read-only-with-respect-to-`PROJECT.md` rule (D-4, D-13); `AnyCodable` names its canonical-copy status and the `SwiftProyecto → SwiftReparto` collapse direction (RQ-13, D-9).
3. Document the deprecated `voiceDescription` shim's removal horizon (D-2) and the `extraKeys` accessor pair's reason for existing (D-8) on the declarations themselves, so a consumer reading the API sees the constraint without reading `AGENTS.md`.
4. Write `scripts/check-public-docs.sh` that fails when any `public` declaration under `Sources/` lacks a preceding `///` comment, and add it as a **step inside the existing `Lint` job** — not as a new job, for the same branch-protection reason Sortie 16 gives.
5. Do not change any declaration's signature, access level, or body. This sortie adds comments and one script; a behavior change here would land after the last acceptance gate ran.

**Exit criteria**:
- [ ] `scripts/check-public-docs.sh` exits 0 on the working tree
- [ ] The script exits non-zero when a `///` comment is deliberately removed from one public declaration, verified locally before restoring it
- [ ] The script runs as a step in the `Lint` job, verified by grep against `.github/workflows/lint.yml`
- [ ] `make build` and `make test` both exit 0
- [ ] `git diff` against Sortie 19's HEAD touches only comment lines, `scripts/`, and `.github/workflows/lint.yml` — no signature or body change, verified by review of the diff

---

### Sortie 20: Tag the beta and register in `collection.json`

**Priority**: 4.2 — blocks nothing; terminal sortie, but carries real external-API risk (prerelease handling in the collection tooling and the first-ever `release.yml` run are both unverified)

**Entry criteria**:
- [ ] Sortie 19a complete (documentation set and API comments in place, build and tests green)

**Tasks**:
1. Tag the initial beta from `main` as a **prerelease** and publish a GitHub release marked prerelease. Derive the version from `REQUIREMENTS.md`'s amended frontmatter; confirm no higher semver tag exists first.
2. Add `intrusive-memory/SwiftReparto` to `/Users/stovak/Projects/package-collection/collection.json` via the `update-package-library` skill's `add-package` path — do not hand-edit the JSON.
3. **Verify the collection tooling accepts a prerelease.** `update-package-library` treats published releases as the only source of truth and never falls back to tags; whether it also filters out prereleases is unverified. If it skips the beta, stop and report rather than hand-editing `collection.json` or promoting the tag to a full release to work around it — either would defeat the tool's invariant.
4. Bump `revision` and refresh `generatedAt` per the collection's format.
5. Confirm `release.yml` fired on the published prerelease and attached `reparto-<version>-arm64-macos.tar.gz`. This is the first time that workflow runs; if it fails, fix it and re-run via `workflow_dispatch` rather than hand-uploading the asset.
6. Verify the collection entry carries the published beta and its `6.2` manifest, both products (`SwiftReparto` library and `reparto` executable), and that `readmeURL` resolves.
7. **File the SwiftEscribo follow-on issue** (D-9): `gh issue create --repo intrusive-memory/SwiftEscribo` recording that `Sources/EscriboProject/CastMember.swift` (plus its own `AnyCodable.swift`) is a third copy of the cast model, that SwiftReparto is now the canonical home, and that folding it in has to reckon with SwiftEscribo's zero-shipping-dependency charter and its SwiftLint rule — so "depend on SwiftReparto" is not free there and the issue must not presume it. Do **not** open a corresponding issue on SwiftProyecto; that repo is out of scope for this mission (D-13).
8. **Homebrew: deferred for the beta, and record the reason rather than skipping it silently.** The package now ships an executable, so it *will* get a formula — but not yet, for two verified reasons: `intrusive-memory/homebrew-tap`'s `scripts/reconcile-formulas.sh` iterates `Formula/*.rb` (verified at `:41`), so it never discovers a repo that has no formula, and it resolves versions via `repos/<repo>/releases/latest`, which excludes prereleases (verified at `:66-68`). Do **not** create the formula now and do **not** promote the beta to a full release to make Homebrew work. Record in the completion note that the formula is created when the first stable release ships.

**Exit criteria**:
- [ ] `gh release view --repo intrusive-memory/SwiftReparto --json isPrerelease --jq .isPrerelease` returns `true`
- [ ] The release has exactly one attached asset, matching `reparto-*-arm64-macos.tar.gz`
- [ ] Downloading and extracting that asset yields a `reparto` binary whose `--version` exits 0
- [ ] `python3 -c "import json;d=json.load(open('collection.json'));print(any(p['url'].endswith('SwiftReparto.git') for p in d['packages']))"` prints `True`, **or** the sortie reports that the tooling declined the prerelease and stops
- [ ] The entry's `manifests['6.2'].products` names both `SwiftReparto` and `reparto`
- [ ] `curl -sfI <readmeURL>` returns 200
- [ ] `gh issue list --repo intrusive-memory/SwiftEscribo --search 'EscriboProject cast' --json number --jq 'length'` returns at least 1 (D-9)
- [ ] `gh issue list --repo intrusive-memory/SwiftProyecto --search 'SwiftReparto' --json number --jq 'length'` returns 0 — no SwiftProyecto work was scheduled by this mission (D-13)
- [ ] `ls ~/Projects/homebrew-tap/Formula/ | grep -ci reparto` returns 0, and the completion note records Homebrew as "deferred — tap tracks stable releases only; formula created at first stable"

---

## Decisions

<!-- Resolved before refinement. Recorded here so the reasoning survives the sortie that consumes it. -->

### D-1: YAML dependency is Yams, not `marcprux/universal`

**Decision**: `jpsim/Yams` is SwiftReparto's sole dependency. `YAMLDecoder` parses, `YAMLEncoder` emits, both behind `YAMLCoding.swift`. No hand-written emitter. Supersedes RQ-16 as written; Sortie 2 carries the amendment.

**Why**: `universal` is a parser and says so — its README opens "A zero-dependency cross-platform Swift *parser*," and `Sources/YAML/YAML.swift` exposes only `parse(_:)`, `parse(yaml:)`, `parse(yamls:)`. Its `Encodable` conformance targets a *JSON*-compatible encoder. It cannot write YAML and never claimed to.

The cost of that gap is this org's shipping history. SwiftProyecto uses `universal` and hand-rolls emission, which has shipped at least four data-loss bugs:

| Release | Failure |
|---|---|
| v4.3.2 (#58/#44) | `CastMember` unknown keys dropped on round-trip |
| — (#55) | nested `episodes_index` flattened through `NSDictionary.description`; 309-line `PROJECT.md` → 103 lines, no error |
| v4.8.1 (#72), 2026-07-31 | `replacingCastBlock` terminated its scan on a blank line, leaving stale indented lines below the new block — re-parsed as **duplicate cast members** |
| v4.8.1 (#72) | the column-0-comment variant of the same splice bug |

`RQ-INV-2` exists because of these. A `Codable`-driven encoder cannot drop a key it was handed; a hand-written emitter is a more careful version of the approach that failed four times.

**Alternatives considered and rejected**: A GitHub survey returns no credible competitor. Yams is 1262★ and active. `behrang/YamlSwift` (414★) loads YAML and does not emit. `universal` (23★) is parse-only. Everything else claiming an emitter — `seznam/swift-uniyaml` (7★), `Argsment/YAML` (1★), `edgeengineer/yaml` (1★) — is a single-digit-star project with no production users. **The field is Yams or hand-rolled.**

**The YAML 1.1 objection, investigated and dismissed**: Yams wraps libyaml, which implements YAML **1.1**, where `yes`/`no`/`on`/`off` are booleans — the "Norway problem." This collides with the schema twice: `language` is BCP-47 and Norwegian is `no`; and `extraKeys` carries arbitrary human YAML, which RQ-4 promises to preserve. Confirmed against a 1.1 implementation: `language: no` loads as boolean `False`.

**Yams is not exposed, by deliberate design.** `Decoder.swift:147` constructs its parser as `Parser(yaml:, resolver: Resolver([.merge]), encoding:)` — **not** `Resolver.default` (`[.bool, .int, .float, .merge, .null, .timestamp, .value]`). The `Codable` path performs no implicit type resolution beyond merge keys: plain scalars arrive tagged `.str` and the target Swift type decides. `String.construct` returns `scalar.string` verbatim (`Constructor.swift:387`); `Bool.construct` opens with `if scalar.tag.name == .str { return nil }` (`:154-157`). This is load-bearing and undocumented, so Sortie 8 task 7 pins it with a regression test.

**What it costs**: RQ-16's original justification was "Pure Swift, no heavy transitive graph." Yams meets the second clause and fails the first — libyaml is a vendored C target. The resolved graph is still one pin. That clause was written before anyone verified `universal` could write YAML, which makes it a requirements bug rather than a constraint worth preserving.

**Residual risk**: Yams ships `swift-tools-version:5.7` with a C target and is unverified against `.v26` + `.v6` + strict concurrency. **Sortie 1 task 6 proves it before any other code exists.** Sortie 1 task 7 also forbids the three tempting workarounds.

**Out of scope**: migrating SwiftProyecto, SwiftSecuencia, SwiftVinetas, or flux-2-swift-mlx off `universal`.

---

### D-2: the Swift property is `voicePrompt`; `voiceDescription` survives as a deprecated shim

**Decision**: `CastMember`'s Swift property is `public var voicePrompt: String?`, with a forwarding `@available(*, deprecated, renamed: "voicePrompt") public var voiceDescription: String?` (both accessors) removed in this package's next major release version.

**Nothing about the file format changes.** The emitted key is already `voicePrompt` — SwiftProyecto encodes `voiceDescription` *to* `.voicePrompt` (`CastMember.swift:502`) and decodes `.voicePrompt ?? .voiceDescription` (`:458-461`). Only the Swift identifier lagged. RQ-3 is unaffected.

**Why the shim**: REQUIREMENTS.md §7 undercounts the migration. It says SwiftEchada imports SwiftProyecto "at exactly two sites for exactly two symbols" — a count of `import` statements, not usages. Measured: **~24 `CastMember.voiceDescription` accesses across 13 files** (4 under `Sources/`, 9 under `Tests/`). The shim lets SwiftEchada land the module swap and the rename as two reviewable changes, with the compiler finding every site.

**The trap this creates**: SwiftEchada has its **own** `CharacterInfo.voiceDescription` (`Sources/SwiftEchada/CharacterInfo.swift:5`), ~10 mentions, a different type. A global replace across SwiftEchada would rename it too. SwiftEchada also already uses `voicePrompt` in 16 files, so both vocabularies are interleaved there and a mechanical `sed` cannot distinguish them.

**Out of scope**: performing SwiftEchada's migration.

---

### D-3: the first beta ships without `Appearance`

**Decision**: `Appearance` is **not** defined in the beta. No `Appearance` type, no `appearance` in `CodingKeys`. It is added in a later version, once SwiftSemblanzas has fully scoped what it needs. Resolves OQ-5 by deferral. Sortie 2 amends §3.3 and acceptance criterion 6.

**Why deferral beats guessing**: RQ-5's justification was that reserving the field now makes a later *addition* routine while changing its shape is not. RQ-Q2 then admitted the shape is genuinely unknown — one `lora: String?`, or `[LoRAAsset]` with per-adapter rank, scale, and engine compatibility, as SwiftSemblanzas' own `REQUIREMENTS.md` §4.1 suggests. Shipping a guess in a released schema converts a cheap addition into an expensive change. Shipping nothing keeps the addition cheap.

**The deferral costs no data, and that is testable.** Because `appearance` is not a declared key, an `appearance:` block in existing data is swept into `extraKeys` and re-emitted verbatim under RQ-4. `all-fields-CAST.md` carries one specifically to prove it (Sortie 13 task 4, Sortie 14 task 4). Nothing in production writes `appearance` today, so there is no live data to preserve yet — but the mechanism is proven before there is.

**What the later addition looks like**: declaring `appearance` moves those keys from `extraKeys` to a typed field. That is a schema change, which is exactly what D-5's version field exists to make tractable.

---

### D-4: Reparto imports cast from `PROJECT.md`

**Decision**: SwiftReparto reads the `cast:` key out of a `PROJECT.md` byte stream and produces a `CastDocument`. **The dividing line is importing the data**: Reparto imports the cast; it does not own, resolve, or write `PROJECT.md`. Sortie 12 implements it; Sortie 2 amends RQ-INV-3 and the §2 table.

**This narrows a load-bearing invariant, so the narrowing is stated precisely.** RQ-INV-3 (line 87) forbids `read PROJECT.md` outright, and the §2 table lists `PROJECT.md` under "Never touches." As amended, SwiftReparto may read **only** the `cast:` key from a `PROJECT.md` it is handed, on the import path, and may never write that file or read any other key from it. Everything else RQ-INV-3 forbids — screenplay discovery, model calls, network, resolving defaults — stands unchanged.

**Why this is coherent rather than a boundary leak**: the cast data is Reparto's by ownership (§2); `PROJECT.md` is merely where it lives today. Importing is a one-directional, read-only migration of data Reparto already owns out of a file it does not. The alternative — every consumer writing its own extraction — is the same failure mode RQ-INV-2 exists to prevent, one layer up.

**The RQ-INV-1 hazard, called out because it is the likely failure**: `SwiftProyecto.ProjectMarkdownParser` already parses `PROJECT.md`. Reaching for it would add an `intrusive-memory` dependency and create the exact package-level cycle this library exists to make impossible. Sortie 12 parses the front matter itself through `YAMLCoding`, and Sortie 16's guard is what notices if anyone takes the shortcut.

**One decoder, not two**: the import path decodes members through the same `CastMember` decoder as `parse`, so RQ-3's leniencies and RQ-4's guarantees apply identically. A second decoder would drift.

---

### D-5: every emitted `CAST.md` carries a schema version

**Decision**: `CAST.md` documents this library emits always carry a schema version in their front matter. Reverses RQ-Q3, which recommended against one. Sortie 2 carries the amendment; Sortie 7 defines the type; Sortie 10 stamps it on every write.

**Why the reversal**: RQ-Q3's argument was "nothing needs it yet, and an unused version field invites divergent interpretations." That held when `CAST.md` was a finished 1.0 schema. It does not hold now: D-3 defers `Appearance` explicitly so the schema *will* change, and the beta line commits to iterating on it. A version field is not speculative when a schema change is already scheduled.

**Legacy input is accepted, not rejected.** A document with no version parses to an unversioned sentinel and is stamped with the current version on the next write. Existing hand-written files keep working and normalize on first write. That is the mechanism that makes the iterative approach safe.

**Forward compatibility must be a typed outcome.** What happens when a document declares a version newer than the library supports is settled by **D-12** (typed rejection via `.unsupportedSchemaVersion(found:supported:)`). It may never be a silent best-effort parse — that is how a newer field gets dropped by an older writer, which is RQ-INV-2's failure with a version number attached.

**Interaction with RQ-11**: stamping a version changes bytes relative to unversioned input. RQ-11 already scopes round-trip identity to "any `x` this library emitted, and every pinned fixture," so the pinned fixtures are written in emitted, versioned form. Sortie 10 task 7 and Sortie 14 task 6 assert the legacy → stamped → byte-stable sequence directly.

### D-6: SwiftReparto ships a CLI (`reparto`)

**Decision**: two products — the `SwiftReparto` library and a `reparto` executable. The binary exists for two jobs: **validate** a cast document, and **import** cast data out of `PROJECT.md` into a canonical `CAST.md`. Reverses RQ-17 ("one product, one target, no CLI target") and §5's non-goals row "Any CLI | None". Sortie 2 carries both amendments; WU-5 implements it.

**The binary is a shell, and that is what preserves RQ-INV-2.** Writing a canonical `CAST.md` happens exactly two ways: programmatic use of the library, or `reparto import`. The CLI parses no YAML, splits no front matter, and builds no markdown — it calls `parse`, `generate`, `write`, and `ProjectCastImporter` and does nothing else. One writer, reachable two ways. Sortie 17's exit criteria grep the CLI sources to enforce it.

**Target shape** — four targets, two products, and the split is load-bearing:

| Target | Depends on | Product |
|---|---|---|
| `SwiftReparto` | Yams | library |
| `RepartoCLICore` | `SwiftReparto`, `ArgumentParser` | **none** |
| `reparto` | `RepartoCLICore` | executable |
| `SwiftRepartoTests` | `SwiftReparto`, `RepartoCLICore` | — |

`RepartoCLICore` exists so command logic is unit-testable without spawning a subprocess, and so `ArgumentParser` never lands on the library target. It is deliberately **not** a product: consumers get the library and the binary, and nothing else becomes public API by accident. This is SwiftEchada's `EchadaCLICore` shape, which is the org's precedent.

**What it costs, stated plainly**: `swift-argument-parser` enters the resolved graph of every package that depends on SwiftReparto — SwiftEchada, SwiftSemblanzas, Produciesta. SwiftPM resolves the whole package graph even when a consumer links only one product, so their `Package.resolved` gains a pin they never asked for. It is not linked into their binaries, and SwiftProyecto already has exactly this shape, so the org has accepted the cost before. But this is a leaf package that everything depends on, and "leaf" now means one fewer thing than it did. RQ-INV-1 is untouched — `swift-argument-parser` is Apple's, not `intrusive-memory`'s — so no cycle becomes possible.

**Consequences that reverse earlier positions in this plan**:
- `release.yml` is now **required** (Sortie 3), where the library-only plan forbade it.
- The release carries a binary asset, where the library-only plan asserted it must not.
- Homebrew moves from "N/A by design" to "deferred, with a date." Two verified facts set that date: `scripts/reconcile-formulas.sh` iterates `Formula/*.rb` (verified at `:41`) and so never discovers a repo with no formula, and it resolves versions through `releases/latest`, which excludes prereleases. **No formula during the beta; created at first stable release.**
- `Package.resolved` becomes tracked (Sortie 1), reversing the library-package convention — a binary built by CI from an unpinned graph is not reproducible.
- Sortie 16's guard gains its most important check: that `ArgumentParser` has not leaked onto the library target. That failure is invisible in a green build.

**Deliberately not in scope**: any subcommand beyond `validate` and `import`. Generating prompts, discovering characters, and touching `.vox` files all have named owners in REQUIREMENTS.md §5, and a CLI is the easiest place for that boundary to erode.

### D-7: paths are relative to the `CAST.md` directory, normalized on the way in

**Decision**: every path string a `CastDocument` holds is relative to the directory containing its `CAST.md`, always, with no exceptions and no second base. `CAST.md` lives beside `PROJECT.md` in the project directory, so that directory is the single anchor for `voices.*` and every future path field. Resolves the audit's C-2.

**Normalization happens on the way in, never on the way out.** This is the whole of the decision, and it is what makes `generate` and `write` agree:

| Entry point | Knows the directory? | Behavior |
|---|---|---|
| `parse(fileURL:)` | yes | relativize any absolute path against the file's directory |
| `ProjectCastImporter` | yes | same, against the `PROJECT.md`'s directory |
| `parse(content:)` | **no** | leave path strings verbatim; documented as the caller's responsibility |
| `generate(document:)` | — | emits exactly what the document holds. **No path logic.** |
| `write(document:to:)` | — | `generate` + write. **No path logic.** |

**Why this shape rather than relativizing at emit**: the plan previously said `generate` should relativize "when the directory is known" — but `generate(document:)` takes no URL and never knows it. That left only two possibilities, both broken: `generate` cannot satisfy RQ-6, or `write` relativizes and `generate` does not, in which case the two produce different bytes and RQ-11's SHA-256 gate is asserting on a string that never reaches disk. Normalizing at the boundary removes the fork: there is one code path to emit, and it does no path work at all.

**The invariant this buys**: a `CastDocument` obtained from a file never contains an absolute path. RQ-6's "absolute paths decode but are never emitted" then holds by construction rather than by a check at write time.

**RQ-7 is untouched.** Relativization is string manipulation — trimming a known directory prefix. It stats nothing, resolves no symlinks, and never asks the filesystem whether a path exists. A path that does not share the base directory's prefix is left exactly as it is; the library does not invent `../` chains to reach outside the project directory, because it has no way to know whether that is meaningful without touching the disk.

**Because `CAST.md` sits beside `PROJECT.md`, import requires no path rewriting at all.** Both files share a directory, so a path already relative to the `PROJECT.md` is already relative to the `CAST.md`. The importer runs the same normalization anyway — for the absolute-path case, and so there is one rule rather than one rule plus an exception.

**The corollary the CLI has to enforce**: writing the imported document anywhere other than beside its source `PROJECT.md` silently invalidates every relative path in it. `reparto import` therefore defaults `--output` to `<PROJECT.md directory>/CAST.md` and refuses a destination in a different directory unless the caller insists (Sortie 17).

---

### D-8: `extraKeys` is `public private(set)`, reachable through named accessors

**Decision**: `CastMember` declares `public private(set) var extraKeys: [String: AnyCodable]`, plus `public subscript(extra key: String) -> AnyCodable?` for reads and `public mutating func setExtra(_:forKey:)` for writes. Resolves OQ-3. Sortie 6 implements it; Sortie 14 asserts through it.

**Why**: REQUIREMENTS.md §7 has SwiftSemblanzas reading `bio`, which lives in `extraKeys`, and D-3 now routes `appearance` through the same dictionary — so this is the access path for a whole deferred field, not one note. SwiftProyecto's `internal` declaration (`CastMember.swift:163`) makes that impossible cross-module.

**Why not plain `public`**: nothing needs to replace the extras dictionary wholesale, and permitting it reintroduces the exact overwrite failure RQ-INV-2 exists to prevent — one assignment silently discards every key the writer did not know about.

**Why not `@testable import`**: acceptance criterion 3 asserts `bio` preservation from a separate test module. Reaching it through a testing-only door would make the acceptance test pass through an entrance consumers do not have, which is the test proving something other than the requirement.

---

### D-9: SwiftEscribo's third copy of the cast model is out of scope, but recorded

**Decision**: Ship the beta with the copies REQUIREMENTS.md accounts for. Add one sentence to RQ-13 recording that a third copy exists at `SwiftEscribo/Sources/EscriboProject/CastMember.swift` (Sortie 2 task 9), and file a follow-on issue on SwiftEscribo (Sortie 20 task 7). Resolves OQ-4.

**Why the note is not optional**: RQ-13 currently reads as though the twin count is two and bounded. It is three — `EscriboProject` carries `Gender` at :38, `CastMember` at :109, the same `voicePrompt`/`voiceDescription` decode at :469-471, and its own `AnyCodable.swift`. The next person to plan reunification will plan against a wrong number, and the cost of preventing that is one sentence.

**Why the collapse is not scheduled here**: same sequencing argument the requirements already make for RQ-Q1. SwiftEscribo also declares a zero-shipping-dependency charter enforced by a SwiftLint rule, so "`EscriboProject` depends on SwiftReparto" is not free there and is not this mission's call to make.

---

### D-10: the body is preserved byte-exactly, by index arithmetic

**Decision**: `CastMarkdownParser` locates the closing `---` delimiter's line terminator **by index** and takes everything after it as an untouched substring. No `split`, no `joined`, no `trimmingCharacters`. Resolves OQ-6. Sortie 9 tasks 2-3 implement it; Sortie 14 asserts it.

**Why**: RQ-8 says "byte-for-byte" without qualification, and RQ-11 asserts by SHA-256 rather than by eyeball — the requirements author pre-committing to this reading. SwiftProyecto's `ProjectMarkdownParser.parse` (`:82-110`) does `split(separator: "\n", omittingEmptySubsequences: false)` → `joined(separator: "\n")` → `trimmingCharacters(in: .whitespacesAndNewlines)`, which silently converts CRLF→LF and strips the trailing newline. Both are byte changes.

**Why it is worth ~20 lines of index arithmetic**: porting the familiar helper fails at Sortie 14, five sorties after the cause, on every fixture carrying a CRLF or a trailing newline. Silent normalization is also the bug family RQ-INV-2 exists to eliminate — the same class as the four SwiftProyecto data-loss releases in D-1's table.

---

### D-11: branch protection follows SwiftAcervo, with `enforce_admins: false`

**Decision**: `main` gets `strict: true`, contexts exactly `["Test on macOS","Test on iOS Simulator"]`, `required_approving_review_count: 0`, `allow_force_pushes: false`, `allow_deletions: false`, **`enforce_admins: false`**. `development` gets the same minus `enforce_admins`. Resolves OQ-7. Sortie 4 applies it.

**Why SwiftAcervo**: it is the only surveyed repo whose protection both names real contexts and matches the two-job CI this plan builds. SwiftProyecto's `enforce_admins: true` with **empty** `contexts` is the worst available shape — it blocks the maintainer while checking nothing.

**What `enforce_admins: false` costs, stated plainly**: on a single-maintainer repo the admin *is* the maintainer, so protection is advisory against deliberate action. The real enforcement is `strict: true` plus non-empty contexts, which stops the accident — a stale branch merged green — rather than the intent.

**The consequence for Sortie 4's verification**: a direct push test **cannot** prove the gate, because an admin bypasses it and the push succeeds. Sortie 4 asserts the protection's API state instead. A verification that passes for the wrong reason is worse than none.

---

### D-12: `schemaVersion` is a monotonic integer starting at 1; newer versions are rejected

**Decision**: the front-matter key is `schemaVersion`. The value is a **monotonic integer starting at 1** — not a string, not semver. Absent means unversioned legacy. A document declaring a version greater than `CastSchemaVersion.current` throws `.unsupportedSchemaVersion(found:supported:)`. Resolves OQ-8. Sortie 7 defines it; Sorties 9, 10, 12, 13, 15 consume it.

**Why an integer**: it cannot be misread as a package version, cannot invite semver range logic in a document format, and cannot be ambiguous about ordering — `"1.10"` sorts before `"1.9"` as a string. This schema has no patch dimension to express.

**Why `schemaVersion` and not `version`**: RQ-Q3's original objection to a version field was that a bare `version:` "invites divergent interpretations." The qualified name says which thing is versioned.

**Why rejection rather than best-effort**: this is the conservative half of D-5's "never a silent best-effort parse." An older writer that *accepts* a newer document will confidently rewrite it and drop whatever it did not understand — RQ-INV-2's exact failure with a version number attached. A caller who wants best-effort can catch the typed error and decide; a caller handed a silent lossy parse cannot.

**Interaction with key order**: the version is emitted in a fixed position — `type: cast`, `schemaVersion`, `cast:` — which forecloses `sortKeys = true` in Sortie 8, since lexicographic order yields `cast` → `schemaVersion` → `type`. Deterministic order is guaranteed at the `encode(to:)` layer instead.

---

### D-13: SwiftProyecto is out of scope for this mission — no code, no issue, no schedule

**Decision** (**user override**, superseding OQ-9's recommendation): this mission does nothing to SwiftProyecto. It does not remove `cast:` from `PROJECT.md`, does not drop `ProjectFrontMatter.cast`, and does **not** file a tracked issue asking anyone else to. Sortie 12 stays read-only with respect to `PROJECT.md`; Sortie 17 adds no `--prune` flag.

**What this leaves open, recorded honestly**: after a project migrates to `CAST.md`, the now-duplicate `cast:` block still sits in its `PROJECT.md`, and nothing in this mission owns deleting it. Two rosters that can drift is a real exposure — the first consumer to read the stale one reintroduces the divergence SwiftReparto exists to end.

**Why the exposure is acceptable here**: nothing in this plan stalls on it, no sortie should perform it, and SwiftReparto is forbidden from writing that file regardless. Sequencing SwiftProyecto's release is a separate decision on a separate repo, and folding it into a beta mission for a leaf library would widen scope without widening capability. It is deferred, not solved — and this decision is where that is written down.

---

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). Each entry MUST be resolved before refinement can proceed past Pass 1. -->

_No blocking open questions remain. OQ-3, OQ-4, OQ-6, OQ-7, OQ-8, and OQ-9 were resolved in Pass 1 and promoted to Decisions D-8 through D-13 respectively; OQ-9 was resolved by user override rather than by its recommendation._

---

## Accepted Risks

<!-- Added by refinement Pass 5. These are not open questions — each has a decided outcome and a defined failure path. They are listed together because each one's failure is invisible unless someone is looking for it. -->

Nothing here blocks execution. Each item is a known unverified assumption with a stated handling rule, gathered in one place so a sortie agent does not have to rediscover it.

| # | Risk | Where it bites | Defined handling |
|---|------|----------------|------------------|
| AR-1 | Yams is `swift-tools-version:5.7` with a vendored C target, unverified against `.v26` + `swiftLanguageModes: [.v6]` + strict concurrency | Sortie 1 | Probe before any other code exists. On failure, **stop and escalate** — the three workarounds (lower the platform floor, drop to `.v5`, add `@preconcurrency`) are each forbidden, because each silently trades RQ-15 for a dependency choice that is the requirements author's call. A BLOCKED Sortie 1 is a correct outcome, not a retry candidate. |
| AR-2 | Yams' plain-scalar behavior (`language: no` decoding as `String`, not `Bool`) depends on `Decoder.swift:147` constructing `Resolver([.merge])` rather than `Resolver.default` — deliberate but **undocumented upstream**, so a future Yams release could change it without calling it a break | Sortie 8 | Pinned by an explicit regression test naming that file and line. A Yams bump that reddens it is a dependency decision, not a test to fix. |
| AR-3 | `update-package-library` treats published releases as the only source of truth; whether it also filters out **prereleases** is unverified | Sortie 20 | If the tooling declines the beta, **stop and report**. Do not hand-edit `collection.json` and do not promote the tag to a full release — either defeats the tool's invariant to work around it. |
| AR-4 | `release.yml` cannot be exercised until Sortie 20 cuts the first release, so it ships unrun for 17 sorties | Sorties 3, 20 | Sortie 3 verifies it structurally (`actionlint`, trigger, asset name) and records in its completion note that end-to-end is unverified. Sortie 20 fixes and re-runs via `workflow_dispatch` rather than hand-uploading the asset. |
| AR-5 | **After a project migrates to `CAST.md`, its `PROJECT.md` still carries the now-duplicate `cast:` block, and nothing owns deleting it** (D-13, user override) | Outside this mission entirely | Accepted deliberately. Two rosters that can drift is a real exposure — the first consumer to read the stale one reintroduces the divergence SwiftReparto exists to end. This mission does not solve it and does not file an issue asking anyone else to. Recorded here so the beta ships with the gap visible rather than assumed-handled. |

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 6 |
| Total sorties | 22 (20 + Sorties 1a and 19a, split in refinement Pass 2) |
| Critical path | 20 sorties |
| Parallelism | 1 supervising agent + 2 sub-agents, 2 parallel groups |
| Accepted risks | 5 (AR-1…AR-5) |
| Decisions recorded | 13 (D-1…D-7 pre-refinement, D-8…D-13 from Pass 1) |
| Open questions | 0 — all resolved in Pass 1 |
| Requirements amendments | 8 (Sortie 2) |
| Products | 2 — `SwiftReparto` library, `reparto` executable |
| Dependencies | 2 — Yams (library), swift-argument-parser (CLI only) |
| Dependency structure | layers (0→5, strict gates) |
