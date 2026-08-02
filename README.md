---
type: doc
updated: 2026-08-01
status: pre-alpha
---

# SwiftReparto

**The cast list, as a file.** SwiftReparto owns `CAST.md` — the schema, the parser, the serializer,
and the guarantee that nothing you hand-wrote in it ever disappears.

Part of the [intrusive-memory](https://github.com/intrusive-memory) ecosystem. Ships as a Swift
**library** only — no CLI, no models, no network.

> **Status: pre-alpha / design.** This repo currently contains design docs only.
> See [REQUIREMENTS.md](REQUIREMENTS.md).

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

## Requirements

| | Minimum |
|---|---|
| **macOS** | 26.0 |
| **iOS** | 26.0 |
| **Swift** | 6.2 |

## Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) — schema, API, invariants, acceptance criteria.

## License

MIT.
