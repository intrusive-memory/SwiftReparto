---
type: doc
title: SwiftReparto — Agent Instructions
updated: 2026-08-01
---

# AGENTS.md

Canonical project context for AI agents (Claude, Gemini, Codex) working in
SwiftReparto. `CLAUDE.md` and `GEMINI.md` are symlinks to this file — there is
one document, not three copies to keep in sync.

## What this package is

SwiftReparto owns `CAST.md`: the schema, the parser, the serializer, and the
round-trip guarantees for a production's cast list. Ships as two products —
the `SwiftReparto` library and the `reparto` executable. No GUI, no models,
no network. See [REQUIREMENTS.md](docs/complete/operation-troupe-marshal/REQUIREMENTS.md) for the full contract and
[EXECUTION_PLAN.md](docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md) for the mission that built it
(OPERATION TROUPE MARSHAL, Decisions D-1 through D-13).

## Current version

**Tag `v0.1.0` — version string `0.1.0`** (the first **stable** release of
this package, promoted from prerelease `v0.1.0-beta.1`).

The two spellings are deliberate and both are load-bearing:

- **The tag carries the `v`** — org convention across `intrusive-memory`
  (SwiftEscribo `v0.1.0`…`v0.3.0`, SwiftProyecto `v4.8.1`). Use it for
  `gh release download` and anything else that names a git ref.
- **`Sources/RepartoCLICore/RepartoVersion.swift`'s `RepartoVersion.current`
  does not** — it is `"0.1.0"`. `release.yml` derives the tarball name
  from `VERSION="${TAG#v}"`, so the constant, `reparto --version`, and
  `reparto-0.1.0-arm64-macos.tar.gz` all agree character-for-character,
  and SwiftPM's `exact:` requirement takes that same unprefixed string.

The constant and this section must always name the same release —
`reparto --version` reads the constant and this file is where a human or
agent looks first. A future release bumps both together.

## Hard constraints

- **The leaf invariant (RQ-INV-1).** SwiftReparto declares no dependency on
  any `intrusive-memory` package, and never will. This is not a style
  preference — SwiftPM detects package-level dependency cycles at manifest
  load, before a single line of Swift is type-checked, and there is no
  target-level escape from one. `SwiftProyecto → SwiftEchada` is exactly that
  cycle in this org's own history; it is why the cast model could not simply
  live inside SwiftEchada. The only permitted dependencies, ever, are `Yams`
  (the `SwiftReparto` library target only) and `swift-argument-parser`
  (`RepartoCLICore` only — never the library target). `scripts/check-leaf-invariant.sh`,
  run as a step inside `tests.yml`'s `Test on macOS` job, is the automated
  guard.
- **One writer (RQ-INV-2).** Only SwiftReparto serializes `CAST.md`.
  Consumers — SwiftEchada, SwiftSemblanzas, Produciesta — read a
  `CastDocument`, mutate the value, and hand it back. Nobody splices YAML,
  rebuilds front matter field by field, or writes a `CAST.md` byte by any
  route that does not pass through `CastMarkdownParser.generate`/`write`.
  The `reparto` binary is a second *door* onto this rule, not an exception to
  it — see **CLI** below.
- **No inference, narrowed on one path only (RQ-INV-3, D-4).** SwiftReparto
  parses and serializes. It does not discover characters from screenplays,
  call a model, resolve defaults, or touch the network. The one narrow
  exception: on the *import* path, `ProjectCastImporter` may read the
  `cast:` key — and only that key — out of a `PROJECT.md` it is handed. It
  never reads `title`, `tts`, `episodes_index`, `variants`, `languages`, or
  any other project-level field, and it **never writes `PROJECT.md`**, under
  any circumstance. Import is read-only with respect to its source, full
  stop. Removing the now-migrated `cast:` block from `PROJECT.md` is out of
  scope for this whole mission (D-13) — nothing here does it, warns about
  it, or grows a flag to do it later.
- **Makefile-only builds. Never `swift build` / `swift test`.** Use `make`
  targets — `make help` lists them (`build`, `test`, `test-ios`, `release`,
  `install`, `clean`, `resolve`, `format`). Locally that means XcodeBuildMCP
  tools when working interactively; CI uses raw `xcodebuild` through the
  Makefile. `Makefile`'s own header greps `Sources/`-adjacent tooling for the
  literal `swift build`/`swift test` strings and forbids reintroducing them,
  including inside a comment explaining why they're banned.
- **Apple Silicon only, arch always pinned.** Every build/test invocation
  pins `arch=arm64` and `ARCHS=arm64`. Intel and Rosetta are out of scope.

## Branch topology

