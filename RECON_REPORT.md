---
type: recon-report
state: current
requirements_file: REQUIREMENTS-personaje.md
requirements_sha256: bec5081dd25f018b6da467910ce624321ce06b50c309f215ff4cbf78f06b7160
project_head: 4690c30e592175c4ae533109edc641c3c2d3edc3
search_root: ~/Projects
generated: 2026-10-03
verdict: BLOCKED
---

# RECON_REPORT.md — SwiftReparto (Personaje requirements)

## Terminology

> **Mission** — A definable, testable scope of work.
> **Sortie** — An atomic, testable unit of work executed by a single agent in one dispatch.
> **Work Unit** — A grouping of sorties.

## Verdict

**BLOCKED** — 47 assumptions checked, 38 confirmed, 8 blocking (4 substantive,
2 on Part 2's missing upstream definitions, 2 wording-only), 1 unverifiable.

Re-run on 2026-10-03 against the same requirements and the same HEAD. The
`repo` locus is carried forward: same revision, no tracked change. The
SwiftCompartido locus was re-verified by a spoke at `b0bd600` (it moved one
commit), and the external facts behind each blocking finding were re-read.
Changes from the first run: C-05 and C-06 are now REFUTED, C-01 is CONFIRMED,
C-08 is new, and A-26 has a firmer reason.

The audit covers `REQUIREMENTS-personaje.md` and the `REQUIREMENTS.md` it
incorporates by reference (RQ-19 to RQ-25, D-14). Almost every claim about
SwiftReparto's own source holds, line references included. The blocking
findings are about what the requirements assume of *other* things: Granville's
live `CAST.md`, the leaf invariant, and a decision recorded in Personaje.

## Assumption Findings

Locus `repo` is this worktree at `4690c30`. Paths under `Sources/` are
`Sources/SwiftReparto/` unless shown otherwise.

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| A-01 | A-FILE | `REQUIREMENTS.md` is tracked, added by `4690c30`, defines RQ-19..RQ-25 and D-14 | repo | CONFIRMED | `REQUIREMENTS.md:42-49`; `git show --stat 4690c30` |
| A-02 | A-DATA | RQ-21 sits at about lines 101–111 and checks `<character>/manifest.json` | repo | CONFIRMED | `REQUIREMENTS.md:101`, `:108-111` |
| A-03 | A-API | `[CastMember].merging(_:)` at `:130`, `backfilled(from:)` at `:161-192` | repo | CONFIRMED | `CastMember+Merging.swift:130`, `:161` (`backfilled` is `fileprivate`) |
| A-04 | A-BEHAVIOR | Merge appends unmatched members, fills only nil fields, never overwrites or removes | repo | CONFIRMED | `CastMember+Merging.swift:130-192` |
| A-05 | A-API | `extraKeys: [String: AnyCodable]` round-trips unknown keys | repo | CONFIRMED | `CastMember.swift:146`, `:349`, `:413` |
| A-06 | A-API | `CastMarkdownParser.parse(fileURL:)` returns `CastDocument` | repo | CONFIRMED | `CastMarkdownParser.swift:166` (instance method) |
| A-07 | A-API | `CastMarkdownGenerator.write(document:to:)` exists | repo | STALE (wording) | `CastMarkdownGenerator.swift:158` — type, name and labels match; it is an instance method, not static |
| A-08 | A-DEP | The library target depends on Yams only | repo | CONFIRMED | `Package.swift:42-57` |
| A-09 | A-DATA | `voices: [String: [String]]` | repo | CONFIRMED | `CastMember.swift:132` |
| A-10 | A-API | `Gender` pattern at `Gender.swift:37-58`, strict decoding | repo | CONFIRMED | `Gender.swift:37`, `:51`; `CastMember.swift:311` |
| A-11 | A-API | `relativizingPaths(in:to:)` at `:415-431` touches only `voices`; `appearance` note at `:400-406` | repo | CONFIRMED | `CastMarkdownParser.swift:415`, `:419-431`, `:401-406` (`internal`) |
| A-12 | A-API | `normalizedCastMemberMatchKey` at `:55-61` lowercases | repo | CONFIRMED | `CastMember+Merging.swift:55` (module-internal free function; also collapses whitespace) |
| A-13 | A-API | `CastDocument.translate` maps decoding failures to `CastParseError`; no `invalidRole` yet | repo | CONFIRMED | `CastDocument.swift:238`; `CastParseError.swift:81-126`. A second `translate` is at `ProjectCastImporter.swift:246` |
| A-14 | A-INVARIANT | None of `CastRole`, `role`, `manifest`, `canonicalName`, `CharacterNameError`, `manifestNameMismatch`, `canonicalize` exist yet | repo | CONFIRMED | grep over `Sources/` — comment hits only |
| A-15 | A-CONFIG | `CastSchemaVersion.current == 1`; comment at `:77-78` cites `appearance` | repo | CONFIRMED | `CastSchemaVersion.swift:79`, `:77-78` |
| A-16 | A-FILE | `appearance` tests at the four cited locations; `all-fields-CAST.md` has an `appearance:` block | repo | CONFIRMED | `FixtureIntegrityTests.swift:67-100`, `AcceptanceGateTests.swift:155-181`, `CastMemberCodingTests.swift:210-253`, `YAMLCodingTests.swift:175-308,904-979`, `Fixtures/all-fields-CAST.md:14` |
| A-17 | A-INVARIANT | No fixture under `Tests/` has `role:` or `manifest:` | repo | CONFIRMED | `grep -rnE '^\s*(role\|manifest):' Tests` — no output |
| A-18 | A-FILE | Doc locations cited by RQ-25 (`README.md:68-74`, `AGENTS.md:128-142`, `:167`, `CHANGELOG.md`) | repo | CONFIRMED | `README.md:68`, `AGENTS.md:128`, `:167`; `git ls-files CHANGELOG.md` |
| A-19 | A-BEHAVIOR | CLI has exactly `validate` and `import`; `validate` emits no warnings; `import` reads `cast:` from PROJECT.md | repo | CONFIRMED | `RepartoCommand.swift:87`; `ImportCommand.swift:30-39`. Behavior rests on doc comments, not a read of the command bodies |
| A-20 | A-FILE | "There is no D5 here (decisions start at D-14)"; body format is RQ-8 | repo | REFUTED (wording) | `docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md:816` — D-5 exists and is the schema-version decision. RQ-8 at that directory's `REQUIREMENTS.md:200` does define the body |
| A-21 | A-CONFIG | `Package.resolved` tracked on this branch; leaf check requires exactly two pins | repo | CONFIRMED | `git ls-files Package.resolved`; `scripts/check-leaf-invariant.sh:95-96` |
| A-22 | A-INVARIANT | RQ-23: "No existing fixture or live `CAST.md` contains `role:` or `manifest:` today" | external | **REFUTED** | `~/Projects/podcasts/granville/CAST.md:10-11`, `:126-127` (hub-derived from X-06) |
| A-23 | A-BEHAVIOR | RP-P6 / Acceptance 2: a 0.1.0-written member with `role` / `manifest` round-trips with no change to the file | external | **REFUTED** | same lines; see blocking finding |
| A-24 | A-INVARIANT | A second library product lets Reparto link SwiftCompartido while "the core stays Yams-only" | repo | **REFUTED** | `AGENTS.md` § Hard constraints (RQ-INV-1); `scripts/check-leaf-invariant.sh:73-77`, `:95-98` (hub-derived from A-21, C-01) |
| A-25 | A-DATA | RP-P2 / Acceptance 1: RQ-21 is amended to check `<character>.dossier/manifest.json` | external | **STALE** | Personaje `DEPENDENCY-MISSIONS.md:136` records OQ-3 as "Drop the path-shape check from Reparto" (hub-derived from X-01, X-07) |
| A-26 | A-DEP | SwiftDossier's `DossierCore` links Reparto | external | UNVERIFIABLE | no SwiftDossier checkout under `~/Projects`; Personaje's working-copy `DEPENDENCY-MISSIONS.md` says "Not created yet" |
| E-01 | A-CONFIG | SwiftEchada pins Reparto `upToNextMajor(from: "0.1.0")` | dep:SwiftEchada | CONFIRMED | `Package.swift:28-29`, no `sibling()` |
| E-02 | A-CONFIG | Echada resolves Reparto 0.1.0 | dep:SwiftEchada | CONFIRMED | `Package.resolved` is gitignored; working copy pins 0.1.0 (`a075db2`) |
| E-03 | A-INVARIANT | 29 files import SwiftReparto | dep:SwiftEchada | CONFIRMED | `git grep -l "import SwiftReparto" HEAD` — 10 in `Sources`, 19 in `Tests` |
| E-04 | A-API | `echada generate cast` exists | dep:SwiftEchada | CONFIRMED | `Sources/EchadaCLICore/GenerateCastCommand.swift:38-41` |
| E-05 | A-INVARIANT | Echada does not read or write `role` / `manifest` extras | dep:SwiftEchada | CONFIRMED | `git grep` over `Sources` — no output |
| E-06 | A-API | `echada verify cast` exists | dep:SwiftEchada | CONFIRMED | `Sources/EchadaCLICore/VerifyCastCommand.swift` |
| C-01 | A-DEP | Linking SwiftCompartido brings SwiftData, SwiftUI, swift-markdown, ZIPFoundation, TextBundle, glosa-av | dep:SwiftCompartido | CONFIRMED | `Package.swift` dependencies and library target; `GuionDocument.swift:9`. SwiftData and SwiftUI arrive by import (system frameworks). `glosa-av` and test-only `SwiftFijos` are `intrusive-memory` packages declared through `sibling()` |
| C-02 | A-BEHAVIOR | Compartido parses screenplays into SwiftData | dep:SwiftCompartido | CONFIRMED | `SwiftDataModels/GuionDocumentModel.swift:109`, `GuionElementModel.swift:98`; `Serialization/GuionDocumentParserSwiftData.swift:28` `parse(script:in:)` |
| C-03 | A-API | A public character-collection API exists today | dep:SwiftCompartido | CONFIRMED | `Sendable/GuionParsedScreenplay+Characters.swift:32` and `GuionDocument.swift:363`: `extractCharacters() -> CharacterList` (`[String: CharacterInfo]`, `Sendable/CharacterInfo.swift:77`). One screenplay each; no public API spans a store (`grep FetchDescriptor Sources` — no output) |
| C-04 | A-DEP | Compartido does not depend on Reparto | dep:SwiftCompartido | CONFIRMED | `grep -rniE reparto Package.swift Sources Tests` — no output |
| C-05 | A-DATA | CP-P1 and CP-P2 are defined and not done | external | **REFUTED** | `grep -rlE 'CP-P[12]'` over `apps/Personaje`, `pkg/SwiftCompartido` and `worktrees/` hits only this worktree's own two files. The `SwiftCompartido-personaje` worktree cited in the first run no longer exists |
| C-06 | A-DATA | Reparto's writer reads CP-P2; CP-P1 implies a minor Compartido release | external | **REFUTED** | same search. `Docs/REQUIREMENTS_PERSONAJE.md` (added by `b0bd600`) has no CP-P IDs and no mention of Reparto or CAST.md |
| C-07 | A-CONFIG | Compartido platform floor | dep:SwiftCompartido | CONFIRMED | `Package.swift` `platforms: [.iOS(.v26), .macOS(.v26)]`, same as Reparto (`Package.swift:25-28`) |
| C-08 | A-INVARIANT | Compartido has no cast type of its own that the writer would collide with | dep:SwiftCompartido | CONFIRMED | `Sendable/CastListPage.swift:69` declares a nested `CastListPage.CastMember`, deprecated at `:59` in favour of `SwiftProyecto.CastMember`. Nested, so no name clash; the deprecation message points at a type SwiftProyecto v5 removed |
| X-01 | A-DATA | Personaje tracks OQ-3 and OQ-4 | external | CONFIRMED | `apps/Personaje/DEPENDENCY-MISSIONS.md:136-137` |
| X-02 | A-FILE | Origin commit `74721c3` exists | external | CONFIRMED | Personaje HEAD is 1 commit ahead (`6952e18`), touching `DEPENDENCY-MISSIONS.md` and `RECON_REPORT.md` only |
| X-03 | A-DATA | Personaje REQUIREMENTS §6 Q4 says "Reparto D5" | external | CONFIRMED | `apps/Personaje/docs/REQUIREMENTS.md:224` |
| X-04 | A-DATA | BUNDLE §3, §8 define `<character>.dossier/manifest.json` | external | CONFIRMED | `apps/Personaje/docs/REQUIREMENTS-DOSSIER-BUNDLE.md:137`, `:330` |
| X-05 | A-DATA | Personaje recon findings B-04a, B-04b | external | CONFIRMED | `apps/Personaje/RECON_REPORT.md:132-148` |
| X-06 | A-DATA | Granville's `CAST.md` exists and is tracked | external | CONFIRMED | `podcasts/granville/CAST.md` — `schemaVersion: 1`, 28 members, all UPPERCASE, no legacy keys; **two members carry `role:` and `manifest:`** |
| X-07 | A-DATA | Granville has `characters/` | external | CONFIRMED | children are `ARCHER/` and `SHANE/`, not `*.dossier/` |

### Blocking findings

#### A-22, A-23 — REFUTED: Granville's `CAST.md` already carries `role:` and `manifest:`, and cannot round-trip unchanged under RQ-23

**Claim**: RQ-23: "No existing fixture or live `CAST.md` contains `role:` or
`manifest:` today… Members without them encode byte-identically." RP-P6: "A
member written at 0.1.0 with `role` / `manifest` in `extraKeys` must load into
the declared fields with no change to the file on round-trip." Acceptance 2:
"Granville's `CAST.md` parses and re-writes byte-identically."
**Source**: `REQUIREMENTS.md` § RQ-23, lines 162–165;
`REQUIREMENTS-personaje.md` lines 30 and 83.
**Found**: `~/Projects/podcasts/granville/CAST.md` (tracked, `main`).

- ARCHER (`:5-11`) has the order `character, voicePrompt, voices, manifest,
  role`. That is 0.1.0's emission: declared keys, then extras sorted.
- SHANE (`:124-…`) has `character, role, manifest, voicePrompt, voices`. That
  is hand-written and matches neither 0.1.0 nor RQ-23.

RQ-23's order is `character, role, …, voices, manifest`. Writing either member
at 0.2.0 moves `role` up, so the file's bytes change.
**Impact**: Acceptance 2 fails as written. RP-P6 is not achievable for any
fixed declared position: 0.1.0 writes extras sorted *after* every declared
key, so a member that also has an extra sorting before `manifest` (`bio`,
`appearance`) changes order whichever slot the new fields take.
**Options**:
1. Keep RQ-23's order. Restate RP-P6 and Acceptance 2 as: decodes into the
   typed fields with no data change, and the *second* write is byte-identical.
   Granville's `CAST.md` takes one normalizing write as part of its migration.
   This matches the existing "first write is a normalizing write" rule in
   `AGENTS.md`. *(recommended)*
2. Change RQ-23 to `…, voices, manifest, role`. ARCHER then round-trips
   unchanged; SHANE and any member with `bio` + `role` still do not.
3. Drop Acceptance 2.

#### A-25 — STALE: RP-P2 amends a check that Personaje has since decided to drop

**Claim**: RP-P2: "Amend RQ-21. The string check compares the manifest path
against `<character>.dossier/manifest.json`." Acceptance 1 tests that check.
**Source**: `REQUIREMENTS-personaje.md` lines 26, 81–82, 103–106.
**Found**: `apps/Personaje/DEPENDENCY-MISSIONS.md:136` gives OQ-3's status as
"Drop the path-shape check from Reparto; `dossier validate --cast` already
covers it." That file changed in `6952e18`, one commit after the `74721c3` this
requirements file was derived from. The requirements file itself lists the
same question under "Open" with the same recommendation.
Separately, Granville's manifests are at `characters/ARCHER/manifest.json` and
`characters/SHANE/manifest.json` (`CAST.md:10`, `:127`; X-07). With RP-P2 as
written, `reparto validate` exits 1 on Granville's `CAST.md` until the
directories are renamed.
**Impact**: RP-P2, Acceptance 1, and RQ-21's `manifestNameMismatch` and
exit-1 behavior are either three sorties' worth of work or none.
**Options**:
1. Drop RQ-21 entirely: no `manifestNameMismatch`, `manifest` is an opaque
   path, RP-P2 and Acceptance 1 are removed. *(recommended — it is what OQ-3
   records and what this file recommends)*
2. Keep RQ-21 as amended (`.dossier`), and accept that Granville fails
   `validate` until migrated.
3. Keep the check but report mismatches as warnings, exit 0.

#### A-24 — REFUTED: a second library product does not keep the leaf invariant (Part 2 only)

**Claim**: "Recommended: a second library product that depends on
`SwiftReparto` and SwiftCompartido, linked only by the `reparto` CLI and
Personaje." Personaje OQ-4 records it as: "The core stays Yams-only."
**Source**: `REQUIREMENTS-personaje.md` lines 50–57;
`apps/Personaje/DEPENDENCY-MISSIONS.md:137`.
**Found**: `AGENTS.md` § Hard constraints: "SwiftReparto declares no
dependency on any `intrusive-memory` package, and never will… SwiftPM detects
package-level dependency cycles at manifest load… there is no target-level
escape from one." `scripts/check-leaf-invariant.sh:73-77` fails if
`Package.swift` names `intrusive-memory`; `:95-98` fails unless
`Package.resolved` holds exactly two pins. SwiftCompartido is an
`intrusive-memory` package and declares `intrusive-memory/glosa-av`
(`Package.swift:55-67`).
**Impact**: Any product in *this* package that links SwiftCompartido puts it
in this manifest. Every consumer of Reparto then resolves SwiftCompartido and
its graph, a required CI check fails, and Reparto can never be a dependency of
SwiftCompartido or glosa-av. There is no cycle today (C-04).
Part 2 is also not startable on its own terms: CP-P1 and CP-P2 are unbuilt
(C-05), and today's `extractCharacters()` covers one screenplay (C-03).
**Options**:
1. Put the discovery writer in a separate package (or in Personaje / a new
   `reparto`-adjacent CLI package) that depends on both SwiftReparto and
   SwiftCompartido. Reparto gains only a library entry point that takes
   plain `[CastMember]` — which `merging(_:)` already is. RQ-INV-1 stands.
   *(recommended)*
2. Amend RQ-INV-1 to permit SwiftCompartido, rewrite the leaf check, and
   accept the graph in every consumer.
3. Have SwiftCompartido export the character collection as a file (JSON) that
   Reparto reads without linking it.

Whichever is chosen, Part 2 stays out of this mission until SwiftCompartido
ships CP-P2.

#### C-05, C-06 — REFUTED: CP-P1 and CP-P2 are not defined anywhere on disk (Part 2 only)

**Claim**: RP-P9 reads "SwiftCompartido's character collection (Compartido
CP-P2)". Depends on: "SwiftCompartido CP-P1, CP-P2 (hard)."
**Source**: `REQUIREMENTS-personaje.md` lines 43 and 88.
**Found**: the first run cited
`worktrees/SwiftCompartido-personaje/REQUIREMENTS-personaje.md`. That worktree
has been removed. SwiftCompartido `b0bd600` adds
`Docs/REQUIREMENTS_PERSONAJE.md` (`type: reference`), which describes
`CharacterVoiceMapping`, per-document extraction and SwiftProyecto
integration. It has no CP-P IDs, no cross-episode collection, and does not
mention Reparto or CAST.md. Personaje's `DEPENDENCY-MISSIONS.md:68` still
plans "cross-episode character collection" for SwiftCompartido, with no ID.
**Impact**: Part 2's input contract has no written definition. RP-P9 and
RP-P11 cannot be given exit criteria.
**Options**:
1. Leave Part 2 out of this mission and remove RP-P9..RP-P14 from this file
   until SwiftCompartido's requirements define the collection. *(recommended;
   it is the same outcome as A-24)*
