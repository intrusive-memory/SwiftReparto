# Graph Report - .  (2026-08-02)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 671 nodes · 1325 edges · 30 communities (26 shown, 4 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 148 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d63064d7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Encoding Container Primitives|Encoding Container Primitives]]
- [[_COMMUNITY_CLI Import Command Tests|CLI Import Command Tests]]
- [[_COMMUNITY_Markdown Parser Body Tests|Markdown Parser Body Tests]]
- [[_COMMUNITY_Cast Member Coding Tests|Cast Member Coding Tests]]
- [[_COMMUNITY_Project Docs and Conventions|Project Docs and Conventions]]
- [[_COMMUNITY_Round-Trip Test Corpus|Round-Trip Test Corpus]]
- [[_COMMUNITY_Project Cast Importer|Project Cast Importer]]
- [[_COMMUNITY_YAML Dialect Coding|YAML Dialect Coding]]
- [[_COMMUNITY_Cast Document Tests|Cast Document Tests]]
- [[_COMMUNITY_Acceptance Gate Fixtures|Acceptance Gate Fixtures]]
- [[_COMMUNITY_Cast Markdown Parser|Cast Markdown Parser]]
- [[_COMMUNITY_Cast Member Identity|Cast Member Identity]]
- [[_COMMUNITY_Cast Document Model|Cast Document Model]]
- [[_COMMUNITY_Rejection Fixture Tests|Rejection Fixture Tests]]
- [[_COMMUNITY_AnyCodable Wrapper|AnyCodable Wrapper]]
- [[_COMMUNITY_Parse Error Tests|Parse Error Tests]]
- [[_COMMUNITY_Gender Enum|Gender Enum]]
- [[_COMMUNITY_Fixture Integrity Tests|Fixture Integrity Tests]]
- [[_COMMUNITY_Console Output Sink|Console Output Sink]]
- [[_COMMUNITY_Cast Parse Errors|Cast Parse Errors]]
- [[_COMMUNITY_Cast Member Merging|Cast Member Merging]]
- [[_COMMUNITY_Schema Version Handling|Schema Version Handling]]
- [[_COMMUNITY_Cast Member Coding Keys|Cast Member Coding Keys]]
- [[_COMMUNITY_Import Guard Exit Mapping|Import Guard Exit Mapping]]
- [[_COMMUNITY_Leaf Invariant Check Script|Leaf Invariant Check Script]]
- [[_COMMUNITY_Reparto Version Constant|Reparto Version Constant]]
- [[_COMMUNITY_Public Docs Check Script|Public Docs Check Script]]

## God Nodes (most connected - your core abstractions)
1. `CastMarkdownParserTests` - 47 edges
2. `RoundTripTests` - 39 edges
3. `CastDocumentTests` - 36 edges
4. `ProjectCastImporter` - 30 edges
5. `YAMLCodingTests` - 30 edges
6. `encodeYAML()` - 28 edges
7. `ProjectCastImportTests` - 27 edges
8. `decodeYAML()` - 25 edges
9. `Data` - 23 edges
10. `CLITests` - 22 edges

## Surprising Connections (you probably didn't know these)
- `intrusive-memory/homebrew-tap` --conceptually_related_to--> `Release Binary Workflow`  [INFERRED]
  AGENTS.md → .github/workflows/release.yml
- `Release Binary Workflow` --conceptually_related_to--> `RepartoVersion.current`  [INFERRED]
  .github/workflows/release.yml → AGENTS.md
- `SwiftEscribo (third cast-model copy)` --semantically_similar_to--> `CastMember`  [EXTRACTED] [semantically similar]
  CHANGELOG.md → AGENTS.md
- `Fixture: legacy-unversioned-CAST.md` --conceptually_related_to--> `CastMember`  [INFERRED]
  Tests/SwiftRepartoTests/Fixtures/legacy-unversioned-CAST.md → AGENTS.md
- `Fixture: all-fields-CAST.md` --cites--> `OPERATION TROUPE MARSHAL Execution Plan`  [AMBIGUOUS]
  Tests/SwiftRepartoTests/Fixtures/all-fields-CAST.md → docs/complete/operation-troupe-marshal/EXECUTION_PLAN.md

## Import Cycles
- None detected.

## Communities (30 total, 4 thin omitted)

### Community 0 - "Encoding Container Primitives"
Cohesion: 0.08
Nodes (34): CodingKey, CodingUserInfoKey, Data, Double, Encoder, Float, Int16, Int64 (+26 more)

### Community 1 - "CLI Import Command Tests"
Cohesion: 0.06
Nodes (32): OutputSink, ParsableCommand, errorMessage(), RepartoExitCode, CodingKeys, dryRun, force, output (+24 more)

### Community 2 - "Markdown Parser Body Tests"
Cohesion: 0.08
Nodes (7): CastMarkdownParserTests, CastDocument, CastParseError, StaticString, String, UInt, URL

### Community 3 - "Cast Member Coding Tests"
Cohesion: 0.08
Nodes (12): voices, CastMemberCodingTests, CastMemberPublicAPITests, MergeTests, Any, CastMember, String, AnyCodable (+4 more)

### Community 4 - "Project Docs and Conventions"
Cohesion: 0.06
Nodes (50): AGENTS.md — Agent Instructions, AnyCodable (vendored), CAST.md (owned schema/file), CastDocument, CastMarkdownParser, CastMember, CastParseError, CastSchemaVersion (+42 more)

