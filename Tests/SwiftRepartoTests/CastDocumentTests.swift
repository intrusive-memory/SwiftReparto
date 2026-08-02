// CastDocumentTests.swift
// SwiftRepartoTests
//
// Sortie 7 tests for `CastDocument` and `CastSchemaVersion`.
//
// These go through `JSONEncoder`/`JSONDecoder`, deliberately. The YAML layer is
// Sortie 8's and the markdown parser is Sortie 9's; asserting document
// semantics through machinery this sortie does not own would make a model bug
// and an encoder bug look identical. Everything asserted here is about how the
// type behaves when handed a `Decoder` — which decoder is beside the point.
//
// The import is plain, not `@testable`. Every guarantee below is one a
// consumer depends on, so every assertion is made through the surface a
// consumer has.

import Foundation
import SwiftReparto
import XCTest

final class CastDocumentTests: XCTestCase {

  // MARK: - Helpers

  private func decodeDocument(_ json: String) throws -> CastDocument {
    try JSONDecoder().decode(CastDocument.self, from: Data(json.utf8))
  }

  private func encodeDocumentAsObject(_ document: CastDocument) throws -> [String: Any] {
    let data = try JSONEncoder().encode(document)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - CastSchemaVersion (D-12)

  func testCurrentSchemaVersionIsTheIntegerOne() {
    XCTAssertEqual(CastSchemaVersion.current, 1)
  }

  func testUnversionedSentinelSortsBelowEveryRealVersion() {
    XCTAssertEqual(CastSchemaVersion.unversioned, 0)
    XCTAssertLessThan(CastSchemaVersion.unversioned, CastSchemaVersion.current)
  }

  func testFrontMatterKeyIsSchemaVersion() {
    XCTAssertEqual(CastSchemaVersion.key, "schemaVersion")
  }

  func testSupportPredicates() {
    XCTAssertTrue(CastSchemaVersion.isUnversioned(CastSchemaVersion.unversioned))
    XCTAssertFalse(CastSchemaVersion.isUnversioned(CastSchemaVersion.current))
    XCTAssertTrue(CastSchemaVersion.isSupported(CastSchemaVersion.unversioned))
    XCTAssertTrue(CastSchemaVersion.isSupported(CastSchemaVersion.current))
    XCTAssertFalse(CastSchemaVersion.isSupported(CastSchemaVersion.current + 1))
  }

  func testValidateAcceptsUnversionedAndCurrent() throws {
    XCTAssertNoThrow(try CastSchemaVersion.validate(CastSchemaVersion.unversioned))
    XCTAssertNoThrow(try CastSchemaVersion.validate(CastSchemaVersion.current))
  }

  func testValidateRejectsNewerWithTheTypedError() {
    XCTAssertThrowsError(try CastSchemaVersion.validate(2)) { error in
      XCTAssertEqual(
        error as? CastParseError,
        .unsupportedSchemaVersion(found: 2, supported: 1))
    }
  }

  // MARK: - Legacy input is accepted, not rejected (D-5)

  func testDocumentWithoutSchemaVersionCarriesTheUnversionedSentinel() throws {
    let document = try decodeDocument(#"{"type":"cast","cast":[]}"#)
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.unversioned)
    XCTAssertTrue(document.isUnversioned)
  }

  func testDocumentWithNullSchemaVersionCarriesTheUnversionedSentinel() throws {
    let document = try decodeDocument(#"{"type":"cast","schemaVersion":null,"cast":[]}"#)
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.unversioned)
    XCTAssertTrue(document.isUnversioned)
  }

  func testDocumentDeclaringTheCurrentVersionCarriesIt() throws {
    let document = try decodeDocument(#"{"type":"cast","schemaVersion":1,"cast":[]}"#)
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.current)
    XCTAssertFalse(document.isUnversioned)
  }

  /// Legacy in, current out: the sentinel never survives an emit (D-5).
  func testEmittingAnUnversionedDocumentStampsTheCurrentVersion() throws {
    let document = try decodeDocument(#"{"type":"cast","cast":[]}"#)
    let object = try encodeDocumentAsObject(document)
    XCTAssertEqual(object["schemaVersion"] as? Int, CastSchemaVersion.current)
  }

  /// The stamp does not depend on the in-memory value either — a hand-built
  /// document that claims to be unversioned still emits the current version.
  func testEmittingAlwaysStampsCurrentRegardlessOfTheStoredValue() throws {
    let document = CastDocument(
      cast: [CastMember(character: "NARRATOR")],
      body: "",
      schemaVersion: CastSchemaVersion.unversioned)
    let object = try encodeDocumentAsObject(document)
    XCTAssertEqual(object["schemaVersion"] as? Int, CastSchemaVersion.current)
  }

  // MARK: - Newer input is a typed rejection (D-12)

  func testDocumentDeclaringANewerVersionIsRejectedByCaseEquality() {
    XCTAssertThrowsError(
      try decodeDocument(#"{"type":"cast","schemaVersion":2,"cast":[]}"#)
    ) { error in
      XCTAssertEqual(
        error as? CastParseError,
        .unsupportedSchemaVersion(found: 2, supported: 1))
    }
  }

  func testTheRejectionReportsTheVersionActuallyFound() {
    XCTAssertThrowsError(
      try decodeDocument(#"{"type":"cast","schemaVersion":97,"cast":[]}"#)
    ) { error in
      XCTAssertEqual(
        error as? CastParseError,
        .unsupportedSchemaVersion(found: 97, supported: CastSchemaVersion.current))
    }
  }

  /// The version check runs before anything else, because a future schema may
  /// have redefined the keys this build would otherwise go on to interpret.
  func testTheVersionCheckPrecedesEveryOtherCheck() {
    XCTAssertThrowsError(try decodeDocument(#"{"schemaVersion":2}"#)) { error in
      XCTAssertEqual(
        error as? CastParseError,
        .unsupportedSchemaVersion(found: 2, supported: 1))
    }
  }

  // MARK: - RQ-1: the document must say what it is

  func testDocumentWithoutTypeThrowsMissingTypeCast() {
    XCTAssertThrowsError(try decodeDocument(#"{"cast":[]}"#)) { error in
      XCTAssertEqual(error as? CastParseError, .missingTypeCast)
    }
  }

  func testDocumentWithTheWrongTypeThrowsMissingTypeCast() {
    XCTAssertThrowsError(try decodeDocument(#"{"type":"project","cast":[]}"#)) { error in
      XCTAssertEqual(error as? CastParseError, .missingTypeCast)
    }
  }

  func testDocumentWithoutCastKeyThrowsMissingCastKey() {
    XCTAssertThrowsError(try decodeDocument(#"{"type":"cast"}"#)) { error in
      XCTAssertEqual(error as? CastParseError, .missingCastKey)
    }
  }

  func testDocumentWithNullCastThrowsMissingCastKey() {
    XCTAssertThrowsError(try decodeDocument(#"{"type":"cast","cast":null}"#)) { error in
      XCTAssertEqual(error as? CastParseError, .missingCastKey)
    }
  }

  // MARK: - RQ-12: "not a cast document" is not "an empty cast document"

  func testEmptyCastArrayParsesRatherThanThrowing() throws {
    let document = try decodeDocument(#"{"type":"cast","schemaVersion":1,"cast":[]}"#)
    XCTAssertEqual(document.cast, [])
  }

  func testMissingCharacterReportsTheOffendingMemberIndex() {
    let json = #"""
      {"type":"cast","schemaVersion":1,"cast":[
        {"character":"NARRATOR"},
        {"actor":"Tom Stovall"}
      ]}
      """#
    XCTAssertThrowsError(try decodeDocument(json)) { error in
      XCTAssertEqual(error as? CastParseError, .missingCharacter(index: 1))
    }
  }

  func testMissingCharacterOnTheFirstMemberReportsIndexZero() {
    let json = #"{"type":"cast","cast":[{"actor":"Tom Stovall"}]}"#
    XCTAssertThrowsError(try decodeDocument(json)) { error in
      XCTAssertEqual(error as? CastParseError, .missingCharacter(index: 0))
    }
  }

  // MARK: - Roster decoding

  func testMembersDecodeInDocumentOrder() throws {
    let json = #"""
      {"type":"cast","schemaVersion":1,"cast":[
        {"character":"NARRATOR"},
        {"character":"THE PRACTITIONER"}
      ]}
      """#
    let document = try decodeDocument(json)
    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR", "THE PRACTITIONER"])
  }

  // MARK: - `body` is not front matter

  func testDecodingLeavesBodyEmptyBecauseItIsNotFrontMatter() throws {
    let document = try decodeDocument(#"{"type":"cast","schemaVersion":1,"cast":[]}"#)
    XCTAssertEqual(document.body, "")
  }

  func testEncodingEmitsExactlyTheThreeFrontMatterKeys() throws {
    let document = CastDocument(
      cast: [CastMember(character: "NARRATOR")],
      body: "## Notes\r\n\r\nRecorded in one take.")
    let object = try encodeDocumentAsObject(document)
    XCTAssertEqual(Set(object.keys), ["type", "schemaVersion", "cast"])
  }

  func testEncodingNeverWritesTheBodyIntoTheFrontMatter() throws {
    let document = CastDocument(cast: [], body: "## Notes\n\nRecorded in one take.\n")
    let data = try JSONEncoder().encode(document)
    let text = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertFalse(text.contains("body"))
    XCTAssertFalse(text.contains("Recorded in one take"))
  }

  func testEncodingWritesTheDocumentTypeConstant() throws {
    let object = try encodeDocumentAsObject(CastDocument())
    XCTAssertEqual(object["type"] as? String, CastDocument.documentType)
    XCTAssertEqual(CastDocument.documentType, "cast")
  }

  // MARK: - Equatable is structural (Sortie 14's round-trip gate depends on it)

  func testEqualDocumentsCompareEqual() {
    let left = CastDocument(cast: [CastMember(character: "NARRATOR")], body: "x")
    let right = CastDocument(cast: [CastMember(character: "NARRATOR")], body: "x")
    XCTAssertEqual(left, right)
  }

  func testADifferenceInsideAMemberMakesDocumentsUnequal() {
    let left = CastDocument(cast: [CastMember(character: "NARRATOR", actor: "A")])
    let right = CastDocument(cast: [CastMember(character: "NARRATOR", actor: "B")])
    XCTAssertNotEqual(left, right)
  }

  func testADifferenceInAPreservedExtraKeyMakesDocumentsUnequal() throws {
    var member = CastMember(character: "NARRATOR")
    member.setExtra(try AnyCodable("a note"), forKey: "bio")
    let left = CastDocument(cast: [member])
    let right = CastDocument(cast: [CastMember(character: "NARRATOR")])
    XCTAssertNotEqual(left, right)
  }

  func testADifferenceInTheBodyMakesDocumentsUnequal() {
    let left = CastDocument(cast: [], body: "a\n")
    let right = CastDocument(cast: [], body: "a")
    XCTAssertNotEqual(left, right)
  }

  func testADifferenceInTheSchemaVersionMakesDocumentsUnequal() {
    let left = CastDocument(cast: [], schemaVersion: CastSchemaVersion.unversioned)
    let right = CastDocument(cast: [], schemaVersion: CastSchemaVersion.current)
    XCTAssertNotEqual(left, right)
  }

  // MARK: - Defaults

  func testDefaultInitializerProducesACurrentEmptyDocument() {
    let document = CastDocument()
    XCTAssertEqual(document.cast, [])
    XCTAssertEqual(document.body, "")
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.current)
    XCTAssertFalse(document.isUnversioned)
  }
}
