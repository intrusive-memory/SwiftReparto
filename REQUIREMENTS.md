---
type: requirements
title: SwiftReparto — Requirements
status: beta
created: 2026-08-01
target_version: first beta release
---

# SwiftReparto — Requirements

**SwiftReparto is the cast-list parsing library.** It owns `CAST.md`: the schema, the parser, the
serializer, and the round-trip guarantees. It knows who is in a production. It knows nothing about
how they sound or how they look.

Ships as a Swift package with two products: the `SwiftReparto` library and the `reparto`
executable. No GUI, no models, no network.

> **Status: beta.** This repo contains `Package.swift`, `Package.resolved`, a `Makefile`, three
> source files, and a passing test suite, with a first commit already made. Implementation
> continues from `RQ-1`.

---

## 1. Why this package exists

Cast data currently lives in `PROJECT.md`'s YAML front matter as `ProjectFrontMatter.cast`, a
**SwiftProyecto** model. That is the wrong owner twice over:

- SwiftProyecto is a project-configuration library. Cast is not project configuration.
- The packages that actually *do* something with cast — SwiftEchada for voice, SwiftSemblanzas for
  visual identity — are downstream consumers parsing and mutating a schema neither of them owns.

Putting the cast model in either consumer is no better. If it lived in SwiftEchada, then
SwiftSemblanzas would have to depend on the entire MLX/TTS voice stack to read a character's name.
If it lived in SwiftSemblanzas, SwiftEchada would drag in FLUX.2 and LoRA training to do the same.
And SwiftProyecto could depend on neither without a package-level cycle.

So the cast model becomes its own leaf package. Every consumer depends on it; it depends on
nothing in the ecosystem.

```
                        SwiftReparto  (CAST.md: schema, parse, serialize)
                       ↗      ↑      ↖
          SwiftEchada       (…)       SwiftSemblanzas
        voice identity              visual identity
          → .vox files                → LoRA adapters

          SwiftProyecto  (PROJECT.md: project config only — no cast, no dependency here)
```

---

## 2. Separation of concerns

The boundary is a **contract**, not a convention. Each row is enforceable by inspection.

| Package | Owns | Never touches |
|---|---|---|
| **SwiftReparto** | `CAST.md`. The cast schema, its parser, its serializer, its losslessness guarantees | Audio, images, models, writing `PROJECT.md`, reading any `PROJECT.md` key other than `cast:`, the filesystem beyond the one file it is handed |
| **SwiftEchada** | Voice identity. Generates `.vox` from `voicePrompt`, records the pointer | The `CAST.md` byte stream — it mutates a `CastDocument` and hands it back to Reparto to write |
| **SwiftSemblanzas** | Non-voice identity. Trains per-character LoRA adapters, records the pointers | Same — never serializes `CAST.md` itself |
| **SwiftProyecto** | `PROJECT.md`. Project identity, episode discovery, variants, TTS config | Cast, in any form. No `CastMember`, no `cast:` key, no SwiftReparto dependency |

### RQ-INV-1 — The leaf invariant

**SwiftReparto declares no dependency on any `intrusive-memory` package, and never will.**

This is the load-bearing rule. It is what makes every consumer relationship acyclic by construction
rather than by discipline, and it is why the cast model could not simply be moved into SwiftEchada:
SwiftEchada depends on SwiftProyecto (its CLI reads `PROJECT.md` for `title`, `episodesDir`,
`filePattern`, `tts.model`), so `SwiftProyecto → SwiftEchada` would be a package-level cycle. SwiftPM
detects cycles at package granularity and fails at manifest load — there is no target-level escape.

The only permitted dependencies are `Yams` for YAML and `swift-argument-parser` for the CLI target
(`RQ-16`).

### RQ-INV-2 — One writer

**Only SwiftReparto serializes `CAST.md`.** Consumers read a `CastDocument`, mutate the value, and
hand it back. No consumer constructs YAML, splices text, or rebuilds front matter field by field.

This is not stylistic. SwiftProyecto issues #44 and #55 were exactly this failure: a consumer
rebuilding front matter field by field silently dropped unknown keys and flattened a nested
`episodes_index` through `NSDictionary.description`, taking a 309-line `PROJECT.md` down to 103
lines with no error. One writer and one round-trip test is the structural fix.

### RQ-INV-3 — No inference