2. Restore or rewrite SwiftCompartido's CP-P1 / CP-P2 first, then re-run recon.

#### A-07, A-20 — wording only

These block by rule but change no work:

- **A-07**: `CastMarkdownGenerator.write(document:to:)` and
  `CastMarkdownParser.parse(fileURL:)` are instance methods. Callers write
  `CastMarkdownGenerator().write(…)`.
- **A-20**: "There is no D5 here" is wrong. D-5 exists in the 0.1.0 execution
  plan and is the schema-version decision, not the body format. The conclusion
  stands: the body format is RQ-8, and Personaje's reference is what needs
  correcting.

## Local Dependency Map

Declared dependencies of this package:

| Dependency | Declared | Resolved | Local checkout | Local HEAD | Status |
|------------|----------|----------|----------------|-----------|--------|
| jpsim/Yams | `upToNextMajor(from: "6.2.2")` | `6.2.2` (`a27b21e0c81c`) | — | — | NO_LOCAL_CHECKOUT |
| apple/swift-argument-parser | `upToNextMajor(from: "1.7.1")` | `1.8.2` (`6a52f3251125`) | — | — | NO_LOCAL_CHECKOUT |

No `.build/checkouts` exists in this worktree, so there is no resolved copy to
read either. No assumption rests on either dependency's source.

