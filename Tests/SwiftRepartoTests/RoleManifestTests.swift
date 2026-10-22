// RoleManifestTests.swift
// SwiftRepartoTests
//
// 0.2.0: `role` (RQ-19) and `manifest` (RQ-20) as declared fields, their
// round-trip and parsing, the RQ-24 migration from extras, and RP-P16 write
// locality. Synthetic data only — the repository is public.
//
// A plain `import SwiftReparto`: every API exercised here is public.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class RoleManifestTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("RoleManifestTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory
  }

  // MARK: - RQ-19: CastRole

  func testCastRoleRawValuesAreTheWireFormat() {
    XCTAssertEqual(
      CastRole.allCases.map(\.rawValue),
      ["lead", "supporting", "guest", "narrator", "costar", "underfive", "background"])
  }

  func testCastRoleDisplayNames() {
    XCTAssertEqual(
      CastRole.allCases.map(\.displayName),
      ["Lead", "Supporting", "Guest Star", "Narrator", "Co-Star", "Under-Five", "Background"])
  }

  func testIsMajorSplitsTheTiers() {
    XCTAssertEqual(
      CastRole.allCases.filter(\.isMajor), [.lead, .supporting, .guest, .narrator])
    XCTAssertEqual(
      CastRole.allCases.filter { !$0.isMajor }, [.costar, .underfive, .background])
  }

  func testRoleAndManifestDefaultToNil() {
    let member = CastMember(character: "NARRATOR")
    XCTAssertNil(member.role)
    XCTAssertNil(member.manifest)
  }

  // MARK: - Acceptance 1: typed fields, byte-identical re-encode

  func testRoleManifestFixtureDecodesIntoTypedFields() throws {
    let document = try parser.parse(content: try TestFixture.roleManifestCastMD.contents())
    let byName = Dictionary(uniqueKeysWithValues: document.cast.map { ($0.character, $0) })

    let practitioner = try XCTUnwrap(byName["THE PRACTITIONER"])
    XCTAssertEqual(practitioner.role, .lead)
    XCTAssertEqual(practitioner.manifest, "characters/THE PRACTITIONER.dossier/manifest.json")
    XCTAssertEqual(Set(practitioner.extraKeys.keys), ["bio"])

    XCTAssertEqual(byName["NARRATOR"]?.role, .narrator)
    XCTAssertEqual(byName["GUARD #2"]?.role, .underfive)
    XCTAssertNil(byName["GUARD #2"]?.manifest)
    XCTAssertNil(byName["JOSÉ"]?.role)
    XCTAssertEqual(byName["JOSÉ"]?.manifest, "characters/JOSÉ.dossier/manifest.json")
    XCTAssertEqual(byName["COUNTER CLERK"]?.role, .background)

    for member in document.cast {
      XCTAssertNil(member[extra: "role"], "\(member.character): role must not land in extraKeys")
      XCTAssertNil(
        member[extra: "manifest"], "\(member.character): manifest must not land in extraKeys")
    }
  }

  func testRoleManifestFixtureRoundTripsByteForByte() throws {
    let original = try TestFixture.roleManifestCastMD.contents()
    let regenerated = try parser.generate(document: try parser.parse(content: original))
    XCTAssertEqual(sha256(regenerated), sha256(original), regenerated)
  }

  func testRoleManifestFixtureRoundTripsThroughAFile() throws {
    let directory = try makeTemporaryDirectory()
    let url = directory.appendingPathComponent("CAST.md")
    let original = try TestFixture.roleManifestCastMD.contents()
    try original.write(to: url, atomically: true, encoding: .utf8)

    try parser.write(document: try parser.parse(fileURL: url), to: url)
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
  }

  /// The emission position the implementation picked (RQ-23 withdrawn): `role`
  /// right after `character`, `manifest` right after `voices`.
  func testEmissionPositionOfRoleAndManifest() throws {
    let member = CastMember(
      character: "NARRATOR", role: .narrator, actor: "A. Person",
      voices: ["voxalta": ["voices/NARRATOR.vox"]], manifest: "characters/NARRATOR/manifest.json",
      extraKeys: ["bio": try AnyCodable("Synthetic.")])
    let emitted = try parser.generate(document: CastDocument(cast: [member]))
    XCTAssertEqual(
      emitted,
      """
      ---
      type: cast
      schemaVersion: 1
      cast:
      - character: NARRATOR
        role: narrator
        actor: A. Person
        voices:
          voxalta:
          - voices/NARRATOR.vox
        manifest: characters/NARRATOR/manifest.json
        bio: Synthetic.
      ---

      """)
  }

  /// D-14 / RQ-11: a member with neither field emits no trace of either, so
  /// every 0.1.0 document encodes exactly as before.
  func testMemberWithoutRoleOrManifestEmitsNeitherKey() throws {
    let emitted = try parser.generate(
      document: CastDocument(cast: [CastMember(character: "NARRATOR", actor: "A. Person")]))
    XCTAssertFalse(emitted.contains("role"), emitted)
    XCTAssertFalse(emitted.contains("manifest"), emitted)
  }

  func testSchemaVersionIsStillOne() {
    XCTAssertEqual(CastSchemaVersion.current, 1, "D-14: no schema version bump for 0.2.0")
  }

  // MARK: - Acceptance 3: strict role decoding

  func testUnknownRoleFailsWithInvalidRole() throws {
    let content = try TestFixture.rejectInvalidRole.contents()
    XCTAssertThrowsError(try parser.parse(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidRole(index: 1, value: "star"))
    }
  }

  func testUnknownRoleFailsThroughParseFileURL() throws {
    let url = try TestFixture.rejectInvalidRole.url()
    XCTAssertThrowsError(try parser.parse(fileURL: url)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidRole(index: 1, value: "star"))
    }
  }

  func testRoleIsCaseSensitive() throws {
    let content = """
      ---
      type: cast
      cast:
      - character: NARRATOR
        role: Lead
      ---

      """
    XCTAssertThrowsError(try parser.parse(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidRole(index: 0, value: "Lead"))
    }
  }

  func testUnknownRoleFailsOnTheImportPathToo() throws {
    let content = """
      ---
      type: project
      cast:
      - character: NARRATOR
        role: star
      ---

      """
    XCTAssertThrowsError(try ProjectCastImporter().importCast(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidRole(index: 0, value: "star"))
    }
  }

  /// Outside a document there is no index to report, so a standalone member
  /// decode surfaces an ordinary `DecodingError`, never a trap.
  func testStandaloneMemberDecodeWithUnknownRoleThrowsDecodingError() {
    let json = Data(#"{"character": "NARRATOR", "role": "star"}"#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(CastMember.self, from: json)) { error in
      XCTAssertTrue(error is DecodingError, "\(error)")
    }
  }

  // MARK: - RQ-20 / acceptance 4: manifest is opaque

  /// Paths of every shape survive a Yams round trip unchanged, including ones
  /// Yams would misread if they were emitted plain.
  func testAnyManifestPathRoundTripsUnchanged() throws {
    let paths = [
      "characters/THE PRACTITIONER/manifest.json",
      "characters/THE PRACTITIONER.dossier/manifest.json",
      "../shared/characters/NARRATOR.dossier/manifest.json",
      "/Volumes/Elsewhere/NARRATOR.dossier/manifest.json",
      "not-even-a-manifest.txt",
      "manifest.json",
      "yes",
      "no",
      "null",
      "~",
      "0755",
      "12:34",
      "1.5",
      "a: b",
      "#hash",
      "- dash",
      "  padded  ",
      "[bracketed]",
      "{braced}",
      "'single' \"double\"",
      "characters/JOSÉ.dossier/manifest.json",
      "",
    ]
    for path in paths {
      let document = CastDocument(cast: [CastMember(character: "NARRATOR", manifest: path)])
      let emitted = try parser.generate(document: document)
      let reparsed = try parser.parse(content: emitted)
      XCTAssertEqual(reparsed.cast.first?.manifest, path, "manifest \(path.debugDescription)")
      XCTAssertEqual(
        try parser.generate(document: reparsed), emitted,
        "manifest \(path.debugDescription) is not a fixed point")
    }
  }

  // MARK: - Acceptance 5: absolute manifest under the CAST.md directory

  func testAbsoluteManifestUnderTheDirectoryIsEmittedRelative() throws {
    let directory = try makeTemporaryDirectory()
    let url = directory.appendingPathComponent("CAST.md")
    let absolute = directory.appendingPathComponent(
      "characters/THE PRACTITIONER.dossier/manifest.json"
    ).path(percentEncoded: false)
    let content = """
      ---
      type: cast
      schemaVersion: 1
      cast:
      - character: THE PRACTITIONER
        voices: {}
        manifest: "\(absolute)"
      ---

      """
    try content.write(to: url, atomically: true, encoding: .utf8)

    let document = try parser.parse(fileURL: url)
    XCTAssertEqual(
      document.cast.first?.manifest, "characters/THE PRACTITIONER.dossier/manifest.json")

    let emitted = try parser.generate(document: document)
    XCTAssertTrue(
      emitted.contains("manifest: characters/THE PRACTITIONER.dossier/manifest.json"), emitted)
    XCTAssertFalse(emitted.contains(directory.path(percentEncoded: false)), emitted)
  }

  func testAbsoluteManifestOutsideTheDirectoryIsLeftAlone() throws {
    let directory = try makeTemporaryDirectory()
    let url = directory.appendingPathComponent("CAST.md")
    let content = """
      ---
      type: cast
      cast:
      - character: NARRATOR
        manifest: /Volumes/Elsewhere/NARRATOR.dossier/manifest.json
      ---

      """
    try content.write(to: url, atomically: true, encoding: .utf8)
    XCTAssertEqual(
      try parser.parse(fileURL: url).cast.first?.manifest,
      "/Volumes/Elsewhere/NARRATOR.dossier/manifest.json")
  }

  func testAbsoluteManifestIsRelativizedOnImport() throws {
    let directory = try makeTemporaryDirectory()
    let url = directory.appendingPathComponent("PROJECT.md")
    let absolute = directory.appendingPathComponent("characters/NARRATOR.dossier/manifest.json")
      .path(percentEncoded: false)
    try """
    ---
    type: project
    cast:
    - character: NARRATOR
      manifest: "\(absolute)"
    ---

    """.write(to: url, atomically: true, encoding: .utf8)

    XCTAssertEqual(
      try ProjectCastImporter().importCast(fileURL: url).cast.first?.manifest,
      "characters/NARRATOR.dossier/manifest.json")
  }

  // MARK: - RQ-24 migration: role / manifest written as 0.1.0 extras

  func testPreReleaseExtrasLoadIntoTheDeclaredFields() throws {
    let document = try parser.parse(content: try TestFixture.preRoleManifestCastMD.contents())
    XCTAssertEqual(document.cast.map(\.role), [.lead, .supporting, nil, nil])
    XCTAssertEqual(
      document.cast.map(\.manifest),
      [
        "characters/ARCHIVIST.dossier/manifest.json", nil,
        "characters/THE LODGER.dossier/manifest.json", nil,
      ])
    XCTAssertEqual(Set(document.cast[1].extraKeys.keys), ["bio"])
    for member in document.cast {
      XCTAssertNil(member[extra: "role"])
      XCTAssertNil(member[extra: "manifest"])
    }
  }

  /// Personaje acceptance 2, on a synthetic roster of the same shape: the
  /// first write may move keys (normalizing write) but changes no data, and
  /// the second write is byte-identical to the first.
  func testPreReleaseDocumentRewritesWithNoDataChangeAndIsThenAFixedPoint() throws {
    let original = try parser.parse(content: try TestFixture.preRoleManifestCastMD.contents())
    let firstWrite = try parser.generate(document: original)
    let reparsed = try parser.parse(content: firstWrite)

    XCTAssertEqual(reparsed, original, "the first write changed data")
    XCTAssertEqual(try parser.generate(document: reparsed), firstWrite)
    XCTAssertEqual(reparsed.body, original.body)
  }

  // MARK: - RP-P16: writes are local on a normalized file

  /// Lines of `text` belonging to the member named `character`: its
  /// `- character:` line through the line before the next member or the
  /// closing delimiter.
  private func memberLineRange(_ character: String, in lines: [String]) -> Range<Int>? {
    guard
      let start = lines.firstIndex(where: {
        $0 == "- character: \(character)" || $0 == "- character: '\(character)'"
      })
    else { return nil }
    var end = start + 1
    while end < lines.count, !lines[end].hasPrefix("- character: "), lines[end] != "---" {
      end += 1
    }
    return start..<end
  }

  /// The changed line ranges between two texts, as (old, new), using the
  /// longest common prefix and suffix.
  private func changedRanges(_ old: [String], _ new: [String]) -> (Range<Int>, Range<Int>) {
    var prefix = 0
    while prefix < old.count, prefix < new.count, old[prefix] == new[prefix] { prefix += 1 }
    var suffix = 0
    while suffix < old.count - prefix, suffix < new.count - prefix,
      old[old.count - 1 - suffix] == new[new.count - 1 - suffix]
    {
      suffix += 1
    }
    return (prefix..<(old.count - suffix), prefix..<(new.count - suffix))
  }

  private func lines(_ text: String) -> [String] {
    text.components(separatedBy: "\n")
  }

  private func normalizedFixture() throws -> (String, CastDocument) {
    let text = try TestFixture.roleManifestCastMD.contents()
    let document = try parser.parse(content: text)
    XCTAssertEqual(try parser.generate(document: document), text, "fixture must be normalized")
    return (text, document)
  }

  func testSettingRoleOnOneMemberChangesOnlyThatMembersLines() throws {
    let (text, original) = try normalizedFixture()
    var document = original
    let index = try XCTUnwrap(document.cast.firstIndex { $0.character == "JOSÉ" })
    document.cast[index].role = .guest

    let before = lines(text)
    let after = lines(try parser.generate(document: document))
    let (oldChanged, newChanged) = changedRanges(before, after)
    let oldMember = try XCTUnwrap(memberLineRange("JOSÉ", in: before))
    let newMember = try XCTUnwrap(memberLineRange("JOSÉ", in: after))

    XCTAssertFalse(newChanged.isEmpty)
    XCTAssertTrue(oldMember.contains(oldChanged.lowerBound) || oldChanged.isEmpty)
    XCTAssertLessThanOrEqual(oldChanged.upperBound, oldMember.upperBound)
    XCTAssertGreaterThanOrEqual(newChanged.lowerBound, newMember.lowerBound)
    XCTAssertLessThanOrEqual(newChanged.upperBound, newMember.upperBound)
    XCTAssertEqual(Array(after[newChanged]), ["  role: guest"])
  }

  func testAddingOneMemberChangesOnlyThatMembersLines() throws {
    let (text, original) = try normalizedFixture()
    var document = original
    document.cast.append(
      CastMember(
        character: "STATION AGENT", role: .costar,
        manifest: "characters/STATION AGENT.dossier/manifest.json"))

    let before = lines(text)
    let after = lines(try parser.generate(document: document))
    let (oldChanged, newChanged) = changedRanges(before, after)
    let newMember = try XCTUnwrap(memberLineRange("STATION AGENT", in: after))

    XCTAssertTrue(oldChanged.isEmpty, "no existing line changed: \(before[oldChanged])")
    XCTAssertEqual(newChanged, newMember)
  }

  func testRemovingOneMemberChangesOnlyThatMembersLines() throws {
    let (text, original) = try normalizedFixture()
    var document = original
    document.cast.removeAll { $0.character == "GUARD #2" }

    let before = lines(text)
    let after = lines(try parser.generate(document: document))
    let (oldChanged, newChanged) = changedRanges(before, after)
    let oldMember = try XCTUnwrap(memberLineRange("GUARD #2", in: before))

    XCTAssertTrue(newChanged.isEmpty, "no line was added: \(after[newChanged])")
    XCTAssertEqual(oldChanged, oldMember)
  }
}
