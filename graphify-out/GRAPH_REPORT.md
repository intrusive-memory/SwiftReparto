# Graph Report - .  (2026-11-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 975 nodes · 1928 edges · 54 communities (48 shown, 6 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 219 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `046ad4a2`
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
- [[_COMMUNITY_Package Manifest|Package Manifest]]
- [[_COMMUNITY_CLI Entry Point|CLI Entry Point]]
- [[_COMMUNITY_Library Root File|Library Root File]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]

## God Nodes (most connected - your core abstractions)
1. `CastMarkdownParserTests` - 47 edges
2. `RoundTripTests` - 39 edges
3. `CastDocumentTests` - 36 edges
4. `ProjectCastImporter` - 33 edges
5. `CapturingSink` - 32 edges
6. `RoleManifestTests` - 32 edges
7. `LineCountCastVersionTests` - 31 edges
8. `YAMLCodingTests` - 30 edges
9. `encodeYAML()` - 28 edges
10. `ProjectCastImportTests` - 27 edges

## Surprising Connections (you probably didn't know these)
- `reject-invalid-role.md fixture` --references--> `CastParseError`  [INFERRED]
  Tests/SwiftRepartoTests/Fixtures/reject-invalid-role.md → AGENTS.md
- `Fixture: reject-future-version.md` --conceptually_related_to--> `CastSchemaVersion`  [INFERRED]
  Tests/SwiftRepartoTests/Fixtures/reject-future-version.md → AGENTS.md
- `Tests Workflow` --references--> `Fixture: confessions-CAST.md`  [EXTRACTED]
  .github/workflows/tests.yml → Tests/SwiftRepartoTests/Fixtures/confessions-CAST.md
- `SwiftEscribo (third cast-model copy)` --semantically_similar_to--> `CastMember`  [EXTRACTED] [semantically similar]
  CHANGELOG.md → AGENTS.md
- `Fixture: all-fields-CAST.md` --conceptually_related_to--> `CastMember`  [INFERRED]
  Tests/SwiftRepartoTests/Fixtures/all-fields-CAST.md → AGENTS.md

## Import Cycles
- None detected.

## Communities (54 total, 6 thin omitted)

### Community 0 - "Encoding Container Primitives"
Cohesion: 0.08
Nodes (36): Codable, CodingKey, CodingUserInfoKey, Data, Double, Encoder, Float, Int16 (+28 more)

### Community 1 - "CLI Import Command Tests"
Cohesion: 0.07
Nodes (18): AnyCodable, Node, String, decodeYAML(), encodeYAML(), narrowingPlainScalarsToReadDialect(), CastMemberPublicAPITests, MergeTests (+10 more)

### Community 2 - "Markdown Parser Body Tests"
Cohesion: 0.08
Nodes (7): CastMarkdownParserTests, CastDocument, CastParseError, StaticString, String, UInt, URL

### Community 3 - "Cast Member Coding Tests"
Cohesion: 0.06
Nodes (7): LineCountCastVersionTests, RejectionFixtureTests, TestFixture, String, CastParseError, StaticString, UInt

### Community 4 - "Project Docs and Conventions"
Cohesion: 0.08
Nodes (6): ProjectCastImporter, FixtureIntegrityTests, ProjectCastImportTests, String, String, URL

### Community 5 - "Round-Trip Test Corpus"
Cohesion: 0.12
Nodes (4): RoundTripTests, CastDocument, String, URL

### Community 6 - "Project Cast Importer"
Cohesion: 0.09
Nodes (4): CastDocumentTests, Any, CastDocument, String

### Community 7 - "YAML Dialect Coding"
Cohesion: 0.09
Nodes (6): RoleManifestTests, CastDocument, Int, Range, String, URL

### Community 8 - "Cast Document Tests"
Cohesion: 0.10
Nodes (30): Decodable, Range, Bool, CastDocument, Error, Int, Range, String (+22 more)

### Community 9 - "Acceptance Gate Fixtures"
Cohesion: 0.10
Nodes (29): AnyCodable (vendored), CastMember.canonicalName(_:), CastMember, CastRole enum, CharacterNameError, CastMember.extraKeys (D-8), [CastMember].merging(_:), reparto validate (+21 more)

### Community 10 - "Cast Markdown Parser"
Cohesion: 0.25
Nodes (5): OutputSink, CanonicalizeCLITests, CapturingSink, String, URL

### Community 11 - "Cast Member Identity"
Cohesion: 0.18
Nodes (7): errorMessage(), ImportCommand, Bool, OutputSink, String, CLITests, URL

### Community 12 - "Cast Document Model"
Cohesion: 0.17
Nodes (14): CastRole, Gender, Hasher, Identifiable, AnyCodable, Bool, Decoder, Encoder (+6 more)

