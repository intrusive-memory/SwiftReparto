// YAMLCodingTests.swift
// SwiftRepartoTests
//
// Sortie 8 tests for the YAML coding layer. This file replaces
// `PackageSmokeTests.swift`, which existed only to prove Yams builds and
// round-trips under this package's floor (AR-1); every assertion it made is
// subsumed here by a real encode/decode round trip through `YAMLCoding.swift`.
//
// The subject under test is a *configuration*, not an algorithm. Yams supplies
// the parser and the emitter; what this sortie owns is the set of emitter
// options, and every option that is wrong in a way that survives casual
// inspection has a test here:
//
//   * `width` folding a long line          -> testLongProseEmitsOnExactlyOneLine
//   * key sorting reordering the front matter -> testFrontMatterKeyOrderIsFixed
//   * dictionary iteration order leaking      -> testExtraKeysEmitInLexicographicOrder
//   * YAML 1.1 booleans eating `language: no` -> testLanguageNoDecodesAsString
//
// These go through `encodeYAML`/`decodeYAML` rather than `YAMLEncoder`
// directly, because an assertion that bypassed the wrapper would pass while
// the shipping configuration was broken.

import Foundation
import XCTest

@testable import SwiftReparto

final class YAMLCodingTests: XCTestCase {

  // MARK: - Fixtures

  /// A one-field carrier so a hostile string can be tested as a YAML *value*
  /// with nothing else in the document to explain a failure.
  private struct StringProbe: Codable, Equatable {
    var text: String
  }

  /// Every string that YAML 1.1, libyaml's plain-scalar rules, or a careless
  /// emitter configuration could mangle.
  ///
  /// The name in each pair is what shows up in a failure message, which is the
  /// entire reason this is a list of pairs and not a list of strings.
  private static let hostileStrings: [(name: String, value: String)] = [
    ("colon-space", "TIME: it is 12:30, and the room is quiet"),
    ("leading-dash", "- not a sequence entry"),
    ("leading-hash", "#not a comment"),
    ("leading-percent", "%not a directive"),
    ("literal-true", "true"),
    ("literal-no", "no"),
    ("literal-null", "null"),
    ("literal-tilde", "~"),
    ("literal-123", "123"),
    ("literal-1.0", "1.0"),
    ("empty", ""),
    ("padded", "  leading and trailing spaces  "),
    ("leading-asterisk", "*not an alias"),
    ("leading-ampersand", "&not an anchor"),
    ("trailing-hash", "a value # and something that is not a comment"),
    ("long-prose", YAMLCodingTests.longProse),
  ]

  /// ~400 characters of single-line prose, the shape of the real `bio:` note
  /// that undeclared-key preservation exists to carry.
  ///
  /// It is deliberately full of spaces: a line folder needs break
  /// opportunities, so a string without them would pass the one-line assertion
  /// for the wrong reason.
  private static let longProse: String = {
    let sentence =
      "The Practitioner speaks in a measured, unhurried baritone that never rises and never hurries, "
      + "as though every sentence had already been decided upon some time ago and is only now being "
      + "released into the room, one clause at a time, without apology and without haste. "
    var accumulated = ""
    while accumulated.count < 400 {
      accumulated += sentence
    }
    return String(accumulated.prefix(400))
  }()

  // MARK: - Helpers