Related repositories the requirements make claims about (not dependencies of
this package):

| Repository | Verified at | Path | Notes |
|------------|-------------|------|-------|
| intrusive-memory/SwiftEchada | `aa36e5259a14` (`development`, `v1.0.0`) | `~/Projects/package-collection/pkg/SwiftEchada` | Working tree dirty; verified against committed content. Two worktrees also exist (`SwiftEchada-personaje`, `SwiftEchada-cast-md`) and were not used |
| intrusive-memory/SwiftCompartido | `b0bd6000fd50` (`development`, 1 commit past `v7.2.5`) | `~/Projects/package-collection/pkg/SwiftCompartido` | Clean. The one new commit adds `Docs/REQUIREMENTS_PERSONAJE.md` only |
| intrusive-memory/Personaje | `6952e18204e1` (`development`) | `~/Projects/apps/Personaje` | Working tree dirty; 1 commit past the `74721c3` named in the requirements' `origin:` |
| intrusive-memory/podcast-granville | `6beafbd304df` (`main`) | `~/Projects/podcasts/granville` | Working tree dirty; `CAST.md` itself is clean. A second checkout, `~/Projects/worktrees/podcast-granville-personaje` (`0886609890b3`, `requirements/personaje`), has the same four `role:` / `manifest:` lines and the same `characters/ARCHER`, `characters/SHANE` |

