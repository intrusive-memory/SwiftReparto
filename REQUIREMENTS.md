---
type: requirements
state: draft
created: 2026-09-25
updated: 2026-11-07
target_version: 0.2.0
controlling_doc: ../SwiftSemblanzas/REQUIREMENTS.md (§5, "The character record")
---

# SwiftReparto 0.2.0: character record support

The character record (a `.dossier` bundle, defined by
[dossier-format](https://github.com/intrusive-memory/dossier-format)
`docs/DOSSIER-FORMAT.md`) starts at `CAST.md`. Each cast member with a dossier
points to its manifest:

```
characters/<CHARACTER>.dossier/manifest.json
```

This document covers what SwiftReparto, the only reader and writer of
`CAST.md`, has to change to support that.

1. **`role`**: a new first-class field, the member's casting tier (RQ-19).
2. **`manifest`**: a new first-class field, the path to the character's
   manifest, opaque to Reparto (RQ-20). RQ-21 is withdrawn.
3. **Canonical character names**, defined here because this is the leaf
   package every consumer links (RQ-22).
4. **`appearance` is deprecated** and will never be declared (RQ-25).
5. **`lineCount`**: added 2026-11-07 for 0.3.0, the number of lines the
   member speaks across the project's episodes, written only by discovery
   and replaced on every merge (RQ-26).

The completed 0.1.0 spec is `docs/complete/operation-troupe-marshal/REQUIREMENTS.md`.
Everything in it still holds unless a requirement below says it's superseded.
IDs continue from that document: RQ-19+, RQ-INV-4+, RQ-Q4+, D-14+.

**Status: RQ-19 to RQ-25 shipped in 0.2.0 (0.2.1 is the current release).
RQ-26 and D-15 (added 2026-11-07) are specified, not implemented; they target
0.3.0, the next minor.**

---

## 1. Summary of changes

| ID | Change | Kind |
|----|--------|------|
| RQ-19 | `role: CastRole?` | New declared field |
| RQ-20 | `manifest: String?` | New declared field |
| RQ-21 | *Withdrawn 2026-10-19.* Manifest path ↔ name invariant | — |
| RQ-22 | `CastMember.canonicalName(_:)` and the canonical match key | New API, changed matching |
| RQ-23 | *Withdrawn 2026-10-21.* `CodingKeys` order | — |
| RQ-24 | Merge rules for `role` / `manifest` | Merge behavior |
| RQ-25 | `appearance` deprecated | Supersedes RQ-5, closes RQ-Q2 |
| D-14 | No schema version bump | Decision |
| RQ-26 | *Added 2026-11-07, 0.3.0.* `lineCount: Int?`, replaced on merge | New declared field, merge behavior |
| D-15 | *Added 2026-11-07.* No schema version bump for `lineCount` | Decision |
| RQ-27 | *Added 2026-11-07, 0.3.0.* `castVersion: Int?` in the front matter | New declared front-matter field |

---

## 2. Requirements

### RQ-19: `role`

- Add `public var role: CastRole?` to `CastMember`, plus the matching init
  parameter (default `nil`).
- `CastRole` follows the pattern `Gender` already uses (`Gender.swift:37-58`):
  `public enum CastRole: String, Codable, Sendable, Equatable, Hashable, CaseIterable`.
  Raw values are the wire format and **must not change**.

  | Raw value | `displayName` | Basis |
  |-----------|---------------|-------|
  | `lead` | Lead | Principal performer, series regular |
  | `supporting` | Supporting | Principal, series regular / recurring |
  | `guest` | Guest Star | Principal, single-episode featured |
  | `narrator` | Narrator | Voice-over principal |
  | `costar` | Co-Star | Principal, day performer |
  | `underfive` | Under-Five | SAG-AFTRA under-five (≤ 5 lines) |
  | `background` | Background | Background actor |

- Add `public var isMajor: Bool`. It is true for `lead`, `supporting`,
  `guest` and `narrator`, matching the planned Major / Minor split in the
  CAST.md body (RQ-8).
- **Decoding is strict**, the same as `Gender`: an unknown raw value fails
  the parse. `CastDocument.translate` must turn that failure into a new
  `CastParseError.invalidRole(index:value:)` that names the member and the
  bad value, instead of surfacing a raw `DecodingError`.
- The asset requirements for each role are **not** defined here. They
  belong to SwiftSemblanzas (§5.4). Reparto carries only the value.

### RQ-20: `manifest`

- Add `public var manifest: String?` to `CastMember`, plus the matching init
  parameter (default `nil`).
- It is a path to the member's `manifest.json`. **RQ-6 applies**: the path is
  relative to the directory containing `CAST.md`. Absolute paths still
  decode, but they are relativized on write.
- `CastMarkdownParser.relativizingPaths(in:to:)`
  (`CastMarkdownParser.swift:415-431`) must now relativize `manifest` as
  well as `voices`. That replaces the placeholder comment about `appearance`
  at `:400-406`.
- **RQ-7 still holds**: Reparto doesn't resolve, open or check the existence
  of the path.
- Paths contain spaces, for example
  `"characters/THE PRACTITIONER/manifest.json"`. Written values must survive
  a Yams round-trip byte-for-byte. Quote them whenever Yams would otherwise
  misread the string.

### RQ-21: manifest path ↔ name invariant (withdrawn)

**Withdrawn 2026-10-19** (dossier-format decision D1, Personaje OQ-3). Reparto
keeps `manifest` an opaque path and knows nothing about the shape of a
dossier. The check belongs to the dossier validator, which reports it as
`E-NAME-MISMATCH` / `W-POINTER` (dossier-format `docs/DOSSIER-FORMAT.md` §3,
§14). Do not implement `manifestNameMismatch`. The original text is kept
below for the record.


SwiftSemblanzas requires that a manifest's parent directory have exactly the
member's name. Reparto can check this **as a string, without touching the
filesystem**, so RQ-7 stays intact.

- Add `public var manifestNameMismatch: String?` to `CastMember`. It returns
  `nil` in either case:
  - `manifest` is nil, or
  - the last two path components are exactly `<character>/manifest.json`,
    compared after NFC normalization (RQ-22).

  Otherwise it returns a message that names both values.
- **Decoding never fails on a mismatch.** A bad pointer must not stop anyone
  reading the cast.
- `reparto validate` reports mismatches as **errors**, with exit code 1.
  SwiftSemblanzas treats them as load errors, per its §5.2.
- The directory above `<character>/` is free. `characters/` is only a
  convention.

### RQ-22: canonical character names

The rule is that a character is named exactly as its screenplay cue, in
uppercase, everywhere. It lives here because every consumer links Reparto
and nothing else in the stack is a leaf. That includes SwiftEchada, which
does not link SwiftSemblanzas.

- Add `public static func canonicalName(_ raw: String) throws -> String` on
  `CastMember`, or on a small `CharacterName` namespace. It does the
  following, in order:
  1. Strips a trailing parenthetical cue extension, repeatedly:
     `(V.O.)`, `(O.S.)`, `(O.C.)`, `(CONT'D)`, and any other `( … )` at the
     end, and a trailing Fountain `^` dual-dialogue mark, in any order (added
     in 0.2.1 to match dossier-format §2). It also strips a leading Fountain
     `@` force-marker.
  2. Trims and collapses internal whitespace to single spaces.
  3. Uppercases, locale-independent.
  4. Normalizes to Unicode NFC.
  5. Throws `CharacterNameError` when the result is empty, contains `/` or
     `:`, or starts with `.`. **It never substitutes characters.**

  Examples: `NARRATOR (V.O.)` → `NARRATOR`. `@McCLANE` → `MCCLANE`.
  `dr. o'neill` → `DR. O'NEILL`. `GUARD #2` and `JOSÉ` are unchanged.
- **Matching uses the canonical form.** `normalizedCastMemberMatchKey`
  (`CastMember+Merging.swift:55-61`) currently lowercases. It becomes the
  canonical name, falling back to the old key when canonicalization throws.
  As a result, `NARRATOR (V.O.)` in an imported cue list merges into
  `NARRATOR`, where today it would be a duplicate.
- **Existing documents are never rewritten silently.** Decoding keeps
  `character` exactly as written. `reparto validate` warns for every member
  whose `character` isn't already canonical. `reparto import` and any API
  that creates members from screenplay cues **must** canonicalize.
- Making names canonical in an existing file is an explicit step:
  `reparto canonicalize [--apply]`. It is a dry-run by default and refuses
  to run if two members would collide.

### RQ-23: `CodingKeys` order (withdrawn)

**Withdrawn 2026-10-21.** No emission position is required for `role` or
`manifest`. Live documents already carry both keys (Granville's `CAST.md`,
in two different orders), and that is fine: the first 0.2.0 write may move
them, under the existing "first write is a normalizing write" rule in
`AGENTS.md`. The position the implementation picks is pinned by the new
fixtures (§5, criterion 1), and members without either key still encode
byte-identically, so the RQ-11 SHA-256 gate is unaffected.

### RQ-24: merge rules

`backfilled(from:)` (`CastMember+Merging.swift:161-192`) gets two new
scalar rules, the same fill-if-nil rule as the existing fields:

- `role`: filled only when the receiver's is nil.
- `manifest`: filled only when the receiver's is nil. It is never
  overwritten, because a pointer that's already set is a deliberate choice.

The merge doc comment (`:93`) lists both fields.

**Migration from extras.** A pre-0.2.0 document may already carry `role:` or
`manifest:` as extras, for example written by Personaje as a stopgap. Those
now decode straight into the typed fields, because they are declared keys.
No migration step is needed.

### RQ-25: `appearance` is deprecated

**This supersedes RQ-5, which deferred `appearance`, and closes RQ-Q2, which
asked about one LoRA versus a list.** Visual assets — portraits, sheets,
LoRAs and trigger words — belong in the character's manifest, which
SwiftSemblanzas defines in §5.3. They do not go in `CAST.md`.

- **`appearance` will never be declared.** No `Appearance` type, and no
  `appearance` coding key.
- **No data loss.** An existing `appearance:` block keeps round-tripping
  through `extraKeys` exactly as it does in 0.1.0. The existing tests for
  that behaviour stay, reframed as legacy-data tests:
  - `FixtureIntegrityTests.swift:67-100`
  - `AcceptanceGateTests.swift:155-181`
  - `CastMemberCodingTests.swift:210-253`
  - `YAMLCodingTests.swift` appearance cases
- **`reparto validate` warns** for each member with an `appearance:` extra:
  "appearance is deprecated; visual assets belong in the character manifest
  (`manifest:`)." It is a warning only, exit 0.
- **Documentation is updated so nothing still promises the field:**
  - `README.md:68-74`: the example YAML swaps `appearance` for `manifest` and `role`.
  - `AGENTS.md:128-142`: the section becomes "appearance is deprecated".
  - `AGENTS.md:167`: the consumer table.
  - The `CastMember.swift` doc comments (`:36-50`, `:138`, `:176`, `:263`, `:302`, `:341`).
  - The `CastSchemaVersion.swift:77-78` comment, which cites `appearance` as
    the next planned bump.
  - `CastMarkdownParser.swift:400-406`.
  - `CHANGELOG.md`: a 0.2.0 entry.
  - Fixture `all-fields-CAST.md` keeps its `appearance:` block, labelled as
    legacy.
- **SwiftSemblanzas** was the only planned writer of `appearance`. Its
  requirements already moved to the manifest (§4.3).

### D-14: no schema version bump

The bump rule is D-12: bump when an older reader would *misinterpret* the
shape. `role` and `manifest` are optional additions. A 0.1.0 reader sweeps
them into `extraKeys` and writes them back unchanged, so nothing is
misinterpreted. **`CastSchemaVersion.current` stays `1`.**

There is one cost. A 0.1.0 reader doesn't know `role` values, so it won't
reject bad ones; it carries them as strings. That's acceptable.

### RQ-26: `lineCount` (added 2026-11-07, target 0.3.0)

Decided by the user on 2026-11-07 (Personaje APP-UI UD21: the episodes are
the only source of the cast list).

- Add `public var lineCount: Int?` to `CastMember`, plus the matching init
  parameter (default `nil`). The wire key is exactly `lineCount`.
- **Meaning.** The number of lines the character speaks across all of the
  project's episodes (screenplays), as counted by the parse. The value is
  SwiftCompartido's `extractAllCharacters()` `lineCount` for that character.
- **Derived, never hand-edited.** The only writer is cast discovery:
  SwiftPersonaje's discovery writer, run by the Personaje app's "Create
  CAST.md" / "Rebuild Cast from Episodes". *Changed 2026-11-07:* the
  Personaje app is the only builder of CAST.md; no other tool writes the cast
  list (RQ-27). Reparto
  doesn't compute it, check it against anything, or set it on any other path
  (`reparto import`, `canonicalize`).
- **Absent means "not counted yet"**: a `CAST.md` written before this field,
  or a member a person added by hand. Absent is not `0`. Reparto never fills
  in a value.
- **Decoding** reads a YAML integer. A value that isn't a non-negative
  integer fails the parse with a new
  `CastParseError.invalidLineCount(index:value:)` that names the member and
  the bad value, the same treatment `role` gets (RQ-19).
- **Round-trip.** A member with `lineCount` re-encodes it unchanged; a member
  without it encodes with no `lineCount` key, so a `CAST.md` written by
  0.2.x loads and re-writes with no data change and passes the RQ-11 SHA-256
  gate. The emission position is the implementation's choice, pinned by a
  fixture, under the same rule as RQ-23 (withdrawn): the first 0.3.0 write
  may move a `lineCount` that a newer writer put elsewhere.
- **Merge rule: replace, not fill.** This is the one exception to the
  fill-if-nil rule of RQ-24 and the existing fields. In
  `backfilled(from:)`, when the incoming (discovered) member's `lineCount`
  is non-nil, it **replaces** the receiver's value, whether the receiver's
  was nil or not. When the incoming value is nil, the receiver's value is
  kept. So every discovery run refreshes the count of each member it
  discovers, new and existing alike, and a merge from a source that carries
  no counts (`reparto import`, PROJECT.md) never erases one.
- The merge doc comment (`:93`) and the `AGENTS.md` merge section ("The
  receiver keeps every field it already has") name `lineCount` as the
  exception.
- **Migration from extras.** A document a newer writer produced before this
  release may carry `lineCount:` as an extra. It decodes straight into the
  typed field, because it is a declared key. No migration step is needed.

### RQ-27: `castVersion` (added 2026-11-07, target 0.3.0)

Decided by the user on 2026-11-07, for the Personaje app's process.

- Add `castVersion: Int?` to `CastDocument`'s front matter, beside `type` and
  `schemaVersion`. The wire key is exactly `castVersion`.
- **Meaning.** The number of commits in the project's git repository
  (`git rev-list --count HEAD`) when the cast was built: the commit the cast
  list was read from. It is not a format version; `schemaVersion` still is.
- **Who writes it.** Only the Personaje app, on "Create CAST.md" and "Rebuild
  Cast from Episodes", which refuse to run unless the project folder is
  pristine (no uncommitted or untracked changes). Reparto never computes it
  and never changes it on any other path; a merge leaves it as it is.
- **Absent** means the file wasn't built by the app (hand-written, or written
  before 0.3.0). It round-trips unchanged; a 0.2.x file loads with no data
  change. A value that isn't a non-negative integer fails the parse with
  `CastParseError.invalidCastVersion(value:)`.
- No schema version bump (D-12): it's an optional addition.

### D-15: no schema version bump for `lineCount`

D-12 applies as it did for D-14: `lineCount` is an optional addition. A 0.2.x
reader sweeps it into `extraKeys` and writes it back unchanged, so nothing is
misinterpreted. **`CastSchemaVersion.current` stays `1`.**

There is one cost. A 0.2.x reader merges `extraKeys` per key, fill-if-absent,
so a discovery run linked against 0.2.x would never refresh an existing count.
Only the SwiftPersonaje discovery writer sets `lineCount`, and it requires
0.3.0, so that combination doesn't happen.

---

## 3. Invariants

- **RQ-INV-4.** Reparto never generates or rewrites a `character` value
  unless the caller explicitly asks for it (RQ-22). The name in `CAST.md` is
  the screenplay's name, not Reparto's.

RQ-INV-1 through 3 (single writer, body preservation, and the rest) are
unchanged.

---

## 4. Consumers

| Consumer | Impact |
|----------|--------|
| **SwiftEchada**, the only one wired today (29 files import Reparto; pinned `upToNextMajor(from: "0.1.0")`, so 0.2.0 resolves without a manifest change) | `.vox` output follows the `manifest` pointer, and file names use `canonicalName` (SwiftEchada `REQUIREMENTS.md` EC-23, EC-24). `verify cast` was removed in Echada 2.0.0, and nothing in Echada compares `role` / `manifest` as fields. |
| **SwiftSemblanzas** (docs only) | Reads `manifest`, `role`, `canonicalName`. Never writes `appearance`. |
| **Personaje** (docs only) | Writes `role` and `manifest` through `CastDocument`. |
| **SwiftPersonaje** discovery writer (from 0.3.0) | The only writer of `lineCount` (RQ-26), through `merging(_:)`. |
| **Produciesta** | No change. It ignores unknown fields today. |

---

## 5. Acceptance criteria

1. A `CAST.md` with `role:` and `manifest:` decodes into typed fields and
   re-encodes byte-identically. Pinned fixture.
2. Every existing fixture passes the RQ-11 SHA-256 gate unchanged.
3. `role: star` fails with `CastParseError.invalidRole(index:, value: "star")`.
4. *Withdrawn with RQ-21.* `manifest` is opaque: any path round-trips and
   `reparto validate` reports no path-shape finding.
5. A `manifest` written with an absolute path under the CAST.md directory is
   emitted as relative.
6. `canonicalName` passes a table test covering every example in RQ-22,
   including the throwing cases.
7. Merging a member named `NARRATOR (V.O.)` into a document containing
   `NARRATOR` backfills. It doesn't append.
8. An `appearance:` block round-trips unchanged, and `reparto validate`
   emits the deprecation warning.
9. `reparto canonicalize` changes nothing without `--apply`, and refuses on
   a collision.
10. *(RQ-26, 0.3.0)* A `CAST.md` with `lineCount:` decodes into the typed
    field and re-encodes byte-identically. Pinned fixture.
11. *(RQ-26)* Every 0.2.x fixture (no `lineCount`) loads with `lineCount`
    nil and passes the RQ-11 SHA-256 gate unchanged.
12. *(RQ-26)* `lineCount: -1` and `lineCount: many` fail with
    `CastParseError.invalidLineCount`.
13. *(RQ-26)* Merging a member with `lineCount: 40` into a receiver with
    `lineCount: 12` gives `40`; into a receiver with none gives `40`. Merging
    a member with no `lineCount` into a receiver with `12` keeps `12`. Every
    other field stays fill-if-nil.
14. *(RQ-27)* A front matter with `castVersion: 57` decodes to `57` and
    re-encodes unchanged; one without it encodes with no `castVersion` key;
    `castVersion: -1` fails with `invalidCastVersion`.

---

## 6. Open questions

| # | Question | Recommendation |
|---|----------|----------------|
| RQ-Q4 | Should `validate` treat non-canonical names as errors instead of warnings? | Warnings in 0.2.0, since live projects may have mixed case. Errors once `reparto canonicalize` has run across the podcasts. |
| RQ-Q5 | Should a member with assets be required to have a `role`? | No. Reparto stays permissive, and SwiftSemblanzas flags a missing role as incomplete. |
| RQ-Q6 | Version: 0.2.0 or 1.0.0? | 0.2.0. The changes are additive, and `appearance` was never shipped as a field. 1.0.0 can wait until the character record has been through a production. |
