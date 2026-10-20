---
type: requirements
state: draft
updated: 2026-10-19
origin: intrusive-memory/Personaje @ 74721c3 (docs/REQUIREMENTS*.md, RECON_REPORT.md)
sequence: 0 (spec lock), 1 (release 0.2.0), 2 (discovery writer, after SwiftCompartido)
---

# SwiftReparto — what Personaje needs

Reparto is the root of this effort's dependency graph: SwiftDossier's
`DossierCore` and SwiftEchada both link it. The work is in two parts: the
already-drafted 0.2.0 (RQ-19 to RQ-25) with one amendment, which depends on
nothing; and a discovery writer, which waits on SwiftCompartido.

## Step 0: done

RQ-19..RQ-25 were untracked in the main checkout (Personaje RECON B-04a). The
draft `REQUIREMENTS.md` is now committed on this branch (`4690c30`).

## Requirements

| ID | Requirement | Source |
|----|-------------|--------|
| RP-P1 | *Done (`4690c30`).* Commit the drafted `REQUIREMENTS.md` (RQ-19..RQ-25, D-14). | RECON B-04a |
| RP-P2 | *Changed 2026-10-19:* **Withdraw RQ-21** (done in `REQUIREMENTS.md`). `manifest` stays an opaque path; the dossier validator checks the name (dossier-format D1). | OQ-3 |
| RP-P3 | RQ-19: `role: CastRole?` as a declared field on `CastMember`. | REQUIREMENTS §6 Q1 |
| RP-P4 | RQ-20: `manifest: String?` as a declared field. | REQUIREMENTS §6 Q1 |
| RP-P5 | RQ-22: `CastMember.canonicalName(_:)` and the canonical match key. Names are the screenplay's, UPPERCASE, NFC. | REQUIREMENTS §1.1 |
| RP-P6 | RQ-23, RQ-24: `CodingKeys` order and merge rules for the new fields. A member written at 0.1.0 with `role` / `manifest` in `extraKeys` must load into the declared fields with no change to the file on round-trip. | REQUIREMENTS §1 table |
| RP-P7 | RQ-25: `appearance` deprecated, never declared. | REQUIREMENTS §6 Q3 |
| RP-P8 | Release 0.2.0. SwiftEchada pins `upToNextMajor(from: "0.1.0")`, so it resolves without a manifest change. | Reparto §4 |

## Part 2: writing a discovered cast (decided 2026-10-03)

Cast discovery is SwiftCompartido's: it parses the screenplays into its
database and reports who speaks. Reparto does no discovery. It reads that
database and writes what it finds to CAST.md. SwiftEchada's `generate cast` is
removed, so this replaces it.

| ID | Requirement |
|----|-------------|
| RP-P9 | Read SwiftCompartido's character collection (Compartido CP-P2) and turn each character into a `CastMember`, with the name passed through `canonicalName` (RQ-22). |
| RP-P10 | Merge the discovered members into the current CAST.md with the existing `[CastMember].merging(_:)` and `backfilled(from:)` rules (`CastMember+Merging.swift:130,161-192`): add new members, fill only nil fields, never overwrite or remove what a person wrote. Duplicates are members with the same canonical name. |
| RP-P11 | Works one screenplay at a time (a series is built by repeated merges) and on a database holding every episode at once. Both give the same CAST.md. |
| RP-P12 | A `reparto` command for it, and a library call an app can use (Personaje is sandboxed and can't run the CLI). |
| RP-P13 | Counts (lines, scenes) are **not** written to CAST.md. Personaje reads them from SwiftCompartido for tier suggestions. |
| RP-P14 | Two different names for one person are not merged. That's a review step in Personaje. |

**Open: which target links SwiftCompartido.** Reading its database means
linking it, and it brings SwiftData, SwiftUI, swift-markdown, ZIPFoundation,
TextBundle and glosa-av. If the core `SwiftReparto` library links it, so does
everything that reads CAST.md (SwiftDossier's read-only core, the Vinetas app,
SwiftEchada), which is what Reparto's README says the package exists to avoid.
Recommended: a second library product that depends on `SwiftReparto` and
SwiftCompartido, linked only by the `reparto` CLI and Personaje. Tracked as
OQ-4 in Personaje's DEPENDENCY-MISSIONS.md.

Part 2 can ship as 0.3.0 so that 0.2.0 doesn't wait on SwiftCompartido.

## Facts already verified at v0.1.0 (Personaje recon)

- `CastMember.extraKeys: [String: AnyCodable]` round-trips unknown keys
  (`CastMember.swift:146,190,203,364`).
- `CastMarkdownParser.parse(fileURL:)` → `CastDocument`;
  `CastMarkdownGenerator.write(document:to:)`. The library depends on Yams only.
- `voices: [String: [String]]` — `voices.voxalta` is an array of paths.

## One reference to settle

Personaje REQUIREMENTS §6 Q4 says the CAST.md body format is "Reparto D5".
There is no D5 here (decisions start at D-14); the body format is RQ-8 in
`docs/complete/operation-troupe-marshal/REQUIREMENTS.md`. Personaje's doc is
what's wrong (RECON B-04b). Nothing to change in Reparto unless a new decision
on the body format is wanted, in which case it gets a D-15+ ID here.

## Acceptance

Reparto's own §5 acceptance criteria, plus:

1. `manifest` round-trips any path unchanged; Reparto reports no path-shape
   finding (RQ-21 withdrawn).
2. Granville's `CAST.md` parses and re-writes byte-identically.

## Depends on

- Part 1 (0.2.0): nothing.
- Part 2: **SwiftCompartido** CP-P1, CP-P2 (hard).

## Blocks

- **SwiftEchada's next release** (hard): its rollout step 1 is Reparto 0.2.0.
- **SwiftDossier** (soft): `DossierCore` can start on 0.1.0 with `extraKeys`,
  but then re-implements name canonicalization and has to be reworked.
  Shipping 0.2.0 first avoids that.
- **Personaje** (soft): writes `role` / `manifest` through `CastDocument`;
  falls back to `extraKeys` until 0.2.0.
- **podcast-granville** migration: `reparto canonicalize` runs first.
- **Personaje** building CAST.md from the scripts (hard, Part 2).

## Open

- *Decided 2026-10-19:* RQ-21 is dropped (OQ-3, dossier-format D1).