### Community 5 - "Round-Trip Test Corpus"
Cohesion: 0.12
Nodes (4): RoundTripTests, CastDocument, String, URL

### Community 6 - "Project Cast Importer"
Cohesion: 0.08
Nodes (11): Decodable, CastMember, Decoder, DecodingError, Error, Int, ProjectCastBlock, ProjectCastImporter (+3 more)

### Community 7 - "YAML Dialect Coding"
Cohesion: 0.15
Nodes (10): Node, String, decodeYAML(), encodeYAML(), narrowingPlainScalarsToReadDialect(), StringProbe, YAMLCodingTests, CastMember (+2 more)

### Community 8 - "Cast Document Tests"
Cohesion: 0.09
Nodes (4): CastDocumentTests, Any, CastDocument, String

### Community 9 - "Acceptance Gate Fixtures"
Cohesion: 0.07
Nodes (22): CustomStringConvertible, Error, String, AcceptanceGateTests, FrontMatterSliceError, TestFixture, allFieldsCastMD, confessionsCastMD (+14 more)

### Community 10 - "Cast Markdown Parser"
Cohesion: 0.16
Nodes (21): Range, Bool, CastDocument, Error, Int, String, UInt8, URL (+13 more)

### Community 11 - "Cast Member Identity"
Cohesion: 0.18
Nodes (11): Hasher, Identifiable, AnyCodable, Bool, Decoder, Encoder, Gender, Int (+3 more)

### Community 12 - "Cast Document Model"
Cohesion: 0.16
Nodes (13): Bool, CastMember, Decoder, DecodingError, Encoder, Error, Int, String (+5 more)

### Community 13 - "Rejection Fixture Tests"
Cohesion: 0.19
Nodes (5): RejectionFixtureTests, TestFixture, CastParseError, StaticString, UInt

### Community 14 - "AnyCodable Wrapper"
Cohesion: 0.24
Nodes (8): Bool, Decoder, Encoder, Int, String, T, AnyCodable, DynamicCodingKey

### Community 16 - "Gender Enum"
Cohesion: 0.18
Nodes (10): CaseIterable, Codable, Equatable, Hashable, Gender, female, male, nonBinary (+2 more)

### Community 18 - "Console Output Sink"
Cohesion: 0.28
Nodes (5): ConsoleOutputSink, OutputSink, Sendable, Int32, String

### Community 19 - "Cast Parse Errors"
Cohesion: 0.22
Nodes (8): String, CastParseError, invalidYAML, missingCastKey, missingCharacter, missingTypeCast, noFrontMatter, unsupportedSchemaVersion

### Community 20 - "Cast Member Merging"
Cohesion: 0.32
Nodes (5): CastMember, String, Array, CastMember, normalizedCastMemberMatchKey()

### Community 21 - "Schema Version Handling"
Cohesion: 0.43
Nodes (4): Bool, Int, String, CastSchemaVersion

### Community 22 - "Cast Member Coding Keys"
Cohesion: 0.25
Nodes (7): CodingKeys, actor, character, gender, language, legacyVoiceDescription, voicePrompt

### Community 23 - "Import Guard Exit Mapping"
Cohesion: 0.33
Nodes (5): LocalizedError, ImportGuardError, outputDirectoryMismatch, outputExists, String

### Community 24 - "Leaf Invariant Check Script"
Cohesion: 0.83
Nodes (3): fail(), ok(), check-leaf-invariant.sh script

## Ambiguous Edges - Review These
- `Fixture: all-fields-CAST.md` → `OPERATION TROUPE MARSHAL Execution Plan`  [AMBIGUOUS]
  Tests/SwiftRepartoTests/Fixtures/all-fields-CAST.md · relation: cites

## Knowledge Gaps
- **99 isolated node(s):** `Int32`, `outputExists`, `outputDirectoryMismatch`, `projectPath`, `output` (+94 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Fixture: all-fields-CAST.md` and `OPERATION TROUPE MARSHAL Execution Plan`?**
  _Edge tagged AMBIGUOUS (relation: cites) - confidence is low._
- **Why does `Data` connect `Encoding Container Primitives` to `Markdown Parser Body Tests`, `Cast Member Coding Tests`, `Round-Trip Test Corpus`, `Project Cast Importer`, `Cast Document Tests`, `Acceptance Gate Fixtures`, `AnyCodable Wrapper`, `Fixture Integrity Tests`, `Console Output Sink`?**
  _High betweenness centrality (0.143) - this node is a cross-community bridge._
- **Why does `CastMarkdownParserTests` connect `Markdown Parser Body Tests` to `Cast Member Coding Tests`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Why does `AnyCodable` connect `AnyCodable Wrapper` to `Gender Enum`, `Encoding Container Primitives`, `Console Output Sink`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Are the 26 inferred relationships involving `ProjectCastImporter` (e.g. with `.run()` and `.testImportedFrontMatterMatchesThePinnedCastFixturesFrontMatter()`) actually correct?**
  _`ProjectCastImporter` has 26 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Int32`, `outputExists`, `outputDirectoryMismatch` to the rest of the system?**
  _100 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Encoding Container Primitives` be split into smaller, more focused modules?**
  _Cohesion score 0.07950310559006211 - nodes in this community are weakly interconnected._