SwiftReparto parses and serializes. It does not discover characters from screenplays, call a model,
resolve defaults, or touch the network. **Reparto imports the cast data; it does not own, resolve,
or write `PROJECT.md`.** It may read only the `cast:` key out of a `PROJECT.md` it is handed, on the
import path (`RQ-INV-3` narrowed by `D-4`); it never reads any other key, and it never writes that
file. Given the same bytes it returns the same document, on any machine, forever.

---

## 3. `CAST.md` schema

Lives beside `PROJECT.md`, in the project directory. Default filename `CAST.md`.

```markdown
---
type: cast
cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    language: en
    voicePrompt: "Deep authoritative British baritone. Warm, commanding documentary narrator."
    voices:
      voxalta:
        - voices/NARRATOR.vox
    appearance:
      portrait: characters/narrator/source/01.png
      lora: characters/narrator/lora/narrator-v2.safetensors
      triggerWord: nrrtr_v2
  - character: THE PRACTITIONER
    voicePrompt: "Younger adult male voice. Conversational, sometimes anxious, occasionally wry."
    bio: "Neurodivergent (ADHD), gay Gen X developer in his late forties…"
    voices:
      voxalta: voices/THE_PRACTITIONER.vox
---

# Cast

## Major Characters

### NARRATOR

Summary prose here.

## Minor Characters

### …
```

### 3.1 Front matter

- **`type: cast`** — document discriminator, lowercase, matching the `type: project` convention in
  `PROJECT.md`.
- **`cast:`** — array of cast members.

**RQ-1 — Acceptance requires both.** A document is a cast document only if it declares `type: cast`
**and** carries a `cast:` key. Requiring both is deliberate: the repo-wide markdown frontmatter
policy forces a `type:` onto every `.md` file, so a `type:`-only check would match arbitrary prose
documents. Anything failing either test is rejected with a typed error, never silently parsed as an
empty cast.

### 3.2 `CastMember` fields

| Field | Type | Notes |
|---|---|---|
| `character` | `String`, required | Character name as it appears in CHARACTER cues |
| `actor` | `String?` | Credits / reference only |
| `gender` | `Gender?` | `M` / `F` / `NB` / `NS` |
| `language` | `String?` | BCP-47 |
| `voicePrompt` | `String?` | Preferred key. Legacy alias `voiceDescription` must still decode |
| `voices` | `[String: [String]]` | Provider → file paths. Scalar form (`voxalta: path.vox`) must still decode |
| `appearance` | — (not a declared `CodingKey`) | **Deferred out of the beta.** Round-trips through `extraKeys`. See §3.3 |
| *(unknown keys)* | — | Preserved verbatim via `extraKeys`. This is how `bio:` survives |

**RQ-2 — `Gender`** is `M` / `F` / `NB` / `NS`, `Codable`, `Sendable`, `CaseIterable`. Moves here
from SwiftProyecto, where it has zero references outside its own defining file.

**RQ-3 — Decode every form in the wild.** `voicePrompt` and legacy `voiceDescription`; `voices` as
both scalar and array. `~/Projects/podcasts/confessions/PROJECT.md` uses the scalar form and is the
pinned fixture. Emission normalizes to the array form; decoding never rejects the scalar.

**RQ-4 — `extraKeys` round-trips losslessly.** Unknown per-member keys decode into `extraKeys` and
re-emit verbatim. `bio:` is the live case — it exists in production data, nothing in the ecosystem
declares it, and it must survive every write by every consumer.

### 3.3 `Appearance` — deferred out of the beta

**RQ-5** — **Deferred, not removed from the design.** `Appearance` is not defined as a type in the
beta, and `appearance` is not a declared `CodingKey` on `CastMember`. The shape it will eventually
carry — a `portrait` path, a `lora` adapter path, a `triggerWord`, or something richer such as
`[LoRAAsset]` with per-adapter rank/scale/engine-compatibility — is genuinely unscoped until
SwiftSemblanzas confirms it, and shipping a guess in a released schema would turn a cheap later
addition into an expensive one.

In the meantime, an `appearance:` key present in existing data is **not** dropped: because it is an
undeclared key, it is swept into `extraKeys` and round-trips verbatim under `RQ-4`, exactly like
`bio:`. The deferral costs no data. When `Appearance` is eventually declared, those keys move from
`extraKeys` to a typed field — a schema change, which is exactly what the `schemaVersion` field
(`RQ-Q3`) exists to make tractable.

