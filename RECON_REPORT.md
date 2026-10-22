---
type: recon-report
state: current
requirements_file: REQUIREMENTS-personaje.md
requirements_sha256: fe131880d307bfacf0278eb81813fa6d1e098b179376f74a406b773ee7f560f6
incorporated_requirements_sha256: d24ada457417c370bba4112cea5edd18e1c32fffc7ee685383eaa6bf81dc9c30
project_head: b7969336af6bd180da55061c532b7e4f233f0ac2
search_root: ~/Projects
generated: 2026-10-21
verdict: CLEAR
---

# RECON_REPORT.md — SwiftReparto (Personaje requirements)

## Terminology

> **Mission** — A definable, testable scope of work.
> **Sortie** — An atomic, testable unit of work executed by a single agent in one dispatch.
> **Work Unit** — A grouping of sorties.

## Verdict

**CLEAR** — every blocking finding from the morning run is resolved by a
requirements edit. Nothing is REFUTED, STALE or CONFIRMED_LOCAL_ONLY against
the current text. One UNVERIFIABLE (A-26) and one AMBIGUOUS revision
(Granville's `CAST.md`) carry into breakdown as Open Questions.

Fourth run, 2026-10-21. It audits the requirements after two rounds of edits
the same day:

1. RQ-23 was withdrawn. RP-P6 and Personaje Acceptance 2 were restated.
   REQUIREMENTS.md §5 criterion 4 was withdrawn along with RQ-21.
2. Part 2 (the discovery writer) moved to Personaje, per OQ-4. E-06, A-07
   and A-20 were reworded.

The SwiftCompartido locus is `main` at `bb4973d` (v7.4.0).

| Finding | Morning run | Now | Resolution |
|---------|-------------|-----|------------|
| A-22, A-23 | REFUTED | Retired | RQ-23 withdrawn |
| A-25 | STALE | CONFIRMED | RQ-21 withdrawn per OQ-3 / dossier-format D1 |
| C-05, C-06 | REFUTED | CONFIRMED | Compartido 7.3.0 ships CP-P1/CP-P2 |
| A-24 | REFUTED | Retired | The text no longer proposes a product in this package. The writer is Personaje's; RP-P15 claims only existing/Part 1 public API |
| E-06 | REFUTED | Retired | §4 no longer cites `verify cast`. It now states that the command was removed in Echada 2.0.0 (CONFIRMED: CHANGELOG 2.0.0; `git grep commandName` at `2d67d79`) |
| A-07 | STALE (wording) | CONFIRMED | The text now says instance methods (`CastMarkdownGenerator.swift:158`) |
| A-20 | REFUTED (wording) | CONFIRMED | The text now cites D-5 at `EXECUTION_PLAN.md:816` as the schema-version decision |

## Assumption Findings

Locus `repo` is this worktree. HEAD is `f433108`. The only change since the
`4690c30` the repo locus was verified at is in `RECON_REPORT.md`,
`REQUIREMENTS-personaje.md` and `REQUIREMENTS.md` (`git diff --stat 4690c30
HEAD`). No file under `Sources/`, `Tests/` or `scripts/`, and no manifest,
changed. Repo-locus verdicts A-01..A-21 are therefore carried forward with
their original evidence. *After the 2026-10-22 rebase* (`f433108` → `b796933`) the base also
carries `c3acb7e`, which touches only `.gitignore`, `tests.yml` and
`Package.resolved` (untracked); nothing under `Sources/`, `Tests/` or
`scripts/`. A-21 holds in substance (two pins, enforced) but the file is no
longer tracked.

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| A-01..A-06, A-08..A-19, A-21 | — | SwiftReparto source facts (merge, extraKeys, Gender pattern, relativizingPaths, match key, translate, schema version, fixtures, CLI) | repo | CONFIRMED (carried) | 2026-10-03 run, same source tree |
| A-07 | A-API | `CastMarkdownGenerator().write(document:to:)`, instance method | repo | CONFIRMED | `CastMarkdownGenerator.swift:158` |
| A-20 | A-FILE | D-5 is the schema-version decision; the body format is RQ-8 | repo | CONFIRMED | `docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md:816`; `docs/complete/operation-troupe-marshal/REQUIREMENTS.md:200` |
| A-24 | A-DEP | *(claim removed 2026-10-21)* A second library product can link SwiftCompartido | repo | Retired | The text now places the writer in Personaje (Part 2). The morning run's REFUTED evidence (`AGENTS.md` RQ-INV-1; `check-leaf-invariant.sh:73-77`, `:95-98`) is why |
| A-25 | A-DATA | RQ-21 withdrawn per dossier-format D1 / Personaje OQ-3 | external | CONFIRMED | `dossier-format/docs/PROPERTY-INVENTORY.md:237` (D1: "Drop it"); `Personaje/DEPENDENCY-MISSIONS.md:186` |
| A-27 | A-DATA | Name / pointer checks are dossier-format `E-NAME-MISMATCH` / `W-POINTER`, §3 and §14 | external | CONFIRMED | `dossier-format/docs/DOSSIER-FORMAT.md:84` (in §3, starts `:77`), `:534`, `:552` (in §14, starts `:526`) |
| A-26 | A-DEP | SwiftDossier's `DossierCore` links Reparto | external | UNVERIFIABLE | Checkout exists (`pkg/SwiftDossier`, `aa760bf`, clean). It has no `Package.swift`. `REQUIREMENTS.md:44` states the dependency as design intent |
| E-01 | A-CONFIG | SwiftEchada pins Reparto `upToNextMajor(from: "0.1.0")` | dep:SwiftEchada | CONFIRMED | `Package.swift:28-29`. Plain remote, no `sibling()` |
| E-03 | A-INVARIANT | 29 files import SwiftReparto | dep:SwiftEchada | CONFIRMED (carried) | 2026-10-03. Not re-counted at `d5f49c3` |
| E-04 | A-API | `echada generate cast` exists (to be replaced) | dep:SwiftEchada | CONFIRMED | `GenerateCastCommand.swift:42-43` at HEAD. It is not removed yet; the working copy is modified |
| E-05 | A-INVARIANT | Echada does not read or write `role` / `manifest` extras | dep:SwiftEchada | CONFIRMED | `git grep -E 'extra: "(role\|manifest)"\|"manifest"\|"role"' HEAD -- Sources`: no output |
| E-06 | A-API | *(claim reworded 2026-10-21)* `echada verify cast` was removed in Echada 2.0.0 | dep:SwiftEchada | CONFIRMED | SwiftEchada `CHANGELOG.md` `[2.0.0]`; `git grep commandName HEAD -- Sources` at `2d67d79` lists no `verify` |
| C-01 | A-DEP | Linking Compartido brings SwiftData, SwiftUI, swift-markdown, ZIPFoundation, TextBundle, glosa-av | dep:SwiftCompartido | CONFIRMED | `main:Package.swift`: library target links TextBundle, ZIPFoundation, Markdown and GlosaCore. SwiftData via `DocumentModelActor.swift:13`; SwiftUI via `GuionDocument.swift:9`. No `sibling()` on main |
| C-02 | A-BEHAVIOR | Compartido parses screenplays into SwiftData | dep:SwiftCompartido | CONFIRMED | `GuionDocumentModel.swift:110`, `GuionElementModel.swift:99`, `:921-983` |
| C-03 | A-API | CP-P2 character collection exists | dep:SwiftCompartido | CONFIRMED | `DocumentModelActor.swift:330` `public func extractAllCharacters() throws -> CharacterCollectionResult` (actor-isolated) |
| C-03b | A-BEHAVIOR | CP-P2 spans every document in the store | dep:SwiftCompartido | CONFIRMED | `DocumentModelActor.swift:~333-346`: an unpredicated `FetchDescriptor<GuionDocumentModel>` |
| C-03d | A-BEHAVIOR | CP-P6 deterministic script order | dep:SwiftCompartido | CONFIRMED | Documents sorted (title, filename, persistentModelID), elements by `sortedElements`. The top-level `characters` is a `Dictionary`, so the order across characters is not defined |
| C-05 | A-DATA | CP-P1 / CP-P2 are defined | dep:SwiftCompartido | CONFIRMED | `main:Docs/REQUIREMENTS_PERSONAJE.md:29-30` |
| C-06 | A-DATA | CP-P1 / CP-P2 are released | dep:SwiftCompartido | CONFIRMED | `CHANGELOG.md` `## [7.3.0] - 2026-10-18`; latest tag on main `v7.4.0` |
| C-09 | A-API | CP-P1 `speaker` on every element | dep:SwiftCompartido | CONFIRMED | `GuionElementModel.swift:373`; `SwiftCompartidoSchemaV3.swift:87`, `:103-106` (lightweight V2→V3) |
| C-04 | A-INVARIANT | Compartido does not depend on Reparto | dep:SwiftCompartido | CONFIRMED | `git grep -i reparto main -- Package.swift Sources Tests`: comments and the deprecation string only |
| C-07 | A-CONFIG | Platforms iOS 26 / macOS 26 | dep:SwiftCompartido | CONFIRMED | `main:Package.swift` |
| C-08 | A-INVARIANT | No top-level `CastMember` in Compartido | dep:SwiftCompartido | CONFIRMED | `CastListPage.swift:68` (nested). The deprecation message now points at SwiftReparto's CAST.md |
| X-01 | A-DATA | Personaje tracks OQ-3 and OQ-4 | external | CONFIRMED | `DEPENDENCY-MISSIONS.md:186-187`. Both rows are still marked "decide" |
| X-03 | A-DATA | Personaje §6 Q4 cites "Reparto D5" | external | CONFIRMED | `Personaje/docs/REQUIREMENTS.md:227` |
| X-06 | A-DATA | Granville `CAST.md` carries `role:` / `manifest:` today (RQ-23-withdrawn rationale, RQ-24 migration) | external | CONFIRMED | `main` (`6beafbd`): ARCHER and SHANE (`:10-11`, `:126-127`). `experiment/gemini-voices` (`515ccdf`, checked out): 4 with `role:`, 9 with `manifest:`, `.dossier` paths |

### New claims introduced by today's edits

| ID | Kind | Claim | Locus | Verdict | Evidence |
|----|------|-------|-------|---------|----------|
| N-01 | A-API | CP-P2 is `DocumentModelActor.extractAllCharacters()`, shipped in 7.3.0 | dep:SwiftCompartido | CONFIRMED | `main:Sources/SwiftCompartido/Actors/DocumentModelActor.swift:330`; `CHANGELOG.md` `[7.3.0] - 2026-10-18` |
| N-02 | A-BEHAVIOR | CP-P2 names arrive uppercased and cut at the first `(` | dep:SwiftCompartido | CONFIRMED | `main:Sources/SwiftCompartido/Sendable/GuionParsedScreenplay+Characters.swift:127-139` (`cleanCharacterName`, ends `.uppercased()`) |
| N-03 | A-DATA | CP-P2's `characters` is a dictionary | dep:SwiftCompartido | CONFIRMED | `main:Sources/SwiftCompartido/Sendable/CharacterCollectionResult.swift:28` (`characters: [String: StoreCharacterInfo]`) |
| N-04 | A-FILE | Personaje has no code yet | external | CONFIRMED | `ls ~/Projects/apps/Personaje`: `DEPENDENCY-MISSIONS.md`, `docs`, `Makefile`, `RECON_REPORT.md`, `tools`. No `Package.swift` or `.xcodeproj` within depth 3 |
| N-05 | A-BEHAVIOR | Nothing in Echada compares `role` / `manifest` as fields | dep:SwiftEchada | CONFIRMED | `CastRosterVerifier.swift` `fieldMismatches` compares a fixed list (`character`, `actor`, `gender`, `language`, `voicePrompt`, …), and only against a legacy `cast:` roster |
| N-06 | A-API | RP-P15: `merging(_:)` and `CastMarkdownParser.write` are public today; `canonicalName` arrives in Part 1 | repo | CONFIRMED | `CastMember+Merging.swift:130` (A-03); `CastMarkdownParser.write` is the RQ-INV-2 writer (`AGENTS.md` § CLI). `canonicalName` is RQ-22 work, not a presupposition |

### Non-blocking notes for breakdown

- **CP-P2 names are already uppercase.** `cleanCharacterName`
  (`GuionParsedScreenplay+Characters.swift:127-139`) ends in
  `.uppercased()`. That contradicts Compartido's own CP-P7. It does no NFC
  normalization, and it cuts at the first `(` rather than stripping only
  trailing extensions. This is harmless to Reparto, because `canonicalName`
  is idempotent on uppercase. However, `GUARD (2)` and `GUARD` collapse
  upstream, before `canonicalName` sees them, so a Part 2 writer can't
  recover the distinction. This is a Compartido issue to raise, not a
  Reparto one.
- **Stores migrated V2→V3 have nil `speaker`.** CP-P2 throws
  `speakerDataMissing(documentTitles:)` for them, and a re-parse is required.
  A Part 2 writer must surface that error, not swallow it.
- **`StoreCharacterInfo` isn't `Equatable`**, and `characters` is a
  dictionary. RP-P11 ("one screenplay at a time and all at once give the same
  CAST.md") then depends on the writer sorting members itself. `merging(_:)`
  appends in `discovered` order.
- **`sceneIds` is empty for Fountain parses** (FDX only). That doesn't matter
  here, because RP-P13 keeps counts and scenes out of CAST.md.
- **Compartido's `Docs/REQUIREMENTS_PERSONAJE.md` is still `state: draft`**,
  even though 7.3.0 shipped it.

## Local Dependency Map

| Dependency | Declared | Resolved | Local checkout | Local HEAD | Status |
|------------|----------|----------|----------------|-----------|--------|
| jpsim/Yams | `upToNextMajor(from: "6.2.2")` | `6.2.2` (`a27b21e0c81c`) | — | — | NO_LOCAL_CHECKOUT |
| apple/swift-argument-parser | `upToNextMajor(from: "1.7.1")` | `1.8.2` (`6a52f3251125`) | — | — | NO_LOCAL_CHECKOUT |

Related repositories (not dependencies of this package):

| Repository | Verified at | Path | Notes |
|------------|-------------|------|-------|
| intrusive-memory/SwiftCompartido | `bb4973d` (`main`, `v7.4.0`) | `~/Projects/package-collection/pkg/SwiftCompartido` | Read via `git show main:`. The working tree is on `development` (`3f3a837`, `7.4.0-dev`, sibling pattern restored); `main` is its ancestor |
| intrusive-memory/SwiftEchada | `d5f49c3` (`development`) | `~/Projects/package-collection/pkg/SwiftEchada` | Dirty (`GenerateCastCommand.swift`, `CastCommand.swift`, …). Verified committed content. `Package.swift` is clean |
| intrusive-memory/Personaje | `7a8a052` (`development`) | `~/Projects/apps/Personaje` | Clean. `REQUIREMENTS-DOSSIER-BUNDLE.md` is now `state: superseded`; its content moved to dossier-format |
| intrusive-memory/podcast-granville | `6beafbd` (`main`); `515ccdf` (`experiment/gemini-voices`, checked out) | `~/Projects/podcasts/granville` | Dirty tree; `CAST.md` itself is clean. **The two branches disagree** — see below |
| intrusive-memory/SwiftDossier | `aa760bf` (`development`) | `~/Projects/package-collection/pkg/SwiftDossier` | Clean. Requirements only, no `Package.swift` |
| dossier-format | `6ad86c2` (`development`) | `~/Projects/dossier-format` | Clean |

### Drift and ambiguity notes

- **Granville's `CAST.md` is AMBIGUOUS.** Acceptance 2 names "Granville's
  `CAST.md`", but `main` and the checked-out `experiment/gemini-voices`
  differ (`git diff --stat main HEAD -- CAST.md`: 18+/9-). `main` has 2
  members with role and manifest, pointing at `characters/<NAME>/manifest.json`.
  The experiment branch has 4 with `role:` and 9 with `manifest:`, pointing at
  `characters/<NAME>.dossier/manifest.json`. Recon did not choose. The
  acceptance fixture should name a revision.
- *Resolved 2026-10-22:* this branch was rebased onto `development`
  (`c3acb7e`); `4690c30` and `f433108` are now `62721a7` and `b796933`, with
  the same content. `c3acb7e` untracks `Package.resolved` and adds `make
  resolve` before the leaf check in CI. A-21's "tracked on this branch" is
  therefore no longer true: `check-leaf-invariant.sh:90-98` still demands
  exactly two pins, but reads them from a file resolved at build time. The
  Resolved column above is from the pre-rebase tracked file.
- *Resolved 2026-10-22:* the requirements edits and this report are
  committed. RP-P9..RP-P14 are in Personaje `docs/REQUIREMENTS.md` §5.1.

## Unverifiable

| ID | Claim | Why | What would settle it |
|----|-------|-----|----------------------|
| A-26 | SwiftDossier's `DossierCore` links Reparto | SwiftDossier has no `Package.swift` yet | Its first manifest |

## Handoff to breakdown

- `CONFIRMED` facts are safe as sortie entry criteria without re-checking.
- Carry into `## Open Questions`:
  - **A-26** (UNVERIFIABLE): SwiftDossier's dependency on Reparto is design
    intent until it has a `Package.swift`. This blocks nothing in this mission.
  - **Granville revision** (AMBIGUOUS): Personaje Acceptance 2 must name
    `main` (`6beafbd`, 2 members with role/manifest, flat `characters/<NAME>/`
    paths) or `experiment/gemini-voices` (`515ccdf`, 4/9, `.dossier` paths).
    Recommended: the experiment branch, since it holds the `.dossier` layout
    the rest of the stack targets. Pin the revision in the fixture.
- *Done 2026-10-22:* `requirements/personaje` rebased onto `development`
  (`c3acb7e`); the requirements edits and this report committed.
- Scope is Part 1 only: RQ-19, RQ-20, RQ-22, RQ-24, RQ-25 and D-14, released
  as 0.2.0. Part 2 has no work in this package.
