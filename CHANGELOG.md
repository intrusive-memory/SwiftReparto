---
type: changelog
title: SwiftReparto — Changelog
updated: 2026-08-01
---

# Changelog

All notable changes to SwiftReparto are recorded here. Format is loosely
[Keep a Changelog](https://keepachangelog.com/); versioning is
[Semantic Versioning](https://semver.org/) once a stable line exists.

## [0.1.0-beta.1] — 2026-08-01

Tagged `v0.1.0-beta.1`, published as a **prerelease**. The initial beta as
built by OPERATION TROUPE MARSHAL (see `docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md`). `reparto
--version` reports `0.1.0-beta.1` — the tag's leading `v` is a tag-naming
convention and is not part of the version string.

### Added

- **`CastDocument` / `CastMarkdownParser`** — the `CAST.md` schema, parser,
  and generator. Round-trip identity (`generate(parse(x)) == x`) asserted by
  SHA-256 against pinned fixtures, for every document this library emits
  (RQ-11).
- **`CastMember`** — the per-character record: `character`, `actor`,
  `gender`, `language`, `voicePrompt` (with a deprecated `voiceDescription`
  shim, both accessors), and `voices: [String: [String]]`. Undeclared
  per-member keys (`bio:`, a deferred `appearance:` block) round-trip
  verbatim through `extraKeys`, reachable only via `subscript(extra:)` and
  `setExtra(_:forKey:)`.
- **`schemaVersion`** — a monotonic integer front-matter key, starting at 1.
  An unversioned document is legacy, not invalid, and is stamped with the
  current version on its first write. A document declaring a newer version
  than this build supports is a typed rejection
  (`CastParseError.unsupportedSchemaVersion`), never a silent best-effort
  parse.
- **`ProjectCastImporter`** — imports the `cast:` key (and only that key)
  out of a `PROJECT.md`, producing a versioned `CastDocument` with an empty
  `body`. Read-only with respect to `PROJECT.md`: it never writes that file
  and never removes its now-migrated `cast:` block.
- **`[CastMember].merging(_:)`** — additive, gap-filling merge. Matches on
  `character`, case- and whitespace-insensitively; never overwrites a field
  the receiver already has; never prunes.
- **`reparto` CLI** — `reparto validate <path>` and
  `reparto import <project-md-path>`, a thin shell over the library (no
  parsing or serialization of its own). Exit codes: `0` success, `1`
  `CastParseError`, `2` destination exists, `3` destination directory
  mismatch, `4` any other failure.
- **`AnyCodable`** — vendored, canonical copy backing `extraKeys`'s lossless
  round-trip. `SwiftProyecto` and `SwiftEscribo` each carry their own twin
  today; this package is the intended collapse target (RQ-13, D-9).
- Full CI: `tests.yml` (macOS + iOS Simulator), `lint.yml` (`swift format`
  in lint mode), `release.yml` (attaches an arm64 macOS tarball to a
  published release, including prereleases).

### Deferred

- **`Appearance`** (D-3) — no `Appearance` type and no `appearance`
  `CodingKey` in this beta. An `appearance:` block in existing data survives
  verbatim in `extraKeys` until the type is declared, at which point those
  keys move to a typed field — a schema change the `schemaVersion` field
  exists to make tractable.
- **Homebrew formula** — not created during the beta. The tap resolves
  versions through `releases/latest`, which excludes prereleases, and its
  reconcile script only re-resolves formulas that already exist; nothing
  discovers this repo automatically. A formula is created by hand in the tap
  when the first stable release ships.

### Out of scope for this mission

- Migrating `PROJECT.md`'s existing `cast:` block out of SwiftProyecto, or
  filing any tracked work against SwiftProyecto to do so (D-13, user
  override).
- Folding SwiftEscribo's third copy of the cast model
  (`EscriboProject/CastMember.swift`) into this package. Recorded in
  `docs/complete/operation-troupe-marshal/REQUIREMENTS.md` RQ-13 and tracked as a follow-on issue on SwiftEscribo
  (D-9).