### Community 13 - "Rejection Fixture Tests"
Cohesion: 0.21
Nodes (5): Any, CastMemberCodingTests, Any, CastMember, String

### Community 14 - "AnyCodable Wrapper"
Cohesion: 0.16
Nodes (15): Branch topology (mission → development → main), check-leaf-invariant.sh, intrusive-memory/homebrew-tap, Makefile Build Interface, RepartoVersion.current, check-public-docs.sh, Lint Workflow, CI Workflows README (+7 more)

### Community 16 - "Gender Enum"
Cohesion: 0.19
Nodes (9): CodingKeys, model, similarityBoost, stability, ElevenLabsCastFieldsRoundTripTests, ElevenLabsSettings, CastDocument, String (+1 more)

### Community 17 - "Fixture Integrity Tests"
Cohesion: 0.12
Nodes (18): CastParseError, Release 0.4.0, linecount-castversion-CAST.md fixture, Fixture: reject-cast-only.md, Fixture: reject-future-version.md, reject-invalid-linecount.md fixture, Fixture: reject-malformed-yaml.md, Fixture: reject-missing-character.md (+10 more)

### Community 18 - "Console Output Sink"
Cohesion: 0.15
Nodes (14): Bool, CastMember, Decoder, DecodingError, Encoder, Error, Int, String (+6 more)

### Community 19 - "Cast Parse Errors"
Cohesion: 0.11
Nodes (18): TestFixture, allFieldsCastMD, confessionsCastMD, confessionsProjectMD, elevenLabsVoicesCastMD, legacyUnversionedCastMD, lineCountCastVersionCastMD, preRoleManifestCastMD (+10 more)

### Community 20 - "Cast Member Merging"
Cohesion: 0.25
Nodes (13): CharacterNameError, Equatable, LocalizedError, CanonicalizationError, collision, CanonicalizationPlan, Collision, Failure (+5 more)

### Community 21 - "Schema Version Handling"
Cohesion: 0.21
Nodes (4): AcceptanceGateTests, FrontMatterSliceError, String, URL

### Community 23 - "Import Guard Exit Mapping"
Cohesion: 0.22
Nodes (15): CAST.md (owned schema/file), CastDocument, CastMarkdownParser, CastSchemaVersion, First write is a normalizing write, Produciesta (consumer), RQ-INV-2 One Writer, SwiftEchada (consumer) (+7 more)

### Community 24 - "Leaf Invariant Check Script"
Cohesion: 0.13
Nodes (3): CastParseError, CastParseErrorTests, CastParseError

### Community 25 - "Reparto Version Constant"
Cohesion: 0.21
Nodes (9): ParsableCommand, CanonicalizeCommand, CodingKeys, apply, path, RepartoCommand, Bool, OutputSink (+1 more)

### Community 26 - "Public Docs Check Script"
Cohesion: 0.17
Nodes (6): RepartoExitCode, directoryPath(), Int32, URL, Int32, Void

### Community 27 - "Package Manifest"
Cohesion: 0.24
Nodes (8): Bool, Decoder, Encoder, Int, String, T, AnyCodable, DynamicCodingKey

### Community 28 - "CLI Entry Point"
Cohesion: 0.24
Nodes (12): AGENTS.md — Agent Instructions, Fixture: all-fields-CAST.md, SwiftReparto Changelog, CLAUDE.md (symlink to AGENTS.md), Fixture: confessions-CAST.md, OPERATION TROUPE MARSHAL Execution Plan, GEMINI.md (symlink to AGENTS.md), OPERATION TROUPE MARSHAL Mission Brief (+4 more)

### Community 29 - "Library Root File"
Cohesion: 0.21
Nodes (11): Error, KeyedDecodingContainer, DecodingError, decodeNonNegativeInteger(), InvalidLineCountValue, InvalidRoleValue, NonNegativeIntegerField, absent (+3 more)

### Community 30 - "Community 30"
Cohesion: 0.26
Nodes (9): CodingKeys, path, quiet, ValidateCommand, validationWarnings(), Bool, CastDocument, OutputSink (+1 more)

### Community 31 - "Community 31"
Cohesion: 0.17
Nodes (11): String, CastParseError, invalidCastVersion, invalidLineCount, invalidRole, invalidYAML, missingCastKey, missingCharacter (+3 more)

### Community 32 - "Community 32"
Cohesion: 0.29
Nodes (8): Bool, String, Substring, CastMember, CharacterNameError, empty, forbiddenCharacter, leadingDot

### Community 33 - "Community 33"
Cohesion: 0.18
Nodes (9): Bool, CastRole, background, costar, guest, lead, narrator, supporting (+1 more)

### Community 34 - "Community 34"
Cohesion: 0.18
Nodes (11): CodingKeys, actor, character, displayName, gender, language, legacyVoiceDescription, lineCount (+3 more)