- `main` — protected, PR-only. Releases are tagged from here.
- `development` — the repository's default branch. Mission and feature work
  targets here first.
- `mission/<slug>/<NN>` — sortie branches, opened against `development`.
- Flow: `mission/<slug>/<NN>` → `development` → `main` → tag.

Both `main` and `development` carry branch protection with
`required_status_checks.strict: true` and contexts exactly
`["Test on macOS", "Test on iOS Simulator"]`; `main` additionally sets
`enforce_admins: false` (D-11 — on a single-maintainer repo the admin *is*
the maintainer, so the real enforcement is `strict: true` plus non-empty
contexts, which stops an accidental stale merge rather than deliberate
action).

## Schema

- **Front-matter key: `schemaVersion`.** The value is a **monotonic integer
  starting at 1** (D-12) — never a string, never semver.
  `CastSchemaVersion.current` is `1` as of this beta.
- **A document parsed without `schemaVersion` is legacy, not invalid**
  (D-5). It decodes to the `unversioned` sentinel (`0`) and is accepted; it
  is never rejected for lacking a version.
- **Every document this library emits is stamped.** `generate`/`write`
  always write `CastSchemaVersion.current` into the front matter,
  regardless of what the source document declared. A legacy file therefore
  normalizes to a versioned one on its first write, unconditionally — there
  is no code path that skips the stamp.
- **Forward compatibility is a typed rejection, never best-effort.** A
  document declaring a version *greater* than `current` throws
  `CastParseError.unsupportedSchemaVersion(found:supported:)`. An older
  build that silently accepted a newer document would confidently rewrite
  it and drop whatever it didn't understand — RQ-INV-2's exact failure with
  a version number attached. A caller that wants best-effort behavior can
  catch the typed error and decide for itself.
- **Emission order is fixed, not sorted**: `type`, `schemaVersion`, `cast`,
  in that order, at the `encode(to:)` layer — this is what lets the YAML
  layer run with `sortKeys = false` (required for other reasons below) and
  still produce a stable key position for the SHA-256 round-trip gate.

### `appearance` is deferred (D-3), and here is exactly what that costs

There is no `Appearance` type in this beta and no `appearance` case in
`CastMember.CodingKeys`. The shape SwiftSemblanzas will eventually need — one
`lora` path, or a list of adapters with per-adapter rank/scale/engine
compatibility — is genuinely unscoped, and shipping a guess into a released
schema would turn a cheap future addition into an expensive migration.

Because `appearance` is not a declared key, an `appearance:` block present in
existing data is swept into `extraKeys` and re-emitted verbatim, exactly like
a hand-written `bio:`. **The deferral costs no data.** When `Appearance` is
eventually declared, those keys move from `extraKeys` to a typed field — that
move *is* a schema change, and it is exactly the migration the
`schemaVersion` field exists to make tractable: bump `current` by one,
document what changed, and an older build refuses the new document instead
of silently mangling it.

## `extraKeys` — reachable, not replaceable (D-8)

`CastMember.extraKeys` is `public private(set) var extraKeys: [String: AnyCodable]`.
Consumers never assign the dictionary wholesale — that would reintroduce the
exact overwrite failure RQ-INV-2 exists to prevent, one assignment
discarding every key the writer didn't know about. The only doors:

- Read: `member[extra: "bio"]`
- Write: `member.setExtra(_:forKey:)`

Both are reachable from a plain `import SwiftReparto`, deliberately not
gated behind `@testable import` — the acceptance test for `bio` preservation
has to pass through the same door a real consumer has.

## Consumer contract (REQUIREMENTS.md §7)

Recorded here so the boundary is checkable from this side without opening
another repo:

| Consumer | Reads | Writes back |
|---|---|---|
| **SwiftEchada** | Full roster | `voices.voxalta` |
| **SwiftSemblanzas** | `character`, `appearance` (via `extraKeys` while deferred), `bio` (via `extraKeys`) | `appearance.lora`, `appearance.triggerWord` (also via `extraKeys` until D-3 resolves) |
| **Produciesta** | Full roster | Voice assignments |
| **SwiftProyecto** | — | — (**not a consumer** — declares no dependency, retains no cast surface) |

Every write, from every consumer, arrives back at `CAST.md` through
`CastMarkdownParser.write` — no consumer serializes the file itself
(RQ-INV-2).

## The YAML dialect this library reads

**SwiftReparto reads YAML 1.2 core-schema semantics through a YAML 1.1
parser (Yams/libyaml), and narrows further wherever even 1.2 core would
change an author's spelling.** This is load-bearing for RQ-4 (undeclared
keys round-trip verbatim) and is implemented in
`Sources/SwiftReparto/YAMLCoding.swift`.

