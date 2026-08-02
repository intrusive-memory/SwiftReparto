---
type: mission-brief
feature_name: OPERATION TROUPE MARSHAL
iteration: 1
state: complete
updated: 2026-08-02
---

# OPERATION TROUPE MARSHAL — Mission Brief, Iteration 01

> **Mission** — A definable, testable scope of work, decomposed into sorties. **Sortie** — An atomic, testable unit of work executed by one autonomous agent in one dispatch. **Work Unit** — A grouping of sorties.

**Verdict: KEEP.** Full reasoning in §8.

---

## 1. What shipped

`intrusive-memory/SwiftReparto` did not exist when this mission began. It now exists, is public, and carries a published beta.

| | |
|---|---|
| Release | [`v0.1.0-beta.1`](https://github.com/intrusive-memory/SwiftReparto/releases/tag/v0.1.0-beta.1), prerelease, one asset: `reparto-0.1.0-beta.1-arm64-macos.tar.gz` |
| Tag / `main` / `development` | all at `8f87f3d` |
| Tests | **241**, green on macOS **and** iOS Simulator, verified in CI on PR #5 |
| Products | `SwiftReparto` (library) + `reparto` (executable) |
| Dependencies | exactly two — Yams 6.2.2, swift-argument-parser 1.8.2 |
| CI gates | `Test on macOS`, `Test on iOS Simulator` (both required), `Lint`, `Release Binary` |
| Guard scripts | `check-leaf-invariant.sh` (gating), `check-public-docs.sh` (advisory) |

**One deliverable did not land: the `collection.json` entry.** See §7. It is deferred by design, not dropped.

---

## 2. Sortie accounting

**22 planned sorties, 6 inserted, 1 continuation — 29 sortie dispatches.** Every one completed; none reached FATAL, none exhausted its retries, and the attempt counter never went past 1.

The six insertions are the interesting number, because each closed a defect the plan could not have known about:

| Inserted | Why |
|---|---|
| **5a** | `AnyCodable` could not decode a bare `null` — and `[String: AnyCodable]` is exactly the type D-8 specifies for `extraKeys`. In YAML a bare `bio:` *is* null, so RQ-4 and D-3 were both broken on ordinary input. |
| **8a** | `AnyCodable.encode(to:)` emitted nested mappings in Swift `Dictionary` order, which is **seeded per process**. Stable within one run, unstable across two. D-3 makes a nested `appearance:` block the *designed* case, so RQ-11's SHA-256 gate would have flaked. |
| **8b** | AR-2's stated mechanism was half wrong. Unquoted `no`/`yes`/`on`/`off` under undeclared keys decoded as `Bool`, breaking RQ-4's verbatim promise. *(User decision: adopt YAML 1.2 core semantics.)* |
| **9a** | The same class in numbers, by a **different** mechanism 8b could not reach — and `0755` → `493` was a silent **value** mutation, not a type change. *(User decision: finish the 1.2 commitment.)* |
| **10a** | `voices` was the one dictionary left out of the ordering discipline — seven lines above the `extraKeys.keys.sorted()` loop that does it right. Sortie 10 measured three different orderings from three construction paths. |
| **12a** | Two front-matter scanners existed, because the parser's was `private static` and unreachable. Behaviorally identical — one edit away from silently diverging, with no gate able to see it. |

**Four of six were byte-stability or data-fidelity defects in the guarantee this package exists to provide.** None was in the plan. All were found by agents running the suite, which is the strongest argument in this brief for the deviation recorded in §6.

---

## 3. Hard discoveries

Facts that cost real effort and would cost it again:

1. **Swift's `Character` is a grapheme cluster, so `"\r\n"` is one Character.** A line scanner over the `Character` view walks past the end of every CRLF line and `hasSuffix("\r")` never fires — silently, on exactly the input RQ-8 cares most about. The body split runs over UTF-8 bytes for this reason.
2. **Yams' `nestedContainer` commits its key into the parent mapping on `deinit`, not on creation.** A bare top-level `var` container compiles, looks correct, and silently reorders keys relative to sibling writes. Scope it in a `do { }` block. (Sortie 10a lost a cycle to this; the *existing* tests caught it.)
3. **`JSONEncoder` on this toolchain does not preserve keyed-container call order without `.sortedKeys`.** Any assertion about key order that inspects `JSONEncoder` output will lie. The SHA-256 gate rests on **Yams** preserving emission order under `sortKeys = false`, not on any general `Codable` guarantee.
4. **`ParsableCommand` already vends static `message(for:)` and `exitCode(for:)`.** A free function with either name silently resolves to the protocol member — member lookup beats file-scope lookup — producing type errors, not a redeclaration error.
5. **`.inf` / `.nan` / `1e400` were not lossy — they were fatal.** `JSONEncoder` refuses non-finite doubles and `AnyCodable.init(from:)` did not guard the `try`, so a *legal* YAML document was unreadable. Nobody had tested those spellings; Sortie 9a fixed it incidentally.
6. **`gh api .../releases/latest` excludes prereleases**, which is the single root cause behind both deferred items (§7).
7. **`gh` writes its 404 error body to stdout**, so `tag=$(gh api ... 2>/dev/null || true)` yields an error blob rather than an empty string — defeating an `-z` guard in the shared `update-package-library` skill. Outcome is still safe (exit 1, no write), but the diagnosis printed is wrong, and this affects all 17 tracked packages.

---

## 4. Process lessons — the headline finding

**Seven encounters with one defect species: a string match standing in for a semantic property.**

| Sortie | The check | What it could not distinguish |
|---|---|---|
| 1a | `grep` for `swift build` / `OS=latest` in the Makefile | a recipe from a comment *banning* that recipe |
| 2 | `grep -c 'No CLI target'` returns 0 | a document whose intro still said "No CLI" |
| 5 | "preserve the MIT header" | a source file that never had one |
| 13 | no `schemaVersion` in the legacy fixture | prose *about* having no schemaVersion |
| 15 | absence of `throws: Error.self` | whether anything specific was asserted at all |
| 17 | `importCast(content:)` absent | a doc comment explaining why it is avoided |
| 19a | (the doc-coverage script's own `public` scan) | `public` inside a comment or string literal |

**Four bit during execution** (1a, 2, 13, 17), **one was caught before dispatch** (5, where the instruction was literally unsatisfiable), and **two were preempted** by supervisor directives (15, 19a). Sortie 2 is the worst case: **all ten of its exit criteria passed against a document that contradicted itself**, and only a semantic read caught it.

Three consequences worth carrying to the next plan:

- **A criterion that greps a whole file cannot express "this property holds."** It expresses "this spelling is absent." Twice, the fix was to *reword prose* so a grep would pass — the check shaped the artifact instead of measuring it.
- **Scope the match.** `grep` recipes, not comments; grep the front-matter block, not the file; assert on typed values (`XCTAssertEqual(error, .missingCharacter(index: 0))`), not on absence of a string.
- **Pair every string-match criterion with a semantic one.** Where this mission did that — Sortie 15's payload-bearing equality, Sortie 16's `swift package dump-package` instead of a manifest grep — no defect got through.

Second process lesson: **verification sorties must be forbidden from fixing the thing they verify.** Sortie 14 was asked directly whether any criterion failed before going green. None had, and nothing was weakened. That question should be standard in the report format, because "all criteria pass" and "all criteria passed on the first run" are very different claims.

---

## 5. Plan accuracy

The plan was unusually good: 13 recorded decisions, 5 named risks, zero open questions at start, and a dependency structure that never needed reordering. Layers gated cleanly; no sortie was dispatched out of order.

Where it was wrong, it was wrong in small, specific ways:

- **Sortie 5** told an agent to "preserve the MIT header" of a file that has none.
- **Sortie 12** told an agent to reuse a `private static` function from another file.
- **Sortie 19** described a house convention (`CLAUDE.md` symlinking) that the two named reference repos **do not share** — SwiftProyecto symlinks, SwiftEscribo hand-writes distinct files.
- **Sortie 19a**'s stated rationale for its guard placement inverted Sortie 16's actual reasoning. The placement is right; the justification would mislead anyone who followed it elsewhere.
- **`.gitignore` `./bin/`** — git does not honor a leading `./` in ignore patterns.
- **AR-2's mechanism** was half wrong, and the half that was wrong is the half that mattered.

None of these was expensive. All were caught by an agent executing the instruction rather than reading it.

---

## 6. Supervisor decisions worth reviewing

Thirteen decisions were logged (`D-SUP-1` … `D-SUP-13`). Three deserve a second look:

- **D-SUP-12 — the plan's Parallel Group 1 was not used.** Sorties 11 and 12 ran sequentially with build authority instead of concurrently with none. Justified by the plan's own sentence — *"the binding constraint is not the dependency graph, it is the working tree"* — and by the fact that four of six inserted sorties exist **because an agent could run the suite**. A sub-agent that cannot build cannot verify its own exit criteria. I would make this call again.
- **D-SUP-10 — the number rule shipped is stricter than YAML 1.2 core.** The user approved "integers follow 1.2 core"; what shipped is "a scalar becomes a number only when that is lossless in spelling," which I widened, and which I also extended to floats unprompted. It is more RQ-4-faithful and less dialect-conformant. **This library is not a strict YAML 1.2 reader — it is a verbatim-preserving reader that agrees with 1.2 where the two do not conflict**, and `AGENTS.md` says so.
- **D-SUP-1 — no mission branch, no rollback point.** `pkg/` is gitignored by the enclosing repo, so a supervisor mission branch would have branched the wrong repository. Correct, but it means this mission never had an undo (see §8).

---

## 7. Open items

1. **`collection.json` registration — the one undelivered task.** `update-package-library` resolves versions through `repos/<repo>/releases/latest`, which excludes prereleases, so it 404s on a repo whose only release is a beta. Sortie 20 **stopped**, as AR-3 instructs, and did not hand-edit the JSON or promote the tag. `collection.json` is byte-identical to its pre-run state at revision 24. **Register at the first stable release.**
2. **Homebrew formula — deferred, same root cause.** The tap's `reconcile-formulas.sh` iterates `Formula/*.rb` (so it never discovers a repo with no formula) and resolves via `releases/latest` (so it ignores prereleases). Create the formula by hand at first stable. **The beta now has two deferrals with one cause — state it once, prominently, when someone cuts `v0.1.0`.**
3. **`update-package-library`'s 404 diagnostic is wrong** (§3.7). Affects all 17 tracked packages. Deliberately not fixed inside a terminal release sortie; belongs in its own reviewed change.
4. **`AGENTS.md`'s Release section says "plus its SHA-256,"** which reads as a second asset. The workflow computes the hash into the step summary instead. One-line doc correction.
5. **`REQUIREMENTS.md`'s status callout enumerates a file inventory** that was accurate when Sortie 2 wrote it and is now stale. Left alone deliberately; the file is the human's.
6. **`Lint` is green but does not gate.** Branch protection requires only the two test contexts, so `swift format` and the doc-coverage check cannot block a merge. Deliberate for doc coverage; worth a decision for lint.
7. **`gh release view` without an explicit tag reports "release not found"** on this repo for the whole beta line — same `releases/latest` cause. Any health check that omits the tag will report SwiftReparto as unreleased.

---

## 8. Rollback verdict

### `KEEP`

**Justification.** Every acceptance criterion in `REQUIREMENTS.md` §8 is proven by a test against a pinned fixture. The 241-test suite passed CI on both destinations as a unit, first attempt, no retries, no admin bypass. The leaf invariant was observed **failing** on a deliberate violation before being trusted. The release workflow succeeded on its first-ever run. The shipped binary links nothing from `DerivedData`. Four data-fidelity defects that would have surfaced as intermittent corruption were found and fixed before the fixtures that would have hidden them were pinned.

**The honest caveat about what this verdict even means here.** Per D-SUP-1, **this mission has no rollback point.** The SwiftReparto repository is itself the deliverable; there is no pre-mission commit to reset to. `ROLLBACK` would have meant deleting the working directory, the GitHub repository, the published release, and the SwiftEscribo issue — not `git reset`. A verdict of KEEP here is therefore weaker evidence than it would be on a mission that could have been undone, and it should be read as *"the work is sound"* rather than *"the alternative was carefully weighed."*

**What would have justified `PARTIAL_SALVAGE`** and did not occur: a failing acceptance gate, a test weakened to pass, a library change made to satisfy a verification sortie, or a hand-uploaded release asset making an unproven workflow look proven. Each was an explicit stop condition; none fired.

**The one incomplete deliverable does not change the verdict.** The `collection.json` entry is blocked by a documented, reproducible external constraint that the plan anticipated (AR-3) and defined handling for. The sortie followed that handling exactly, and preserved the answer instead of working around it.
