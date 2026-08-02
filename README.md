---
type: doc
updated: 2026-08-01
status: beta
---

# SwiftReparto

**The cast list, as a file.** SwiftReparto owns `CAST.md` — the schema, the parser, the serializer,
and the guarantee that nothing you hand-wrote in it ever disappears.

Part of the [intrusive-memory](https://github.com/intrusive-memory) ecosystem. Ships as the
**SwiftReparto** library plus a `reparto` executable — no GUI, no models, no network.

> **Status: beta.** Two products ship: the `SwiftReparto` library and the
> `reparto` executable. See [REQUIREMENTS.md](docs/complete/operation-troupe-marshal/REQUIREMENTS.md) for the full
> contract and [AGENTS.md](AGENTS.md) for the standing rules a consumer or
> contributor needs — the schema version, the CLI's exit codes, and the YAML
> dialect this library reads.

## Why

A production's cast is referenced by everything and owned by nothing. Voice generation needs it.
Storyboard generation needs it. The project-config library was carrying it by accident, and both
of the packages that actually *use* it were parsing and rewriting a schema neither one owned.

Moving it into either consumer just relocates the problem — SwiftSemblanzas would have to link the
entire MLX/TTS stack to read a character's name, and SwiftEchada would have to link FLUX.2 to do
the same. So the cast list gets its own package, and that package sits at the bottom.

## The shape of it

```
                        SwiftReparto   ← CAST.md: schema, parse, serialize
                       ↗             ↖
          SwiftEchada                  SwiftSemblanzas
        voice identity                 visual identity
          → .vox files                   → LoRA adapters

          SwiftProyecto   ← PROJECT.md: project config only. No cast. No dependency here.
```

Three rules do the work:

- **SwiftReparto is a leaf.** It depends on no `intrusive-memory` package and never will. That makes
  every consumer relationship acyclic by construction rather than by discipline — and it is the
  reason the cast model could not simply live in SwiftEchada, which already depends on
  SwiftProyecto.
- **One writer.** Only SwiftReparto serializes `CAST.md`. Consumers mutate a `CastDocument` value
  and hand it back. Nobody splices YAML.
- **No inference.** Parse and serialize, nothing else. No screenplay discovery, no model calls, no
  filesystem beyond the one file it is given.

## What's in the file

YAML front matter with the cast roster, then free markdown for character summaries. Unknown keys
round-trip verbatim — a hand-written `bio:` survives every write by every consumer, which is the
whole point.

```yaml
---
type: cast
cast:
  - character: NARRATOR
    voicePrompt: "Deep authoritative British baritone. Measured pacing."
    voices:
      voxalta: [voices/NARRATOR.vox]
    appearance:
      lora: characters/narrator/lora/narrator-v2.safetensors
      triggerWord: nrrtr_v2
---
```

`voices` is written by SwiftEchada. `appearance` is written by SwiftSemblanzas. Neither reaches for
the other's keys, and neither writes the file.

## Install

Two products, two install paths. There is no Homebrew formula yet — the org's
tap only tracks stable releases, and this is a beta (see
[AGENTS.md](AGENTS.md#release) for exactly why).

### The library, via Swift Package Manager

```swift
.package(url: "https://github.com/intrusive-memory/SwiftReparto.git", exact: "0.1.0-beta.1")
```

(The git tag is `v0.1.0-beta.1`; SwiftPM's `exact:` takes the unprefixed
semver and resolves the `v`-prefixed tag itself.)

Then depend on the `SwiftReparto` product in the target that reads or writes
cast data. `RepartoCLICore` is deliberately not a product — the library
carries no CLI dependency.

### The `reparto` binary, via `gh release download`

```sh
gh release download v0.1.0-beta.1 \
  --repo intrusive-memory/SwiftReparto \
  --pattern 'reparto-*-arm64-macos.tar.gz'
tar xzf reparto-*-arm64-macos.tar.gz
./reparto --version
```

Every release — including this beta — attaches an arm64 macOS tarball; see
`.github/workflows/release.yml`.

## Usage

### Import a cast from `PROJECT.md`

```swift
import SwiftReparto

let importer = ProjectCastImporter()
let document = try importer.importCast(fileURL: projectMdURL)

// Write it out as a new, versioned CAST.md beside the PROJECT.md.
// ProjectCastImporter never writes PROJECT.md itself (read-only on that path).
let castURL = projectMdURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
try CastMarkdownParser().write(document: document, to: castURL)
```

Equivalently, from the shell:

```sh
reparto import path/to/PROJECT.md
```

### Parse, mutate, write

```swift
import SwiftReparto

let parser = CastMarkdownParser()
var document = try parser.parse(fileURL: castURL)

document.cast[0].actor = "Tom Stovall"
document.cast[0].voices["voxalta", default: []].append("voices/NARRATOR-alt.vox")
// document.body is left untouched — SwiftReparto never touches your prose.

try parser.write(document: document, to: castURL)
```

`reparto validate path/to/CAST.md` checks that a file parses at all, without
mutating it — useful as a pre-commit or CI check on hand-edited cast files.

## Requirements

| | Minimum |
|---|---|
| **macOS** | 26.0 |
| **iOS** | 26.0 |
| **Swift** | 6.2 |

## Documentation

- [REQUIREMENTS.md](docs/complete/operation-troupe-marshal/REQUIREMENTS.md) — schema, API, invariants, acceptance criteria.
- [AGENTS.md](AGENTS.md) — standing rules: the leaf invariant, the one-writer
  rule, the schema version policy, the YAML dialect, the CLI's exit codes,
  and why there's no Homebrew formula yet.

## License

MIT.