### 3.4 Path semantics

**RQ-6** — All file references (`voices.*`, `appearance.portrait`, `appearance.lora`) are relative
to **the directory containing `CAST.md`**. Absolute paths decode but are never emitted.

**RQ-7** — SwiftReparto does not resolve, validate, or touch these paths. It carries strings. A
consumer that wants to know whether a `.vox` exists asks the filesystem itself.

### 3.5 Body

**RQ-8** — Everything after the front matter is free markdown, carried as an opaque `String` and
re-emitted **byte-for-byte**. Reserved structure is `## Major Characters` / `## Minor Characters`
with an `###` heading per character. SwiftReparto never generates, parses, or reformats it.

---

## 4. API

### RQ-9 — `CastDocument`

```swift
public struct CastDocument: Codable, Sendable, Equatable {
  public var cast: [CastMember]
  public var body: String
}
```

The unit of read-modify-write. Consumers mutate `cast` and leave `body` alone.

### RQ-10 — `CastMarkdownParser`

```swift
public struct CastMarkdownParser: Sendable {
  public init()
  public func parse(content: String) throws -> CastDocument
  public func parse(fileURL: URL) throws -> CastDocument
  public func generate(document: CastDocument) throws -> String
  public func write(document: CastDocument, to fileURL: URL) throws
}
```

**RQ-11 — Round-trip identity.** `generate(parse(x)) == x` for any `x` this library emitted, and for
every pinned fixture. This is the acceptance gate, asserted by SHA-256, not by eyeball.

**RQ-12 — Typed errors.** A `CastParseError` distinguishing missing front matter, malformed YAML,
missing `type: cast`, missing `cast:`, and a missing required `character`. No `fatalError`, no
silent empty-cast fallback — a caller must be able to tell "this is not a cast document" from
"this cast document is empty."

### RQ-13 — `AnyCodable`

Vendored here, not imported. `RQ-INV-1` forbids depending on SwiftProyecto, which is where the
current implementation lives.

This is a real cost and worth stating plainly: the exact JSON round-trip semantics of `AnyCodable`
are what make `extraKeys` lossless, and there will briefly be two copies. **SwiftReparto's copy is
canonical.** SwiftProyecto should consume `AnyCodable` *from* SwiftReparto once Reparto 1.0 ships,
collapsing the twins — but that is a follow-on, not a blocker, and it is the one place the leaf
invariant may later be relaxed in the other direction (`SwiftProyecto → SwiftReparto`, which is
acyclic and legal). A **third** copy exists at
`SwiftEscribo/Sources/EscriboProject/CastMember.swift`, with its own `AnyCodable.swift`; folding it
in is a follow-on outside this mission as well.

### RQ-14 — Merge

```swift
public func merging(_ discovered: [CastMember]) -> [CastMember]
```

Additive by default: members present in the receiver keep every field; members in `discovered` and
not the receiver are appended; matching is case- and whitespace-insensitive on `character`.
**Never prunes.** Pruning is a consumer's explicit, flagged operation, never a side effect of merge.

This exists because the alternative is each consumer writing its own merge, and one of them
already got it wrong: Produciesta's `CastWriter` deletes every member absent from the *current
screenplay's* roster, which against a project-wide `CAST.md` would drop 11 of 12 characters —
taking their hand-written `bio` and `voicePrompt` with them, and orphaning the `.vox` files those
prompts produced.

---

## 5. Non-goals

Not deferred. **Out of scope by design** — each belongs to a named owner.

| Not this package | Owner |
|---|---|
| Discovering characters from screenplays | SwiftEchada (`CastExtractor` / `SourceMaterialLocator`) |
| Generating `voicePrompt` text | SwiftEchada (Foundation Models) |
| Generating `.vox` files | SwiftEchada + SwiftVoxAlta |
| Training LoRA adapters, portraits, DINOv2 gating | SwiftSemblanzas |
| Reading or writing `PROJECT.md` | SwiftProyecto |
| Major/minor classification and body prose | Deferred; see the SwiftEchada `DEF-1` |
| Character discovery, prompt generation, `.vox`/LoRA generation via the CLI | SwiftEchada, SwiftSemblanzas — `reparto` is a shell over this library, bounded to `validate` and `import` |

---

## 6. Package

**RQ-15** — Swift 6.2, `swiftLanguageModes: [.v6]`, strict concurrency, `Sendable` throughout.
Platforms `.macOS(.v26)`, `.iOS(.v26)`, matching the collection.