- **Booleans**: only the six YAML 1.2 core spellings —
  `true`/`True`/`TRUE`/`false`/`False`/`FALSE` — decode as `Bool`.
  `no`/`yes`/`on`/`off`/`y`/`n` (YAML 1.1's "Norway problem" set) stay
  `String`, in any case. This matters twice over: `no` is also the
  Norwegian BCP-47 tag, and an undeclared `retired: no` must not silently
  become `retired: false`.
- **Numbers**: a plain scalar becomes an `Int` **only when that is provably
  lossless in spelling** — `String(parsedInt) == originalText`. So `180`
  and `-5` decode as numbers, but `0755` (leading zero), `1_000` (digit
  separator), `12:34`/`1:00:00` (sexagesimal), and `0b1011`/`0o17`/`0x1f`
  all stay `String`, because re-rendering the parsed value would not
  reproduce the author's characters.
- **Floats never survive as numbers.** No floating-point spelling is
  reproducible on the emission path (`AnyCodable` collapses an
  integer-valued double to its JSON integer token, and a genuinely
  fractional value re-renders through a different formatter than any
  plausible source spelling). Every plain float-shaped scalar — including
  `.inf`, `-.inf`, `.nan`, which YAML 1.1 would otherwise throw decoding —
  is therefore kept as `String`.
- **The one documented cost, stated plainly: a preserved string re-emits
  quoted.** `mood: no` round-trips as `mood: 'no'`, and `code: 0755` as
  `code: '0755'`. The *characters* and the *meaning* survive; the *plain
  (unquoted) style* does not, and cannot — quoting is what stops Yams'
  numeric/boolean constructors from reinterpreting the value on the next
  read. A genuinely numeric `count: 180` is unaffected and stays bare.
- Only *plain, untagged* scalars are touched. A quoted `'no'`, an explicitly
  tagged `!!bool no`, and null resolution are all left exactly as parsed.

## `voices: {}` is deliberate, not a bug

A `CastMember` with no voice pointers still emits `voices: {}` rather than
omitting the key. `[String: [String]]` has no absent/empty distinction in
Swift, so omitting the key on emission would make "this character never had
a voice recorded" indistinguishable from "a human deliberately cleared this
roster entry." Emitting the empty mapping keeps that fact visible in the
file. (Sortie 10.)

## `merging(_:)` gap-fills; it does not overwrite

`[CastMember].merging(_:)` (RQ-14) matches on `character`, case- and
whitespace-insensitively. On a match:

- The receiver keeps **every field it already has**, untouched — an
  existing `voicePrompt`, `bio`, `actor`, `gender`, `language`, or a
  `voices` entry for a provider it already carries is never overwritten by
  the discovered version, no matter what that version holds.
- A field the receiver **lacks** is filled in from `discovered` — per-field
  for scalars, **per-provider** for `voices` (only a provider key absent
  from the receiver counts as a gap; a shared provider is left exactly as
  the receiver had it), and per-key for `extraKeys`.

A `discovered` member with no match is appended, in `discovered` order,
after every receiver member. `result.count >= self.count` always — merge
never prunes. This exists because Produciesta's `CastWriter` once rebuilt a
roster from only the current screenplay's discovered characters, which
against a project-wide `CAST.md` would have dropped 11 of 12 characters —
and their hand-written `bio` and `voicePrompt` with them.

## First write is a normalizing write — read this before filing a bug

**RQ-11's round-trip identity guarantee (`generate(parse(x)) == x` by
SHA-256) applies to documents this library emitted, not to arbitrary
hand-written input.** The first time any document — legacy or freshly
imported — passes through `generate`/`write`, four things can change its
bytes even though nothing about its *meaning* changed:

1. `schemaVersion` is stamped (or added, if absent).
2. Legacy `voiceDescription:` is rewritten to `voicePrompt:`.
3. A scalar `voices` provider (`voxalta: a.vox`) is normalized to array
   form (`voxalta: [a.vox]`).
4. Provider keys are lower-cased.
5. A scalar that would otherwise be misread under the YAML dialect above
   (`mood: no`, `code: 0755`) is quoted on the way back out.

None of this is data loss — every one of these is idempotent, and applying
`generate` to its own output a second time changes nothing further. But a
byte-diff between a hand-edited `CAST.md` and this library's first write of
it is expected, not a corruption symptom. **This is the single most likely
source of a surprised bug report** — check whether the input had already
been through this library's own `write` before treating a byte difference
as a defect.

## CLI

