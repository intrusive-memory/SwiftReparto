---
type: requirements
state: draft
updated: 2026-10-22
origin: intrusive-memory/Personaje @ 74721c3 (docs/REQUIREMENTS*.md, RECON_REPORT.md)
sequence: 0 (spec lock), 1 (release 0.2.0)
---

# SwiftReparto — what Personaje needs

Reparto is the root of this effort's dependency graph: SwiftDossier's
`DossierCore` and SwiftEchada both link it. The work here is the drafted 0.2.0
(RQ-19 to RQ-25, with RQ-21 and RQ-23 withdrawn), which depends on nothing.
The discovery writer that was Part 2 lives in SwiftPersonaje (decided
2026-10-21, placed 2026-10-22). Who may write CAST.md is settled in
[Who writes CAST.md](#who-writes-castmd).

## Step 0: done

RQ-19..RQ-25 were untracked in the main checkout (Personaje RECON B-04a). The
draft `REQUIREMENTS.md` is now committed on this branch (`62721a7`; `4690c30` before the rebase onto `development`).

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| RP-P1 | *Done (`62721a7`).* Commit the drafted `REQUIREMENTS.md` (RQ-19..RQ-25, D-14). | RECON B-04a |
| RP-P2 | *Changed 2026-10-19:* **Withdraw RQ-21** (done in `REQUIREMENTS.md`). `manifest` stays an opaque path; the dossier validator checks the name (dossier-format D1). | OQ-3 |
| RP-P3 | RQ-19: `role: CastRole?` as a declared field on `CastMember`. | REQUIREMENTS §6 Q1 |
| RP-P4 | RQ-20: `manifest: String?` as a declared field. | REQUIREMENTS §6 Q1 |
| RP-P5 | RQ-22: `CastMember.canonicalName(_:)` and the canonical match key. Names are the screenplay's, UPPERCASE, NFC. | REQUIREMENTS §1.1 |
| RP-P6 | RQ-24: merge rules for the new fields (RQ-23 withdrawn 2026-10-21). A member written at 0.1.0 with `role` / `manifest` in `extraKeys` must load into the declared fields with no data change; key order may change on the first write. | REQUIREMENTS §1 table |
| RP-P7 | RQ-25: `appearance` deprecated, never declared. | REQUIREMENTS §6 Q3 |
| RP-P8 | Release 0.2.0. SwiftEchada pins `upToNextMajor(from: "0.1.0")`, so it resolves without a manifest change. | Reparto §4 |

## Part 2: the discovery writer lives in SwiftPersonaje (decided 2026-10-21)

Cast discovery is SwiftCompartido's: `DocumentModelActor.extractAllCharacters()`
(CP-P2, shipped in 7.3.0) returns every speaking character across a store.
Something has to turn that into CAST.md, and it **can't be in this package**.
Reading Compartido means linking it. SwiftPM resolves dependencies per
package, so even a separate product here would put SwiftCompartido (and
SwiftData, SwiftUI, swift-markdown, ZIPFoundation, TextBundle, glosa-av) in
every CAST.md reader's graph. That breaks RQ-INV-1 and fails
`check-leaf-invariant.sh` (recon A-24).

**Decision (Personaje OQ-4):** the discovery writer lives in Personaje's
stack, which links both packages. *Placed 2026-10-22:* in the
**SwiftPersonaje** library, behind the `personaje` CLI. SwiftPersonaje
replaced Personaje REQUIREMENTS §5 as the home of the CLI, already plans
to link SwiftCompartido for `evidence` (its §7), and is the library the
Personaje app links; the app's review screen (APP-UI §11.1) calls it. The writer calls `extractAllCharacters()`, maps each
character to a `CastMember` through `canonicalName`, merges with
`[CastMember].merging(_:)`, and writes with `CastMarkdownParser.write`. This
package's part is only to make sure that public surface is enough. This
replaces SwiftEchada's `generate cast`.

RP-P9..RP-P14 move out of this package, with the wording below. They are
kept here for traceability. *Done 2026-10-22:* SwiftPersonaje
`REQUIREMENTS.md` §7.1 carries them. (They were first put in Personaje
`docs/REQUIREMENTS.md` §5.1, a section SwiftPersonaje had already replaced;
that copy is now a pointer.)

| ID | Requirement (owner: SwiftPersonaje) |
|----|--------------------------------|
| RP-P9 | Read SwiftCompartido's character collection (CP-P2) and turn each character into a `CastMember`, with the name passed through `canonicalName` (RQ-22). CP-P2 names arrive already uppercased and cut at the first `(` (Compartido `cleanCharacterName`); `canonicalName` is idempotent on them. |
| RP-P10 | Merge the discovered members into the current CAST.md with `[CastMember].merging(_:)`: add new members, fill only nil fields, never overwrite or remove what a person wrote. Duplicates are members with the same canonical name. |
| RP-P11 | Works on a store holding one screenplay (a series built by repeated merges) or every episode at once; both give the same CAST.md. CP-P2's `characters` is a dictionary, so the writer sorts discovered members deterministically before merging. |
| RP-P12 | Available from the `personaje` CLI and from the Personaje app (APP-UI §11.1), both through the SwiftPersonaje library. There is no `reparto` command for it. |
| RP-P13 | Counts (lines, scenes) are **not** written to CAST.md. Personaje reads them from SwiftCompartido for tier suggestions. |
| RP-P14 | Two different names for one person are not merged. That's a review step in Personaje. |

What this package owes the writer, all of it in Part 1 already:

| ID | Requirement |
|----|-------------|
| RP-P15 | `canonicalName(_:)` (RQ-22), `[CastMember].merging(_:)` and `CastMarkdownParser.write` are public and reachable from a plain `import SwiftReparto`. No new API is added for discovery. |

## Who writes CAST.md

*Decided 2026-10-22.* Two layers, and they must not be confused.

**Bytes: SwiftReparto only (RQ-INV-2).** Every write is `parse` → mutate
the `CastDocument` → `CastMarkdownParser.write`. Nobody splices YAML or
edits lines. That rule is unchanged.

**Fields: each caller owns what it sets.** Several packages call that
path. Each changes only the members and fields below, and never removes a
member or overwrites a field it doesn't own:

| Caller | Members | Fields it sets | Through |
|--------|---------|----------------|---------|
| `reparto import` | creates the roster | everything in PROJECT.md `cast:` | `ProjectCastImporter` |
| `reparto canonicalize --apply` (RQ-22) | renames | `character` | Reparto |
| SwiftPersonaje discovery writer (RP-P9..P14) | adds | `character` only; gap-fills via `merging(_:)` | Reparto |
| SwiftPersonaje `cast-import` | creates the roster | as `reparto import` | `ProjectCastImporter` |
| SwiftDossier `create` / `migrate` (SD-12) | adds if absent | `role`, `manifest` | Reparto |
| SwiftPersonaje `voice` | — | `voicePrompt`; `voices.voxalta` on `--adopt` | Reparto |
| SwiftEchada (EC-25) | — | `voices.voxalta` | Reparto |
| Produciesta | — | voice assignments (`voices.*`) | Reparto |
| A person | any | any | an editor; the next library write normalizes it |

Nobody writes the body yet (Personaje Q4: only after Reparto defines it).

What every caller may rely on, and what it may not:

- **The first write normalizes the whole file** (AGENTS.md "First write is
  a normalizing write"; RQ-23 withdrawn). On a hand-edited or 0.1.0-written
  file, members the call didn't touch can change key order and quoting.
  Data never changes. For a live project, run `reparto canonicalize
  --apply` once to take that write deliberately, then commit it alone.
- **After that, a write touches only what changed** (RP-P16 below).
- **Writes are not coordinated across processes.** Two callers that
  `parse` the same file and both `write` lose the first one's change.
  Callers run one at a time; SwiftPersonaje runs `echada` as a subprocess
  and waits for it. A lock is not in scope for 0.2.0.

| ID | Requirement |
|----|-------------|
| RP-P16 | **Writes are local on a normalized file.** On a document this library already wrote, changing, adding or removing one member and writing changes only that member's lines (and nothing in the front matter outside `cast`, or in the body). Today's emission makes this true (`YAMLCoding.swift`: `width = -1`, `sortKeys = false`, per-member key order fixed in `encode(to:)`), but nothing tests it, and SwiftDossier SD-12 depends on it. 0.2.0 adds the test. |

## Facts already verified at v0.1.0 (Personaje recon)

- `CastMember.extraKeys: [String: AnyCodable]` round-trips unknown keys
  (`CastMember.swift:146,190,203,364`).
- `CastMarkdownParser().parse(fileURL:)` → `CastDocument`;
  `CastMarkdownGenerator().write(document:to:)`. Both are instance methods.
  The library depends on Yams only.
- `voices: [String: [String]]` — `voices.voxalta` is an array of paths.

## One reference to settle

Personaje REQUIREMENTS §6 Q4 says the CAST.md body format is "Reparto D5".
That's the wrong reference. D-5 here is the schema-version decision
(`docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md:816`); the body
format is RQ-8 in `docs/complete/operation-troupe-marshal/REQUIREMENTS.md`.
Personaje's doc is what needs correcting (RECON B-04b). Nothing to change in Reparto unless a new decision
on the body format is wanted, in which case it gets a D-15+ ID here.

## Acceptance

Reparto's own §5 acceptance criteria, plus:

1. `manifest` round-trips any path unchanged; Reparto reports no path-shape
   finding (RQ-21 withdrawn).
2. Granville's `CAST.md` parses and re-writes with no data change; the
   second write is byte-identical to the first.
3. RP-P16: on a normalized multi-member fixture, setting `role` on one
   member, adding one member, and removing one member each produce a
   line diff confined to that member.

## Depends on

- Part 1 (0.2.0): nothing.
- Part 2: nothing in this package. SwiftPersonaje's writer depends on SwiftCompartido
  ≥ 7.3.0 (CP-P2) and on Reparto 0.2.0.

## Blocks

- **SwiftEchada's next release** (hard): its rollout step 1 is Reparto 0.2.0.
- **SwiftDossier** (soft): `DossierCore` can start on 0.1.0 with `extraKeys`,
  but then re-implements name canonicalization and has to be reworked.
  Shipping 0.2.0 first avoids that.
- **Personaje** (soft): writes `role` / `manifest` through `CastDocument`;
  falls back to `extraKeys` until 0.2.0.
- **podcast-granville** migration: `reparto canonicalize` runs first.
- **SwiftPersonaje's discovery writer** (hard): it needs `canonicalName` from 0.2.0.

## Open

- *Decided 2026-10-19:* RQ-21 is dropped (OQ-3, dossier-format D1).
- *Decided 2026-10-21:* RQ-23 is dropped; key order may change on first write.
- *Decided 2026-10-21:* the discovery writer lives in Personaje's stack (OQ-4);
  *placed 2026-10-22* in SwiftPersonaje.
- *Decided 2026-10-22:* who writes CAST.md (bytes: Reparto; fields: per
  caller), and RP-P16.
