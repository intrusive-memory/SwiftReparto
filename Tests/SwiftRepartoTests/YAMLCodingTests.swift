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
//
// Sortie 8b added a second subject: the *dialect*. `decodeYAML` now narrows
// libyaml's YAML 1.1 implicit typing to the YAML 1.2 core schema for booleans,
// by retagging plain scalars in the parsed `Node` tree. The tests under
// "Task 7 / AR-2" own that narrowing end to end — the tokens it must convert,
// the six spellings it must leave alone, the quoted forms it must not touch,
// and the fact that it reaches every depth.
//
// Sortie 9a finished that commitment for *numbers*. The tests under "Sortie 9a"
// own the rule that a plain scalar becomes a number only when doing so is
// provably lossless in spelling — so `0755` is the string `"0755"` rather than
// the integer 493, and no floating-point spelling is parsed as a number at all,
// while `180` is still the integer 180 and still emits bare.

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
  /// This is a legacy `appearance:` block's shape (RQ-25) — the deprecated field rides
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

  /// Every YAML 1.1 boolean look-alike, under an *undeclared* key, is a
  /// `String` carrying its original spelling.
  ///
  /// ## This test changed in Sortie 8b, deliberately, by user decision
  ///
  /// Sortie 8 measured the opposite and pinned it: `yes`, `no`, `on`, and `off`
  /// under an unknown key were captured as `Bool` and re-emitted as
  /// `true`/`false`, destroying the author's spelling. The mechanism was that
  /// `Resolver([.merge])` (`Decoder.swift:147`) governs a node's *resolved*
  /// tag while `Bool.construct` gates on its *raw* tag —
  /// `if scalar.tag.name == .str { return nil }` (`Constructor.swift:154-157`)
  /// — and an unquoted plain scalar's raw tag is `.implicit`, so it reached
  /// YAML 1.1's boolean switch. Declared fields were never affected, because
  /// every `CastMember` field is `String?` and nothing on that path ever asks
  /// for a `Bool`.
  ///
  /// **The user decided this library reads the YAML 1.2 core schema.** Under
  /// that schema the boolean set is exactly `true`/`True`/`TRUE`/`false`/
  /// `False`/`FALSE`; `yes`, `no`, `on`, `off`, `y`, and `n` are strings.
  /// `decodeYAML` now walks the parsed `Node` tree and stamps an explicit
  /// `.str` raw tag onto every plain scalar in that gap, which turns
  /// `Bool.construct`'s own guard against it. See the dialect comment block at
  /// the top of `YAMLCoding.swift`.
  ///
  /// This test is the pin for that decision. **A failure here means the
  /// retagging pass stopped working, not that the expectation is stale** — the
  /// four uppercase variants are included because Yams matches booleans on
  /// `scalar.string.lowercased()`, so a pass that only handled lowercase would
  /// leave `NO` resolving to `false`.
  ///
  /// ## What it still does not buy (Sorties 13/14)
  ///
  /// The *value* survives; the *bytes* do not. A bare `mood: no` re-emits as
  /// `mood: 'no'` — quoted, because the emitter must stop the next reader from
  /// re-resolving it. A pinned fixture containing a bare `no`/`yes`/`on`/`off`
  /// under an undeclared key still fails a SHA-256 byte gate on its first pass.
  /// Write it quoted in the fixture.
  func testBooleanLookalikesUnderAnUnknownKey() throws {
    let tokens = [
      "no", "No", "NO",
      "yes", "Yes", "YES",
      "on", "On", "ON",
      "off", "Off", "OFF",
      "y", "Y", "n", "N",
    ]

    for token in tokens {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token,
        "'\(token)' was not captured as the String '\(token)'")
      XCTAssertNil(
        try? captured.decode(Bool.self),
        "'\(token)' was captured as a Bool — the YAML 1.2 core retagging pass missed it")

      // The spelling, not merely the meaning, survives re-emission.
      let reEmitted = try encodeYAML(member)
      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)

      XCTAssertEqual(
        try XCTUnwrap(reDecoded[extra: "mood"]).decode(String.self), token,
        "'\(token)' changed on re-emission. Emitted:\n\(reEmitted)")
      XCTAssertEqual(reDecoded, member, "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
      XCTAssertFalse(
        reEmitted.contains("mood: true") || reEmitted.contains("mood: false"),
        "'\(token)' was normalized to a boolean spelling. Emitted:\n\(reEmitted)")
    }

    // The exact bytes, pinned so the honest limitation above is not a claim in
    // a comment: a bare `mood: no` comes back as `mood: 'no'`. The spelling
    // survives. The plain style does not, and cannot — an unquoted `no` on the
    // way out would be a boolean to any other YAML 1.1 reader of the file.
    let reEmittedBareNo = try encodeYAML(try decodeMemberWithMood("no"))
    XCTAssertTrue(
      reEmittedBareNo.contains("mood: 'no'"),
      "a bare `mood: no` did not re-emit as `mood: 'no'`. Emitted:\n\(reEmittedBareNo)")
  }

  /// The six YAML 1.2 core-schema boolean spellings are still booleans.
  ///
  /// The retagging pass narrows YAML 1.1's boolean set; it must not empty it.
  /// If this goes red alongside
  /// ``testBooleanLookalikesUnderAnUnknownKey`` staying green, the guard in
  /// `retaggingPlainYAML11Booleans(in:)` has been inverted or its
  /// case-sensitive allow-list has lost an entry.
  func testYAML12CoreBooleansStillDecodeAsBool() throws {
    for (token, expected) in [
      ("true", true), ("True", true), ("TRUE", true),
      ("false", false), ("False", false), ("FALSE", false),
    ] {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(Bool.self), expected,
        "'\(token)' is a YAML 1.2 core boolean and was not decoded as one")

      // Case is normalized to the canonical spelling on re-emission, which is
      // what a boolean *is* — this is not the string path.
      let reEmitted = try encodeYAML(member)
      XCTAssertTrue(
        reEmitted.contains("mood: \(expected)"),
        "'\(token)' did not re-emit as the boolean `\(expected)`. Emitted:\n\(reEmitted)")

      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)
      XCTAssertEqual(reDecoded, member, "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }
  }

  /// A boolean look-alike inside a *nested* mapping under an undeclared key.
  ///
  /// The retagging walk descends; this is the test that proves it. A pass that
  /// only inspected the document's top-level mapping values would leave
  /// `flags.retired` as `false` and `tags[1]` as `true`, and every other
  /// boolean test in this file would still pass.
  ///
  /// It also guards Sortie 8a: the nested mapping must still emit with its keys
  /// sorted at every depth after the walk has rewritten the node tree.
  func testBooleanLookalikesAreRetaggedInsideANestedExtra() throws {
    let member = try decodeYAML(
      CastMember.self,
      from: """
        character: THE PRACTITIONER
        flags:
          retired: no
          nested:
            deeper:
              active: yes
          tags:
            - off
            - "on"
            - true
        """)

    let flags = try XCTUnwrap(member[extra: "flags"], "`flags` was not captured")
    let decoded = try flags.decode([String: AnyCodable].self)

    XCTAssertEqual(
      try XCTUnwrap(decoded["retired"]).decode(String.self), "no",
      "a boolean look-alike one level down was not retagged")

    let nested = try XCTUnwrap(decoded["nested"]).decode([String: [String: AnyCodable]].self)
    XCTAssertEqual(
      try XCTUnwrap(nested["deeper"]?["active"]).decode(String.self), "yes",
      "a boolean look-alike three levels down was not retagged")

    let tags = try XCTUnwrap(decoded["tags"]).decode([AnyCodable].self)
    XCTAssertEqual(tags.count, 3)
    XCTAssertEqual(
      try tags[0].decode(String.self), "off",
      "a boolean look-alike inside a sequence was not retagged")
    XCTAssertEqual(
      try tags[1].decode(String.self), "on",
      "a quoted sequence element did not stay a String")
    XCTAssertEqual(
      try tags[2].decode(Bool.self), true,
      "a YAML 1.2 core boolean inside a sequence stopped being a Bool")

    // Round-trips, and Sortie 8a's every-depth key sorting still holds.
    let reEmitted = try encodeYAML(member)
    XCTAssertEqual(
      try decodeYAML(CastMember.self, from: reEmitted), member,
      "the nested extra did not round-trip. Emitted:\n\(reEmitted)")
    XCTAssertEqual(
      try encodeYAML(try decodeYAML(CastMember.self, from: reEmitted)), reEmitted,
      "re-emission was not stable. Emitted:\n\(reEmitted)")
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

  /// A double-quoted `"no"` is untouched by the retagging pass.
  ///
  /// ``testQuotedBooleanLookalikesStayStrings`` covers the single-quoted form.
  /// This one exists because the retagging guard is written in terms of scalar
  /// *style*, and `.singleQuoted` and `.doubleQuoted` are two different styles
  /// — a guard that named only one of them would pass that test and fail here.
  /// A quoted scalar was already a `String`; the pass must neither change its
  /// value nor make it stop round-tripping.
  func testDoubleQuotedBooleanLookalikesAreUnaffected() throws {
    for token in ["no", "yes", "on", "off", "true", "false", "NO", "Yes"] {
      let member = try decodeMemberWithMood("\"\(token)\"")
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token,
        "double-quoted '\(token)' was not captured as a String")

      let reEmitted = try encodeYAML(member)
      XCTAssertEqual(
        try decodeYAML(CastMember.self, from: reEmitted), member,
        "double-quoted '\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }
  }

  // MARK: - Sortie 9a: the YAML 1.1 numeric trap

  /// Every YAML 1.1 / Yams numeric extension, under an *undeclared* key, is a
  /// `String` carrying its original spelling.
  ///
  /// ## The rule these rows encode
  ///
  /// **A plain scalar is decoded as a number only when doing so is provably
  /// lossless in spelling.** For an integer that reduces to
  /// `String(intValue) == originalSpelling`; anything else stays a `String`.
  /// That is stronger than YAML 1.2 core on purpose: strict 1.2 core would read
  /// `0755` as decimal `755`, which is still not the characters the author
  /// wrote, and RQ-4 asks for verbatim.
  ///
  /// ## What each row was doing before Sortie 9a
  ///
  /// Measured, under an undeclared key, on the commit before this one:
  ///
  ///     12:34   -> Int 754    re-emitted as `754`
  ///     1:00:00 -> Int 3600   re-emitted as `3600`
  ///     0755    -> Int 493    re-emitted as `493`
  ///     0b1011  -> Int 11     re-emitted as `11`
  ///     0o17    -> Int 15     re-emitted as `15`
  ///     0x1f    -> Int 31     re-emitted as `31`
  ///     1_000   -> Int 1000   re-emitted as `1000`
  ///
  /// `0755` was the worst of them: a silent *value* mutation, not merely a
  /// re-spelling, because YAML 1.2 core reads those same characters as decimal
  /// 755 while Yams' YAML 1.1 rules read octal 493.
  ///
  /// **A failure here means the narrowing pass stopped working, not that the
  /// expectation is stale.** In particular, restoring the old behavior would
  /// mean a hand-written `code: 0755` in a cast file silently becomes `493`.
  func testYAML11NumericExtensionsUnderAnUnknownKeyStayStrings() throws {
    let tokens = [
      // Sexagesimal — not a number in YAML 1.2 core at all.
      "12:34", "1:00:00",
      // Bare-leading-zero octal — the silent value mutation.
      "0755", "07", "00",
      // Yams' radix prefixes. `0b` is not YAML 1.2 core; `0o` and `0x` are,
      // but neither spelling is reproducible from the parsed value.
      "0b1011", "0o17", "0x1f",
      // Digit separators, and signs/zeroes that do not render back identically.
      "1_000", "+5", "-0",
    ]

    for token in tokens {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token,
        "'\(token)' was not captured as the String '\(token)'")
      XCTAssertNil(
        try? captured.decode(Int.self),
        "'\(token)' was captured as an Int — the YAML 1.2 core narrowing pass missed it")

      // The spelling, not merely the meaning, survives re-emission.
      let reEmitted = try encodeYAML(member)
      let reDecoded = try decodeYAML(CastMember.self, from: reEmitted)

      XCTAssertEqual(
        try XCTUnwrap(reDecoded[extra: "mood"]).decode(String.self), token,
        "'\(token)' changed on re-emission. Emitted:\n\(reEmitted)")
      XCTAssertEqual(reDecoded, member, "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
      XCTAssertTrue(
        reEmitted.contains("mood: '\(token)'"),
        "'\(token)' did not re-emit carrying its original characters. Emitted:\n\(reEmitted)")
    }
  }

  /// The single most important row, called out on its own: `0755` is no longer
  /// `493`, and its four characters come back out intact.
  ///
  /// This is a value corruption, not a formatting nit, and it deserves a test
  /// whose failure message says so without the reader decoding a loop.
  func testOctalLookalikeIsNoLongerSilentlyRenumbered() throws {
    let member = try decodeMemberWithMood("0755")
    let captured = try XCTUnwrap(member[extra: "mood"])

    XCTAssertNotEqual(
      try? captured.decode(Int.self), 493,
      "`mood: 0755` was read as octal 493 — a silent value mutation of the author's data")
    XCTAssertEqual(try captured.decode(String.self), "0755")

    let reEmitted = try encodeYAML(member)
    XCTAssertTrue(
      reEmitted.contains("0755"),
      "the characters `0755` did not survive re-emission. Emitted:\n\(reEmitted)")
    XCTAssertFalse(
      reEmitted.contains("493"),
      "`0755` re-emitted as `493`. Emitted:\n\(reEmitted)")
  }

  /// A genuinely numeric scalar still decodes as an `Int` and still re-emits
  /// *bare*.
  ///
  /// The narrowing pass must not turn every digit in the file into a string.
  /// `String(180) == "180"`, so decoding it as a number is provably lossless
  /// and it is left alone — which also means it goes back out unquoted, exactly
  /// as the author wrote it. If this goes red alongside
  /// ``testYAML11NumericExtensionsUnderAnUnknownKeyStayStrings`` staying green,
  /// the lossless test has been inverted or dropped.
  func testLosslessIntegersStillDecodeAsIntAndReEmitBare() throws {
    for (token, expected) in [("180", 180), ("-5", -5), ("0", 0), ("1000", 1000)] {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(Int.self), expected,
        "'\(token)' is a lossless integer spelling and stopped decoding as an Int")

      let reEmitted = try encodeYAML(member)
      XCTAssertTrue(
        reEmitted.contains("mood: \(token)\n") || reEmitted.hasSuffix("mood: \(token)"),
        "'\(token)' did not re-emit bare — it was quoted. Emitted:\n\(reEmitted)")
      XCTAssertFalse(
        reEmitted.contains("mood: '\(token)'"),
        "'\(token)' was quoted on re-emission. Emitted:\n\(reEmitted)")
      XCTAssertEqual(
        try decodeYAML(CastMember.self, from: reEmitted), member,
        "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }
  }

  /// Every floating-point spelling, under an undeclared key, is a `String`.
  ///
  /// ## Why the lossless test is never satisfied by a float
  ///
  /// This is a measurement, not a policy. Before Sortie 9a, under an undeclared
  /// key:
  ///
  ///     1.0   -> Double 1.0  re-emitted as `1`       (JSON collapse to Int)
  ///     1.    -> Double 1.0  re-emitted as `1`
  ///     1e3   -> Double 1e3  re-emitted as `1000`
  ///     1.5   -> Double 1.5  re-emitted as `1.5e+0`  (Yams' `%.*g` rendering)
  ///     .5    -> Double 0.5  re-emitted as `5e-1`
  ///     .inf  -> THREW. `JSONEncoder` refuses a non-finite Double and
  ///     -.inf -> THREW. `AnyCodable.init(from:)` does not guard that `try`,
  ///     .nan  -> THREW. so a legal YAML document was simply unreadable.
  ///     1e400 -> THREW (overflows to `inf` on the way into JSON).
  ///
  /// Two independent renderers stand between a parsed `Double` and the file —
  /// `AnyCodable`'s JSON store, which probes `Int` before `Double` on the way
  /// out and so collapses every integer-valued double, and Yams'
  /// `formattedStringForCodable`, which writes scientific notation. Neither
  /// reproduces a source spelling, so no float passes the lossless test and all
  /// of them stay strings. The three throwing cases become ordinary strings as
  /// a side effect, which is a strict improvement: those documents now decode.
  func testFloatingPointScalarsUnderAnUnknownKeyStayStrings() throws {
    let tokens = [
      "1.0", "1.", "1.5", "1.50", ".5", "0.0", "1e3", "1e400",
      ".inf", "-.inf", ".nan",
    ]

    for token in tokens {
      let member = try decodeMemberWithMood(token)
      let captured = try XCTUnwrap(member[extra: "mood"], "`mood` was not captured for '\(token)'")

      XCTAssertEqual(
        try captured.decode(String.self), token,
        "'\(token)' was not captured as the String '\(token)'")
      XCTAssertNil(
        try? captured.decode(Double.self),
        "'\(token)' was captured as a Double — no float spelling survives this pipeline")

      let reEmitted = try encodeYAML(member)
      XCTAssertTrue(
        reEmitted.contains("mood: '\(token)'"),
        "'\(token)' did not re-emit carrying its original characters. Emitted:\n\(reEmitted)")
      XCTAssertEqual(
        try decodeYAML(CastMember.self, from: reEmitted), member,
        "'\(token)' did not round-trip. Emitted:\n\(reEmitted)")
    }
  }

  /// The narrowing reaches a nested mapping and a sequence element.
  ///
  /// A pass that only inspected the document's top-level mapping values would
  /// leave `codes.mode` as `493` and `codes.list[0]` as `754`, and every other
  /// numeric test in this file would still pass.
  ///
  /// It also guards Sortie 8a: the nested mapping must still emit with its keys
  /// sorted at every depth after the walk has rewritten the node tree.
  func testNumericNarrowingReachesNestedMappingsAndSequences() throws {
    let member = try decodeYAML(
      CastMember.self,
      from: """
        character: THE PRACTITIONER
        codes:
          mode: 0755
          nested:
            deeper:
              mask: 0o17
          list:
            - 12:34
            - "0755"
            - 180
        """)

    let codes = try XCTUnwrap(member[extra: "codes"], "`codes` was not captured")
    let decoded = try codes.decode([String: AnyCodable].self)

    XCTAssertEqual(
      try XCTUnwrap(decoded["mode"]).decode(String.self), "0755",
      "an octal look-alike one level down was not narrowed")

    let nested = try XCTUnwrap(decoded["nested"]).decode([String: [String: AnyCodable]].self)
    XCTAssertEqual(
      try XCTUnwrap(nested["deeper"]?["mask"]).decode(String.self), "0o17",
      "a numeric look-alike three levels down was not narrowed")

    let list = try XCTUnwrap(decoded["list"]).decode([AnyCodable].self)
    XCTAssertEqual(list.count, 3)
    XCTAssertEqual(
      try list[0].decode(String.self), "12:34",
      "a sexagesimal inside a sequence was not narrowed")
    XCTAssertEqual(
      try list[1].decode(String.self), "0755",
      "an already-quoted sequence element did not stay a String")
    XCTAssertEqual(
      try list[2].decode(Int.self), 180,
      "a lossless integer inside a sequence stopped being an Int")

    // Round-trips, and Sortie 8a's every-depth key sorting still holds.
    let reEmitted = try encodeYAML(member)
    XCTAssertEqual(
      try decodeYAML(CastMember.self, from: reEmitted), member,
      "the nested extra did not round-trip. Emitted:\n\(reEmitted)")
    XCTAssertEqual(
      try encodeYAML(try decodeYAML(CastMember.self, from: reEmitted)), reEmitted,
      "re-emission was not stable. Emitted:\n\(reEmitted)")
  }

  /// A *declared* `String?` field carrying `0755` is unaffected.
  ///
  /// Declared fields were never exposed to the numeric trap — `String.construct`
  /// hands back `scalar.string` verbatim regardless of style or tag
  /// (`Constructor.swift:387`) — and the narrowing pass must not have changed
  /// that in either direction. This is the control for
  /// ``testYAML11NumericExtensionsUnderAnUnknownKeyStayStrings``.
  func testDeclaredStringFieldCarryingAnOctalLookalikeIsUnaffected() throws {
    let member = try decodeYAML(
      CastMember.self,
      from: """
        character: THE PRACTITIONER
        actor: 0755
        language: 12:34
        """)

    XCTAssertEqual(member.actor, "0755", "a declared `String?` field lost its verbatim spelling")
    XCTAssertEqual(member.language, "12:34", "a declared `String?` field was read sexagesimally")

    let reEmitted = try encodeYAML(member)
    XCTAssertEqual(
      try decodeYAML(CastMember.self, from: reEmitted), member,
      "a declared field carrying a numeric look-alike did not round-trip. Emitted:\n\(reEmitted)")
  }

  /// The exact emitted bytes for one member carrying both shapes side by side.
  ///
  /// Pinned so the honest limitation in `YAMLCoding.swift` is not merely a
  /// claim in a comment: the preserved string is quoted and the genuine integer
  /// is bare, in the same document.
  func testPreservedStringAndBareIntegerEmitSideBySide() throws {
    let member = try decodeYAML(
      CastMember.self,
      from: """
        character: THE PRACTITIONER
        count: 180
        mood: 0755
        """)

    let reEmitted = try encodeYAML(member)

    XCTAssertEqual(
      reEmitted,
      """
      character: THE PRACTITIONER
      voices: {}
      count: 180
      mood: '0755'

      """,
      "the emitted form changed. Emitted:\n\(reEmitted)")
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
