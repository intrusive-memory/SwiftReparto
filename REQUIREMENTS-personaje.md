---
type: requirements
state: draft
updated: 2026-10-19
origin: intrusive-memory/Personaje @ 74721c3 (docs/REQUIREMENTS*.md, RECON_REPORT.md)
sequence: 0 (spec lock), 1 (release 0.2.0)
---

# SwiftReparto — what Personaje needs

Reparto is the root of this effort's dependency graph: SwiftDossier's
`DossierCore` and SwiftEchada both link it. The work here is the drafted 0.2.0
(RQ-19 to RQ-25, with RQ-21 and RQ-23 withdrawn), which depends on nothing.
The discovery writer that was Part 2 lives in Personaje (decided 2026-10-21).

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

## Part 2: the discovery writer lives in Personaje (decided 2026-10-21)

Cast discovery is SwiftCompartido's: `DocumentModelActor.extractAllCharacters()`
(CP-P2, shipped in 7.3.0) returns every speaking character across a store.
Something has to turn that into CAST.md, and it **can't be in this package**.
Reading Compartido means linking it. SwiftPM resolves dependencies per
package, so even a separate product here would put SwiftCompartido (and
SwiftData, SwiftUI, swift-markdown, ZIPFoundation, TextBundle, glosa-av) in
every CAST.md reader's graph. That breaks RQ-INV-1 and fails
`check-leaf-invariant.sh` (recon A-24).

**Decision (Personaje OQ-4):** the discovery writer lives in **Personaje**.
Personaje has no code yet, and its app will link both packages. The writer calls `extractAllCharacters()`, maps each
character to a `CastMember` through `canonicalName`, merges with
`[CastMember].merging(_:)`, and writes with `CastMarkdownParser.write`. This
package's part is only to make sure that public surface is enough. This
replaces SwiftEchada's `generate cast`.

RP-P9..RP-P14 move to Personaje's requirements, with the wording below. They
are kept here for traceability. *Done 2026-10-22:* Personaje's
`docs/REQUIREMENTS.md` §5.1 carries them (Personaje `b88ceec`).

| ID | Requirement (owner: Personaje) |
|----|--------------------------------|
| RP-P9 | Read SwiftCompartido's character collection (CP-P2) and turn each character into a `CastMember`, with the name passed through `canonicalName` (RQ-22). CP-P2 names arrive already uppercased and cut at the first `(` (Compartido `cleanCharacterName`); `canonicalName` is idempotent on them. |
| RP-P10 | Merge the discovered members into the current CAST.md with `[CastMember].merging(_:)`: add new members, fill only nil fields, never overwrite or remove what a person wrote. Duplicates are members with the same canonical name. |
| RP-P11 | Works on a store holding one screenplay (a series built by repeated merges) or every episode at once; both give the same CAST.md. CP-P2's `characters` is a dictionary, so the writer sorts discovered members deterministically before merging. |
| RP-P12 | Available from the Personaje app and its CLI. There is no `reparto` command for it. |
| RP-P13 | Counts (lines, scenes) are **not** written to CAST.md. Personaje reads them from SwiftCompartido for tier suggestions. |
| RP-P14 | Two different names for one person are not merged. That's a review step in Personaje. |

What this package owes the writer, all of it in Part 1 already:

| ID | Requirement |
|----|-------------|
| RP-P15 | `canonicalName(_:)` (RQ-22), `[CastMember].merging(_:)` and `CastMarkdownParser.write` are public and reachable from a plain `import SwiftReparto`. No new API is added for discovery. |

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

## Depends on

- Part 1 (0.2.0): nothing.
- Part 2: nothing in this package. Personaje's writer depends on SwiftCompartido
  ≥ 7.3.0 (CP-P2) and on Reparto 0.2.0.

## Blocks

- **SwiftEchada's next release** (hard): its rollout step 1 is Reparto 0.2.0.
- **SwiftDossier** (soft): `DossierCore` can start on 0.1.0 with `extraKeys`,
  but then re-implements name canonicalization and has to be reworked.
  Shipping 0.2.0 first avoids that.
- **Personaje** (soft): writes `role` / `manifest` through `CastDocument`;
  falls back to `extraKeys` until 0.2.0.
- **podcast-granville** migration: `reparto canonicalize` runs first.
- **Personaje's discovery writer** (hard): it needs `canonicalName` from 0.2.0.

## Open

- *Decided 2026-10-19:* RQ-21 is dropped (OQ-3, dossier-format D1).
- *Decided 2026-10-21:* RQ-23 is dropped; key order may change on first write.
- *Decided 2026-10-21:* the discovery writer lives in Personaje (OQ-4).