  /// The keys of the emitted document's top-level mapping, in emission order.
  ///
  /// Column zero is the discriminator: nested mapping keys are indented and
  /// block-sequence entries begin with `-`, so neither is mistaken for a
  /// top-level key.
  private func topLevelKeys(of yaml: String) -> [String] {
    yaml.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
      guard let first = line.first, first.isLetter else { return nil }
      guard let colon = line.firstIndex(of: ":") else { return nil }
      return String(line[line.startIndex..<colon])
    }
  }

  private func makeMember(bio: String) throws -> CastMember {
    var member = CastMember(
      character: "THE PRACTITIONER",
      actor: "Tom Stovall",
      gender: .male,
      language: "en",
      voicePrompt: "A measured voice: unhurried, precise.",
      voices: ["voxalta": ["voices/practitioner.vox"]]
    )
    member.setExtra(try AnyCodable(bio), forKey: "bio")
    return member
  }

  /// Decodes a minimal member carrying `mood:` — an undeclared key — with the
  /// given raw YAML scalar text.
  ///
  /// The value is interpolated *unquoted* into the document so the caller
  /// controls whether the emitted scalar is plain or quoted; that distinction
  /// is the whole subject of the boolean tests below.
  private func decodeMemberWithMood(_ rawScalar: String) throws -> CastMember {
    try decodeYAML(
      CastMember.self,
      from: """
        character: THE PRACTITIONER
        mood: \(rawScalar)
        """)
  }

  // MARK: - Task 5: hostile inputs round-trip

  /// `decode(encode(x)) == x` for every hostile string, as a plain YAML value.
  func testHostileStringsRoundTripAsScalars() throws {
    for (name, value) in Self.hostileStrings {
      let original = StringProbe(text: value)
      let yaml = try encodeYAML(original)
      let decoded = try decodeYAML(StringProbe.self, from: yaml)

      XCTAssertEqual(
        decoded, original,
        "hostile string '\(name)' did not survive the round trip. Emitted:\n\(yaml)")
    }
  }

  /// The same strings, carried in an undeclared key through `AnyCodable`.
  ///
  /// This is the path that actually matters (RQ-4): a `bio:` note is not a
  /// declared field, so it is decoded without a destination type to steer it.
  /// A value that survives as a typed `String` can still be captured as an
  /// `Int` here, and that would be silent data loss rather than a crash.
  func testHostileStringsRoundTripThroughExtraKeys() throws {
    for (name, value) in Self.hostileStrings {
      let original = try makeMember(bio: value)
      let yaml = try encodeYAML(original)
      let decoded = try decodeYAML(CastMember.self, from: yaml)

      XCTAssertEqual(
        decoded, original,
        "hostile string '\(name)' did not survive the round trip as an undeclared key. "
          + "Emitted:\n\(yaml)")
      XCTAssertEqual(
        try XCTUnwrap(decoded[extra: "bio"]).decode(String.self), value,
        "hostile string '\(name)' decoded as something other than a String")
    }
  }

  /// A three-level nested mapping under an undeclared key.
  ///
  /// This is the `appearance:` block's shape (D-3) — the deferred field rides
  /// the undeclared-key path, and it is not flat.
  func testThreeLevelNestedMappingRoundTrips() throws {
    let nested: [String: [String: [String: String]]] = [
      "appearance": [
        "lora": [
          "path": "loras/practitioner.safetensors",
          "engine": "flux",
        ]
      ]
    ]

    var original = CastMember(character: "THE PRACTITIONER")
    original.setExtra(try AnyCodable(nested), forKey: "appearance")

    let yaml = try encodeYAML(original)
    let decoded = try decodeYAML(CastMember.self, from: yaml)

    XCTAssertEqual(decoded, original, "nested mapping did not survive the round trip:\n\(yaml)")

    let reconstructed = try XCTUnwrap(decoded[extra: "appearance"])
      .decode([String: [String: [String: String]]].self)
    XCTAssertEqual(reconstructed, nested)
  }

  // MARK: - Task 6: the `width` regression

  /// The direct regression test for `width`.
  ///
  /// Yams defaults `width` to 0, which libyaml reads as "best width" and which
  /// folds a ~400-character plain scalar across five or six lines. The value
  /// still round-trips — YAML folding is semantically lossless — so nothing
  /// below this assertion would notice. What breaks is byte identity, and the
  /// failure surfaces sortie later as a SHA-256 mismatch that reads like
  /// corruption.
  func testLongProseEmitsOnExactlyOneLine() throws {
    XCTAssertEqual(Self.longProse.count, 400, "fixture is not 400 characters")

    let yaml = try encodeYAML(StringProbe(text: Self.longProse))
    let newlineCount = yaml.filter { $0 == "\n" }.count

    XCTAssertEqual(
      newlineCount, 1,
      "the 400-character prose string was folded across lines — check `width`. Emitted:\n\(yaml)")
    XCTAssertTrue(
      yaml.contains(Self.longProse),
      "the 400-character prose string does not appear contiguously in the output:\n\(yaml)")
  }

  /// The same assertion on the shape that ships: a long `bio:` on a member.
  func testLongProseInAnExtraKeyEmitsOnExactlyOneLine() throws {
    let member = try makeMember(bio: Self.longProse)
    let yaml = try encodeYAML(member)

    let bioLines = yaml.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { $0.contains("The Practitioner speaks") }

    XCTAssertEqual(
      bioLines.count, 1,
      "the long `bio:` was folded across \(bioLines.count) lines. Emitted:\n\(yaml)")
    XCTAssertTrue(
      yaml.contains(Self.longProse),
      "the long `bio:` does not appear contiguously in the output:\n\(yaml)")
  }

  // MARK: - Determinism

  /// Encoding the same value repeatedly in one process is byte-identical.
  ///
  /// The fixture is chosen to be maximally hostile to this: several undeclared
  /// keys, a nested mapping, and a multi-provider `voices` map — every one of
  /// them backed by a Swift `Dictionary` whose iteration order is not part of
  /// its value.
  func testRepeatedEncodingIsByteIdentical() throws {
    var member = CastMember(
      character: "THE PRACTITIONER",
      actor: "Tom Stovall",
      gender: .male,
      language: "en",
      voicePrompt: "A measured voice: unhurried, precise.",
      voices: [
        "voxalta": ["voices/practitioner.vox"],
        "apple": ["com.apple.voice.premium.en-GB.Serena"],
        "elevenlabs": ["practitioner"],
      ]
    )
    for key in ["zeta", "bio", "mood", "appearance", "alpha", "notes"] {
      member.setExtra(try AnyCodable("value for \(key)"), forKey: key)
    }
    member.setExtra(try AnyCodable(["one": ["two": "three"]]), forKey: "nested")

    let document = CastDocument(cast: [member, CastMember(character: "NARRATOR")])
    let first = try encodeYAML(document)

    for iteration in 1...25 {
      XCTAssertEqual(
        try encodeYAML(document), first,
        "encode #\(iteration) differed from encode #0 — key order is not deterministic")
    }
  }

  /// Undeclared keys emit after the declared keys, in lexicographic order.
  ///
  /// This is the regression test for dictionary iteration order, and it is
  /// also the answer to an open question: `CastMember.encode(to:)` writes its
  /// declared keys through a `CodingKeys` container and its extras through a
  /// second, dynamic container obtained from the same `Encoder`. That the
  /// second container's keys land *after* the first container's, rather than
  /// interleaved or in place of them, is a property of the encoder — proven
  /// for `JSONEncoder` in Sortie 6 and proven for Yams right here.
  func testExtraKeysEmitInLexicographicOrder() throws {
    var member = CastMember(
      character: "THE PRACTITIONER",
      actor: "Tom Stovall",
      gender: .male,
      language: "en",
      voicePrompt: "A measured voice: unhurried, precise.",
      voices: ["voxalta": ["voices/practitioner.vox"]]
    )
    // Inserted in an order that is neither declaration order nor sorted order,
    // so a pass-through of insertion order fails this test too.
    for key in ["zeta", "bio", "mood", "appearance", "alpha", "notes"] {
      member.setExtra(try AnyCodable("value for \(key)"), forKey: key)
    }

    let yaml = try encodeYAML(member)

    XCTAssertEqual(
      topLevelKeys(of: yaml),
      [
        // Declared, in `CodingKeys` declaration order.
        "character", "actor", "gender", "language", "voicePrompt", "voices",
        // Undeclared, lexicographic.
        "alpha", "appearance", "bio", "mood", "notes", "zeta",
      ],
      "emitted key order is wrong. Emitted:\n\(yaml)")
  }

  /// Front matter emits `type`, `schemaVersion`, `cast` — in that order.
  ///
  /// Lexicographic key sorting would produce `cast`, `schemaVersion`, `type`,
  /// so this assertion fails the moment anyone turns sorting on in
  /// `YAMLCoding.swift`.
  func testFrontMatterKeyOrderIsFixed() throws {
    let document = CastDocument(cast: [CastMember(character: "NARRATOR")])
    let yaml = try encodeYAML(document)

    XCTAssertEqual(
      topLevelKeys(of: yaml), ["type", "schemaVersion", "cast"],
      "front-matter key order is wrong. Emitted:\n\(yaml)")
  }

  // MARK: - Task 7 / AR-2: the YAML 1.1 boolean trap

  /// `language: no` is the string `"no"`, not `false`.
  ///
  /// This is the case AR-2 exists for. Under YAML 1.1's default resolver the
  /// plain scalars `no`, `yes`, `on`, and `off` all resolve to booleans, which
  /// would turn the Norwegian BCP-47 tag `no` into `false` and destroy the
  /// field.
  ///
  /// It does not happen, and the reason is a single line of Yams:
  /// `YAMLDecoder` constructs its parser with `Resolver([.merge])` rather than
  /// `Resolver.default` at `Yams/Sources/Yams/Decoder.swift:147` (Yams 6.2.2),
  /// so the `Codable` path performs no implicit type resolution beyond merge
  /// keys. A plain scalar's *resolved* tag is therefore `.str`, and
  /// `String.construct` hands back `scalar.string` verbatim
  /// (`Constructor.swift:387`). Every declared field of ``CastMember`` is typed
  /// `String?`, so every declared field is protected by this.
  ///
  /// **The protection is narrower than it looks — see
  /// ``testBooleanLookalikesUnderAnUnknownKey`` before relying on it anywhere
  /// the destination type is not already a `String`.**
  ///
  /// The upstream behavior is deliberate but undocumented (AR-2), so a Yams
  /// release could change it without calling it a break. **If this test turns
  /// red after a Yams bump, that is a dependency decision to escalate — not a
  /// test to update.**
  func testLanguageNoDecodesAsString() throws {
    let yaml = """
      character: THE NORWEGIAN
      language: no
      """

    let member = try decodeYAML(CastMember.self, from: yaml)

    XCTAssertEqual(member.language, "no", "`language: no` was resolved as a YAML 1.1 boolean")

    // ...and it goes back out quoted, so the next reader of the file cannot
    // resolve it as a boolean either.
    let reEmitted = try encodeYAML(member)
    XCTAssertTrue(
      reEmitted.contains("language: 'no'"),
      "re-emission did not quote the string `no`:\n\(reEmitted)")

    let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)
    XCTAssertEqual(reDecoded.language, "no")
  }

  /// Every YAML 1.1 boolean look-alike, under an *undeclared* key.
  ///
  /// ## This test pins DISCOVERED behavior, and it is not what Sortie 8 was told to expect
  ///
  /// The sortie brief asserted that `no`, `yes`, `on`, `off`, `y`, and `n`
  /// under an unknown key are each captured as a `String` and re-emitted
  /// unchanged. **Four of the six are not.** The behavior below is what Yams
  /// 6.2.2 actually does, measured, and it is pinned here rather than wished
  /// away. Read the mechanism before changing anything:
  ///
  /// `Resolver([.merge])` (`Decoder.swift:147`) governs a node's *resolved*
  /// tag. It does not change the node's *raw* tag, which for an unquoted plain
  /// scalar is `.implicit`. `Bool.construct` gates on the raw tag —
  /// `if scalar.tag.name == .str { return nil }` (`Constructor.swift:154-157`)
  /// — so `.implicit` sails straight past the guard and into a YAML 1.1
  /// boolean switch over `true/yes/on` and `false/no/off`
  /// (`Constructor.swift:158-166`).
  ///
  /// A *declared* field is safe because its destination type is `String?`, and
  /// nothing ever asks for a `Bool`. An *undeclared* key is not, because
  /// `AnyCodable.init(from:)` probes `Bool` → `Int` → `Double` → `String` in
  /// that order and the first success wins. `y` and `n` survive only because
  /// they are absent from Yams' boolean switch, not because anything protects
  /// them.
  ///
  /// ## What this costs, precisely
  ///
  /// A hand-written `retired: no` under an unknown key is captured as the
  /// boolean `false` and re-emitted as `retired: false`. The *meaning* is
  /// preserved — YAML 1.1 says that scalar is a boolean — but the spelling is
  /// normalized on first write, in the same family as the `schemaVersion`
  /// stamp (D-5).
  ///
  /// RQ-11 is not violated: it guarantees `generate(parse(x)) == x` for `x`
  /// this library emitted, and this library emits `false`, which is stable
  /// forever after. **Sorties 13/14: a pinned fixture containing an unquoted
  /// `no`/`yes`/`on`/`off` as a whole value under an undeclared key will fail
  /// the SHA-256 gate on its first pass.** Quote it in the fixture, or expect
  /// the normalization.
  ///
  /// Escalated to the supervisor rather than worked around: the only fixes
  /// available are in `AnyCodable.init(from:)`'s probe order or in a
  /// node-retagging pass in `YAMLCoding.swift`, and both are policy decisions
  /// about which YAML dialect this library speaks.
  func testBooleanLookalikesUnderAnUnknownKey() throws {
    // Not in Yams' boolean switch, so they arrive as strings.
    for token in ["y", "n"] {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token, "'\(token)' was not captured as a String")
      XCTAssertNil(try? captured.decode(Bool.self), "'\(token)' was captured as a Bool")

      let reEmitted = try encodeYAML(member)
      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)

      XCTAssertEqual(
        try XCTUnwrap(reDecoded[extra: "mood"]).decode(String.self), token,
        "'\(token)' changed on re-emission. Emitted:\n\(reEmitted)")
      XCTAssertEqual(reDecoded, member, "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }

    // In Yams' boolean switch, so they arrive as `Bool` and re-emit with the
    // canonical spelling. See the discussion above before "fixing" this.
    for (token, expected) in [("yes", true), ("on", true), ("no", false), ("off", false)] {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(Bool.self), expected,
        "'\(token)' is no longer captured as a Bool — the discovered behavior changed")

      let reEmitted = try encodeYAML(member)
      XCTAssertTrue(
        reEmitted.contains("mood: \(expected)"),
        "'\(token)' did not normalize to `\(expected)`. Emitted:\n\(reEmitted)")

      // Whatever the spelling, the value is stable from the first write on,
      // which is what RQ-11 actually requires.
      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)
      XCTAssertEqual(reDecoded, member, "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }
  }

  /// Quoting is the escape hatch, and it works for every token.
  ///
  /// This is the answer to give anyone whose undeclared `no` turned into
  /// `false`: write `'no'`. A quoted scalar has style `.singleQuoted`, and
  /// every numeric constructor bails on a non-plain style while
  /// `Bool.construct`'s switch never sees a match for the quoted text.
  func testQuotedBooleanLookalikesStayStrings() throws {
    for token in ["no", "yes", "on", "off", "y", "n", "true", "false"] {
      let member = try decodeMemberWithMood("'\(token)'")
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token,
        "quoted '\(token)' was not captured as a String")

      let reEmitted = try encodeYAML(member)
      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)

      XCTAssertEqual(
        try XCTUnwrap(reDecoded[extra: "mood"]).decode(String.self), token,
        "quoted '\(token)' changed on re-emission. Emitted:\n\(reEmitted)")
      XCTAssertEqual(reDecoded, member, "quoted '\(token)' did not round-trip")
    }
  }

  // MARK: - Decode-side behavior the parser layer will meet

  /// An empty roster written as `cast: []` decodes to a valid empty document.
  ///
  /// Recorded here because the bare valueless form (`cast:` with nothing after
  /// it) resolves to null and is rejected as `.missingCastKey` — a fact worth
  /// having pinned before Sortie 10 writes an empty roster for the first time.
  func testEmptyRosterRoundTrips() throws {
    let document = CastDocument(cast: [])
    let yaml = try encodeYAML(document)
    let decoded = try decodeYAML(CastDocument.self, from: yaml)

    XCTAssertTrue(yaml.contains("cast: []"), "an empty roster did not emit as `cast: []`:\n\(yaml)")
    XCTAssertEqual(decoded.cast, [])
    XCTAssertEqual(decoded.schemaVersion, CastSchemaVersion.current)
  }

  /// A whole document, roster and all, survives a round trip.
  ///
  /// The end-to-end version of everything above, and the assertion that
  /// replaces `PackageSmokeTests.testYamsEncodeDecodeRoundTrip`.
  func testWholeDocumentRoundTrips() throws {
    var practitioner = try makeMember(bio: Self.longProse)
    practitioner.setExtra(
      try AnyCodable(["lora": ["path": "loras/p.safetensors"]]), forKey: "appearance")

    let document = CastDocument(
      cast: [
        practitioner,
        CastMember(character: "NARRATOR", language: "no"),
      ]
    )

    let yaml = try encodeYAML(document)
    let decoded = try decodeYAML(CastDocument.self, from: yaml)

    XCTAssertEqual(decoded.cast, document.cast, "roster did not round-trip. Emitted:\n\(yaml)")
    XCTAssertEqual(decoded.schemaVersion, CastSchemaVersion.current)
    // `body` is not part of the encoded form by design — the markdown layer
    // owns it. This is a statement of the contract, not an oversight.
    XCTAssertEqual(decoded.body, "")
  }

  // MARK: - Sortie 8a: cross-process byte stability of nested mappings

  /// A `CastMember` carrying a nested `appearance:` block emits
  /// byte-identically no matter which insertion order was used to build the
  /// nested dictionary.
  ///
  /// ## This is a proxy, not a true cross-process test
  ///
  /// The defect Sortie 8a fixes is that `AnyCodable.encode(to:)` used to hand
  /// a decoded `[String: AnyCodable]` straight to the encoder, which walks
  /// `Dictionary`'s own storage order — stable within a process (per Sortie
  /// 8's `testRepeatedEncodingIsByteIdentical`) but seeded per process, so it
  /// is not guaranteed to match between two separate invocations of the same
  /// program. A literal cross-process test would mean spawning a second
  /// `xctest` process from inside this one and diffing its output; XCTest has
  /// no supported way to do that, and even a hand-rolled `Process` launch
  /// would make this suite's pass/fail depend on process-spawning mechanics
  /// unrelated to `AnyCodable` — a worse trade than the gap it would close.
  ///
  /// Building the same logical `appearance:` mapping through two different
  /// insertion sequences is the closest in-process substitute: Swift's
  /// `Dictionary` storage layout can differ for the same keys inserted in a
  /// different order (the same property that makes cross-process order
  /// unstable in the first place), so this exercises a real, if narrower,
  /// instance of the hazard. What actually proves the fix — at every
  /// depth, deterministically — is `AnyCodableTests
  /// .testThreeLevelNestedMappingIsSortedAtEveryLevel`; this test is the
  /// `CastMember` / `extraKeys` shape D-3 cares about, layered on top.
  func testNestedAppearanceBlockEmitsByteIdenticallyRegardlessOfInsertionOrder() throws {
    let loraKeys = ["path", "engine", "scale", "rank", "adapter", "weight", "tag", "version"]

    func buildLora(insertionOrder keysInOrder: [String]) -> [String: String] {
      var lora: [String: String] = [:]
      for key in keysInOrder {
        lora[key] = "value-for-\(key)"
      }
      return lora
    }

    let forwardLora = buildLora(insertionOrder: loraKeys)
    let reverseLora = buildLora(insertionOrder: loraKeys.reversed())
    XCTAssertEqual(
      forwardLora, reverseLora,
      "fixture bug: the two dictionaries must be logically equal for this test to mean anything")

    var memberBuiltForward = CastMember(character: "THE PRACTITIONER")
    memberBuiltForward.setExtra(try AnyCodable(["lora": forwardLora]), forKey: "appearance")

    var memberBuiltReverse = CastMember(character: "THE PRACTITIONER")
    memberBuiltReverse.setExtra(try AnyCodable(["lora": reverseLora]), forKey: "appearance")

    let yamlForward = try encodeYAML(memberBuiltForward)
    let yamlReverse = try encodeYAML(memberBuiltReverse)

    XCTAssertEqual(
      yamlForward, yamlReverse,
      "the same logical `appearance:` block emitted different bytes depending on nested "
        + "dictionary insertion order.\nforward:\n\(yamlForward)\nreverse:\n\(yamlReverse)")
  }
}