### Drift and ambiguity notes

- **This worktree is behind `development`.** `requirements/personaje` branches
  from `fb87bfb`. `development` is now at `c3acb7e`, which untracks
  `Package.resolved` and adds a `make resolve` step to CI. A mission branch cut
  from here still tracks `Package.resolved` (A-21) and will conflict on
  `.gitignore` and `tests.yml` when it lands.
- **swift-argument-parser resolved to 1.8.2**, above the declared floor of
  1.7.1. Not a finding against any assumption.
- **`REQUIREMENTS-personaje.md` is untracked** in this worktree.
- **The main SwiftReparto checkout** (`~/Projects/package-collection/pkg/SwiftReparto`,
  `development`, `c3acb7e`) holds no requirements file and no recon report.
  This worktree is the only place either exists.
- **Personaje's `DEPENDENCY-MISSIONS.md` has uncommitted edits.** They touch
  dossier-format, OQ-5, OQ-13 and OQ-17..19. OQ-3 and OQ-4 read the same in
  the working copy as at `6952e18`.

## Unverifiable

| ID | Claim | Why | What would settle it |
|----|-------|-----|----------------------|
| A-26 | SwiftDossier's `DossierCore` links Reparto | No SwiftDossier checkout under `~/Projects` | The repository, or its `Package.swift` |

Byte-level round-trip claims (Acceptance 2, RQ-11) were assessed by reading key
order, not by running the library. Recon runs no builds.

## Handoff to breakdown

- `CONFIRMED` facts are safe as sortie entry criteria without re-checking.
- `UNVERIFIABLE` items become an `## Open Questions` entry or an explicit verification
  step in the first dependent sortie's entry criteria — never a silent assumption.
- The dependency map's local paths carry into EXECUTION_PLAN.md so sortie agents
  don't rediscover them.
- Breakdown has not run. It needs decisions on A-22/A-23, A-25 and A-24 first
  (C-05/C-06 fall away if Part 2 leaves this mission), or a re-run of recon
  with `--accept-risk`.