**RQ-16** — Exactly two dependencies, split by target: `jpsim/Yams` for YAML, used by the
`SwiftReparto` target only; `apple/swift-argument-parser`, used by `RepartoCLICore` only. Zero
package dependencies for `Yams` itself, one resolved pin, with `libyaml` vendored as an internal C
target. Adding any `intrusive-memory` dependency violates `RQ-INV-1`.

**RQ-17** — Two products: the `SwiftReparto` library, and a `reparto` executable. The CLI's purpose
is bounded to two jobs: validate a cast document, and import cast data from `PROJECT.md`. The CLI is
a shell over the library — it parses no YAML and serializes no markdown of its own, so `RQ-INV-2`'s
one-writer rule still holds with the binary in the picture.

**RQ-18** — Repo `intrusive-memory/SwiftReparto`, added to `collection.json`. Does not exist yet.

---

## 7. Consumers

Recorded so the boundary is checkable from this side.

| Consumer | Reads | Writes back | Notes |
|---|---|---|---|
| **SwiftEchada** | Full roster | `voices.voxalta` | Its light `SwiftEchada` library target depends on Reparto **only** — it imports SwiftProyecto today at exactly two sites (`CharacterProfile.swift:2`, `CharacterMerger.swift:1`) for exactly two symbols, `Gender` and `CastMember`, both of which move here. `EchadaCLICore` keeps SwiftProyecto for project-level fields |
| **SwiftSemblanzas** | `character`, `appearance`, `bio` | `appearance.lora`, `appearance.triggerWord` | `CAST.md` is canonical; the SwiftData catalog in its `REQUIREMENTS.md` §4.1 is a derived index keyed by character slug, rebuildable from the markdown |
| **Produciesta** | Full roster | Voice assignments | Needs only this light library for cast reads — not `SwiftEchada`, not `EchadaCLICore` |
| **SwiftProyecto** | — | — | **Not a consumer.** Declares no dependency, retains no cast surface |

---

## 8. Acceptance criteria for 1.0.0

1. `make test` green. Never `swift build` / `swift test`.
2. Round-trip SHA-256 identity against `Fixtures/confessions-CAST.md` — scalar `voices`, a
   multi-sentence `voicePrompt`, and a per-member `bio` all survive unchanged.
3. `extraKeys` preservation asserted on `bio` specifically, by name.
4. Body preserved byte-for-byte across a mutate-and-write cycle.
5. Legacy `voiceDescription` and scalar-`voices` decoding both covered.
6. `appearance` is deferred out of the beta (no declared type or `CodingKey`, §3.3), and an
   `appearance:` key present in existing data still round-trips verbatim through `extraKeys`.
7. `merging(_:)` proven additive: a merge against a one-character roster leaves a twelve-character
   document at twelve characters.
8. Rejection covered: `type:`-only, `cast:`-only, and neither.
9. `Package.swift` declares zero `intrusive-memory` dependencies.

---

## 9. Open questions

- **RQ-Q1 — `AnyCodable` reunification.** Ship the vendored copy in 1.0 and collapse the twins in a
  follow-on, or block 1.0 on SwiftProyecto consuming it from here? *Recommendation: ship vendored,
  collapse later. Blocking 1.0 on a SwiftProyecto release inverts the sequencing for no gain.*
- **RQ-Q2 — `Appearance` shape.** Is one LoRA per character enough, or does SwiftSemblanzas need
  `[LoRAAsset]` with per-adapter rank/scale/engine-compatibility (its `REQUIREMENTS.md` §4.1
  suggests the latter)? Getting this wrong means a schema change rather than a field addition.
  *Recommendation: confirm with SwiftSemblanzas before tagging 1.0 — it is cheap now and expensive
  after.*
- **RQ-Q3 — Does `CAST.md` carry a `version:`?** Reversed: yes. Every `CAST.md` document this
  library emits carries a `schemaVersion` in its front matter. A document parsed without one is
  legacy, not invalid — it decodes to an unversioned sentinel and is stamped with the current
  version on its next emit. A document declaring a version newer than the library supports is a
  typed rejection, never a silent best-effort parse. *Deferring `Appearance` out of the beta (§3.3)
  means the schema will change, so an unused-field objection no longer holds — the version field
  is what makes that iteration tractable.*
