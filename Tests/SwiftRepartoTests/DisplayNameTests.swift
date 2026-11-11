// DisplayNameTests.swift
// SwiftRepartoTests
//
// `CastMember.displayName` (RP-1 to RP-4, RP-6). Synthetic data only.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class DisplayNameTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  private func document(_ memberYAML: String) -> String {
    "---\ntype: cast\nschemaVersion: 1\ncast:\n\(memberYAML)---\n\nBody.\n"
  }

  func testDefaultsToNil() {
    XCTAssertNil(CastMember(character: "ALPHA").displayName)
  }

  func testDecodesWhenPresent() throws {
    let parsed = try parser.parse(
      content: document("  - character: ALPHA\n    displayName: Alpha Prime\n"))
    XCTAssertEqual(parsed.cast.first?.displayName, "Alpha Prime")
  }

  func testDecodesAsNilWhenAbsent() throws {
    let parsed = try parser.parse(content: document("  - character: ALPHA\n"))
    XCTAssertNil(parsed.cast.first?.displayName)
  }

  func testEmptyStringStaysEmpty() throws {
    let parsed = try parser.parse(
      content: document("  - character: ALPHA\n    displayName: ''\n"))
    XCTAssertEqual(parsed.cast.first?.displayName, "")
    let emitted = try parser.generate(document: parsed)
    XCTAssertEqual(try parser.parse(content: emitted).cast.first?.displayName, "")
  }

  func testValueIsNotTrimmedOrRecased() throws {
    let parsed = try parser.parse(
      content: document("  - character: ALPHA\n    displayName: '  mIxEd Case  '\n"))
    XCTAssertEqual(parsed.cast.first?.displayName, "  mIxEd Case  ")
  }

  func testDisplayNameIsNotCapturedInExtraKeys() throws {
    let parsed = try parser.parse(
      content: document("  - character: ALPHA\n    displayName: Alpha Prime\n    note: kept\n"))
    let member = try XCTUnwrap(parsed.cast.first)
    XCTAssertNil(member[extra: "displayName"])
    XCTAssertEqual(member.extraKeys.keys.sorted(), ["note"])
  }

  func testNilDisplayNameIsOmittedFromOutput() throws {
    let emitted = try parser.generate(
      document: CastDocument(cast: [CastMember(character: "ALPHA")], body: ""))
    XCTAssertFalse(emitted.contains("displayName"))
  }

  func testEncodesAfterManifestAndBeforeSortedExtras() throws {
    var member = CastMember(
      character: "ALPHA", manifest: "characters/ALPHA.dossier/manifest.json",
      displayName: "Alpha Prime")
    member.setExtra(try AnyCodable("x"), forKey: "aardvark")
    let emitted = try parser.generate(document: CastDocument(cast: [member], body: ""))
    let manifestAt = try XCTUnwrap(emitted.range(of: "manifest:")).lowerBound
    let displayAt = try XCTUnwrap(emitted.range(of: "displayName:")).lowerBound
    let extraAt = try XCTUnwrap(emitted.range(of: "aardvark:")).lowerBound
    XCTAssertLessThan(manifestAt, displayAt)
    XCTAssertLessThan(displayAt, extraAt)
  }

  /// A document emitted by 0.2.1, where `displayName` was an undeclared extra
  /// and so followed `manifest`, round-trips to the same bytes (N-4).
  func testZeroTwoOneDocumentWithDisplayNameAsOnlyExtraRoundTripsByteIdentical() throws {
    // Reproduce 0.2.1's emission: there `displayName` could only be an extra.
    var member = CastMember(
      character: "ALPHA", manifest: "characters/ALPHA.dossier/manifest.json")
    member.setExtra(try AnyCodable("Alpha Prime"), forKey: "displayName")
    let legacy = try parser.generate(document: CastDocument(cast: [member], body: "Body.\n"))
    let reparsed = try parser.parse(content: legacy)
    XCTAssertEqual(reparsed.cast.first?.displayName, "Alpha Prime")
    XCTAssertEqual(sha256(try parser.generate(document: reparsed)), sha256(legacy))
  }

  func testMergeKeepsReceiversDisplayName() {
    let receiver = [CastMember(character: "ALPHA", displayName: "Mine")]
    let discovered = [CastMember(character: "ALPHA", displayName: "Theirs")]
    XCTAssertEqual(receiver.merging(discovered).first?.displayName, "Mine")
  }

  func testMergeFillsNilDisplayName() {
    let receiver = [CastMember(character: "ALPHA")]
    let discovered = [CastMember(character: "ALPHA", displayName: "Theirs")]
    XCTAssertEqual(receiver.merging(discovered).first?.displayName, "Theirs")
  }
}