### Community 35 - "Community 35"
Cohesion: 0.24
Nodes (9): ExitMapping / RepartoExitCode, ProjectCastImporter, reparto canonicalize [--apply], reparto CLI Executable, reparto import, RepartoExitCode / ExitMapping.swift, RQ-INV-3 No Inference (D-4), Release 0.1.0 (first stable) (+1 more)

### Community 36 - "Community 36"
Cohesion: 0.20
Nodes (9): SwiftPersonaje / SwiftDossier (consumer), A-26 SwiftDossier links Reparto (unverifiable), RECON_REPORT.md (Personaje recon), Granville CAST.md revision ambiguity, REQUIREMENTS.md (0.2.0 character record), dossier-format DOSSIER-FORMAT.md, docs/complete/operation-troupe-marshal/REQUIREMENTS.md (0.1.0 spec), voices.voxalta two-owner collision (EC-23) (+1 more)

### Community 37 - "Community 37"
Cohesion: 0.28
Nodes (5): Sendable, CastDocument, String, URL, CastMarkdownParser

### Community 38 - "Community 38"
Cohesion: 0.31
Nodes (6): CastMember, String, Array, CastMember, legacyCastMemberMatchKey(), normalizedCastMemberMatchKey()

### Community 39 - "Community 39"
Cohesion: 0.29
Nodes (8): scripts/check-leaf-invariant.sh, PROJECT.md (external file), RepartoCLICore Target, RQ-INV-1 Leaf Invariant, swift-argument-parser, SwiftProyecto (non-consumer), SwiftReparto Library, Yams (YAML dependency)

### Community 40 - "Community 40"
Cohesion: 0.25
Nodes (7): CaseIterable, Hashable, Gender, female, male, nonBinary, notSpecified

### Community 41 - "Community 41"
Cohesion: 0.29
Nodes (5): CustomStringConvertible, String, TestFixtureError, notFound, URL

### Community 42 - "Community 42"
Cohesion: 0.32
Nodes (4): ConsoleOutputSink, OutputSink, Int32, String

### Community 43 - "Community 43"
Cohesion: 0.43
Nodes (4): Bool, Int, String, CastSchemaVersion

### Community 44 - "Community 44"
Cohesion: 0.33
Nodes (5): CodingKeys, dryRun, force, output, projectPath

### Community 45 - "Community 45"
Cohesion: 0.40
Nodes (4): ImportGuardError, outputDirectoryMismatch, outputExists, String

### Community 46 - "Community 46"
Cohesion: 0.83
Nodes (3): fail(), ok(), check-leaf-invariant.sh script

## Ambiguous Edges - Review These
- `Fixture: all-fields-CAST.md` → `OPERATION TROUPE MARSHAL Execution Plan`  [AMBIGUOUS]
  Tests/SwiftRepartoTests/Fixtures/all-fields-CAST.md · relation: cites
- `SwiftPersonaje / SwiftDossier (consumer)` → `A-26 SwiftDossier links Reparto (unverifiable)`  [AMBIGUOUS]
  RECON_REPORT.md · relation: conceptually_related_to

## Knowledge Gaps
- **145 isolated node(s):** `Int32`, `outputExists`, `outputDirectoryMismatch`, `projectPath`, `output` (+140 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Fixture: all-fields-CAST.md` and `OPERATION TROUPE MARSHAL Execution Plan`?**
  _Edge tagged AMBIGUOUS (relation: cites) - confidence is low._
- **What is the exact relationship between `SwiftPersonaje / SwiftDossier (consumer)` and `A-26 SwiftDossier links Reparto (unverifiable)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Data` connect `Encoding Container Primitives` to `CLI Import Command Tests`, `Markdown Parser Body Tests`, `Project Docs and Conventions`, `Round-Trip Test Corpus`, `Project Cast Importer`, `Community 42`, `Rejection Fixture Tests`, `Schema Version Handling`, `Package Manifest`?**
  _High betweenness centrality (0.087) - this node is a cross-community bridge._
- **Why does `CastMarkdownParserTests` connect `Markdown Parser Body Tests` to `CLI Import Command Tests`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Why does `AnyCodable` connect `Package Manifest` to `Encoding Container Primitives`, `Cast Member Merging`, `Community 37`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Are the 29 inferred relationships involving `ProjectCastImporter` (e.g. with `.run()` and `.testImportedFrontMatterMatchesThePinnedCastFixturesFrontMatter()`) actually correct?**
  _`ProjectCastImporter` has 29 INFERRED edges - model-reasoned connections that need verification._
- **Are the 15 inferred relationships involving `CapturingSink` (e.g. with `.testCanonicalizeApplyNormalizesEvenWithNoRenames()` and `.testCanonicalizeApplyRenamesAndWrites()`) actually correct?**
  _`CapturingSink` has 15 INFERRED edges - model-reasoned connections that need verification._