`reparto` ships two subcommands. It is a shell over the library (D-6): every
command's only calls into `SwiftReparto` are `parse`, `generate`, `write`,
and `ProjectCastImporter` — no command decodes a YAML block, locates a
document's delimited header, or builds markdown of its own. This is what
keeps RQ-INV-2's one-writer rule true with a binary in the picture: writing a
canonical `CAST.md` happens exactly two ways — direct library use, or
`reparto import` — and both end up inside the same `generate`/`write` pair.

- **`reparto validate <path>`** — parses `<path>` as a cast document.
  Reports nothing on success. `--quiet` suppresses the error message on
  failure and relies on the exit code alone.
- **`reparto import <project-md-path> [--output <path>] [--force] [--dry-run]`**
  — imports the `cast:` block out of a `PROJECT.md` and writes a versioned
  `CAST.md`. `--output` defaults to `CAST.md` beside the source file — every
  relative path in the imported roster is relative to *that* directory
  (D-7), so writing elsewhere silently invalidates them. `--dry-run`
  performs the import but writes nothing; the document that would have been
  written goes to standard output instead.

### Exit codes

Mapped in exactly one place (`RepartoExitCode` / `repartoExitCode(for:)` in
`ExitMapping.swift`) so `validate` and `import` cannot drift, and so
`reparto --help`'s discussion text and the code that actually computes an
exit status read the same four constants:

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | `CastParseError` — the document could not be parsed or imported. |
| `2` | `import`'s destination already exists (pass `--force` to overwrite). |
| `3` | `import`'s `--output` is outside the source `PROJECT.md`'s directory (pass `--force` to override). |
| `4` | Any other failure — for example, a file that cannot be read at all. |

`reparto --help` is the spec. If this table and `--help`'s discussion text
ever disagree, the code is right and this file is stale — file the
correction here, don't trust this table over the binary.

## Release

Two products, one release process: a release is a **tag + GitHub release
from `main`**, and `.github/workflows/release.yml` (triggered by
`release: published`, or manually via `workflow_dispatch`) runs `make
release` and attaches an **arm64 macOS tarball**
(`reparto-<version>-arm64-macos.tar.gz`, plus its SHA-256) to that release.
`release: published` fires for prereleases too — deliberate, so a beta gets
a downloadable tarball via `gh release download` even though Homebrew (see
below) will never see it.

### Homebrew: deferred for the entire beta — here is exactly why

The org's `intrusive-memory/homebrew-tap` is **pull**-based:
`scripts/reconcile-formulas.sh` runs on a **6-hour cron**, using only its own
`GITHUB_TOKEN`. Source repos — this one included — never dispatch to it; the
push direction (a cross-repo `repository_dispatch` using an org deploy
token) is dead, because that token expired and was deleted in July 2026.

Two verified facts in that script decide when a formula for this repo can
exist at all:

1. **It iterates `Formula/*.rb`** (`reconcile-formulas.sh:41` —
   `for formula_file in Formula/*.rb; do`). It only *re-resolves* formulas
   that already exist in the tap; it has no code path that discovers a new
   repo on its own. **The first formula for `reparto` has to be created by
   hand, in the tap repo, by someone.**
2. **It resolves the version to bump to via
   `repos/<owner>/<repo>/releases/latest`** (`reconcile-formulas.sh:66-68`),
   and that GitHub API endpoint **deliberately excludes prereleases** — a
   404 there is read by the script as "no stable release yet" and the
   formula is left alone.

Put together: even if a formula existed today, the cron would never move it
to a beta tag, and no formula is created automatically regardless. **Therefore:
no Homebrew formula during the beta.** One is created — by hand, in the tap
— when the first *stable* (non-prerelease) release ships. Do not create one
early to "get ahead of it," and do not promote a beta tag to a full release
just to make the tap notice it.

## Queryable Codemap

A prebuilt [graphify](https://pypi.org/project/graphifyy/) knowledge graph of this
codebase lives in [`graphify-out/`](graphify-out/) (671 nodes · 1325 edges). **Prefer
querying it before grepping** for architecture or "what connects to what" questions:

```bash
graphify query "How does X flow through the system?"
graphify path "TypeA" "TypeB"      # shortest path between two nodes
graphify explain "SomeType"        # plain-language node explanation
```

Human-readable summary: [`graphify-out/GRAPH_REPORT.md`](graphify-out/GRAPH_REPORT.md).
Refresh after significant changes with `/codemap` (or
`graphify . --backend claude-cli`).

## Testing and this document

`make test` runs the full suite (241 tests as of WU-5's close, across both
macOS and iOS Simulator destinations via `make test` / `make test-ios`).
In-source API documentation (DocC comments on every public declaration) is a
separate, later pass — this file does not restate what belongs there.
