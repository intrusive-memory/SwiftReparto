// CastMarkdownParserTests.swift
// SwiftRepartoTests
//
// Sortie 9 tests for `CastMarkdownParser`.
//
// Two things are asserted here that nothing else in the suite can assert:
//
//   1. THE BODY IS BYTES. Every body assertion compares `Array(body.utf8)`
//      against `Array(expected.utf8)`, never `body == expected`. Swift's `==`
//      on `String` compares under Unicode canonical equivalence, and a CRLF
//      body and an LF body are *not* equal under it — but a string comparison
//      still reads as the weaker claim, and the requirement (RQ-8) is stated in
//      bytes. Asserting in bytes is asserting the requirement.
//
//   2. RELATIVIZATION IS PURE STRING WORK. The absolute paths below are built
//      from the same URL the parser is handed, so no test here depends on
//      whether the temporary directory is reached through a symlink. That is
//      the point of RQ-7: nothing resolves anything.
//
// The import is plain, not `@testable`. `relativizingPaths(in:to:)` is
// internal and is asserted through `parse(fileURL:)`, which is the only way a
// consumer reaches it.

import Foundation
import SwiftReparto
import XCTest

final class CastMarkdownParserTests: XCTestCase {

  private let parser = CastMarkdownParser()

  // MARK: - Temporary files

  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = URL.temporaryDirectory.appending(
      path: "SwiftRepartoTests-\(UUID().uuidString)",
      directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }

  /// Writes `content` as `CAST.md` in a fresh temporary directory.
  ///
  /// Written as `Data`, not through a `String` file API, so the bytes on disk
  /// are exactly the bytes the test wrote.
  private func writeCastFile(_ content: String) throws -> URL {
    let directory = try makeTemporaryDirectory()
    let fileURL = directory.appending(path: "CAST.md")
    try Data(content.utf8).write(to: fileURL)
    return fileURL
  }

  // MARK: - Assertions

  private func assertBody(
    _ document: CastDocument,
    isExactly expected: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      Array(document.body.utf8),
      Array(expected.utf8),
      "body bytes differ; got \(Array(document.body.utf8))",
      file: file,
      line: line)
  }

  private func assertThrows(
    _ expected: CastParseError,
    _ expression: @autoclosure () throws -> CastDocument,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try expression(), file: file, line: line) { error in
      XCTAssertEqual(error as? CastParseError, expected, file: file, line: line)
    }
  }

  // MARK: - The happy path

  func testParsesAMinimalDocument() throws {
    let document = try parser.parse(
      content: """
        ---
        type: cast
        schemaVersion: 1
        cast:
          - character: NARRATOR
            actor: Tom Stovall
        ---
        # Notes
        """)

    XCTAssertEqual(document.schemaVersion, 1)
    XCTAssertEqual(document.cast.count, 1)
    XCTAssertEqual(document.cast[0].character, "NARRATOR")
    XCTAssertEqual(document.cast[0].actor, "Tom Stovall")
    assertBody(document, isExactly: "# Notes")
  }

  func testUndeclaredKeysSurviveTheParse() throws {
    let document = try parser.parse(
      content: """
        ---
        type: cast
        cast:
          - character: NARRATOR
            bio: Recorded in one take.
        ---
        """)

    XCTAssertEqual(try document.cast[0][extra: "bio"]?.decode(String.self), "Recorded in one take.")
  }

  func testDocumentWithoutSchemaVersionIsUnversionedRatherThanInvalid() throws {
    let document = try parser.parse(
      content: """
        ---
        type: cast
        cast: []
        ---
        """)

    XCTAssertTrue(document.isUnversioned)
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.unversioned)
  }

  /// The exit criterion in full: `cast: []` is a document, not a failure.
  func testEmptyCastArrayParsesToAnEmptyRosterAndDoesNotThrow() throws {
    let document = try parser.parse(
      content: """
        ---
        type: cast
        schemaVersion: 1
        cast: []
        ---
        # Nobody yet
        """)

    XCTAssertEqual(document.cast, [])
    assertBody(document, isExactly: "# Nobody yet")
  }

  func testParserIsSendable() {
    func requireSendable<Value: Sendable>(_: Value.Type) {}
    requireSendable(CastMarkdownParser.self)
  }

  // MARK: - Byte-exact body preservation (RQ-8, D-10)

  func testCRLFLineEndingsInTheBodySurviveAsCRLF() throws {
    let content = "---\r\ntype: cast\r\ncast: []\r\n---\r\n# Notes\r\n\r\nRecorded in one take.\r\n"
    let document = try parser.parse(content: content)

    assertBody(document, isExactly: "# Notes\r\n\r\nRecorded in one take.\r\n")

    // Stated a second way, so the assertion cannot pass on a body that merely
    // compares equal: the carriage returns are physically present.
    let bytes = Array(document.body.utf8)
    XCTAssertEqual(bytes.filter { $0 == 0x0D }.count, 3)
    XCTAssertEqual(bytes.filter { $0 == 0x0A }.count, 3)
  }

  func testBodyWithNoTrailingNewlineKeepsNone() throws {
    let content = "---\ntype: cast\ncast: []\n---\n# Notes\n\nNo newline after this."
    let document = try parser.parse(content: content)

    assertBody(document, isExactly: "# Notes\n\nNo newline after this.")
    XCTAssertNotEqual(Array(document.body.utf8).last, 0x0A)
  }

  func testBodyWithATrailingNewlineKeepsExactlyOne() throws {
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n# Notes\n")
    assertBody(document, isExactly: "# Notes\n")
  }

  func testBodyIsEmptyWhenTheFileEndsAtTheClosingDelimiter() throws {
    let withNewline = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n")
    assertBody(withNewline, isExactly: "")

    let withoutNewline = try parser.parse(content: "---\ntype: cast\ncast: []\n---")
    assertBody(withoutNewline, isExactly: "")
  }

  func testBodyThatIsASingleNewlineIsPreserved() throws {
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n\n")
    assertBody(document, isExactly: "\n")
  }

  func testLeadingBlankLinesInTheBodyAreNotTrimmed() throws {
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n\n\n   # Notes\n")
    assertBody(document, isExactly: "\n\n   # Notes\n")
  }

  func testTrailingWhitespaceInTheBodyIsNotTrimmed() throws {
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n# Notes   \n\t\n")
    assertBody(document, isExactly: "# Notes   \n\t\n")
  }

  /// The classic way a naive splitter loses data: the body carries delimiters
  /// of its own. Only the *first* `---` after the opening one closes the front
  /// matter; every byte past its terminator is content.
  func testBodyContainingItsOwnDelimiterSurvivesByteExactly() throws {
    let body = "# Notes\n\n---\n\nAn example of front matter:\n\n---\ntype: cast\n---\n"
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n" + body)

    assertBody(document, isExactly: body)
    XCTAssertEqual(document.cast, [])
  }

  func testBodyContainingAHorizontalRuleSurvivesByteExactly() throws {
    let body = "# Notes\n\n----\n\nAnd a longer one:\n\n--------\n"
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n" + body)
    assertBody(document, isExactly: body)
  }

  func testMixedLineEndingsAreNotNormalizedInEitherDirection() throws {
    let body = "# Notes\r\nLF line\nCRLF line\r\n"
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n" + body)
    assertBody(document, isExactly: body)
  }

  func testNonASCIIBodyBytesAreUnchanged() throws {
    let body = "# Notas\n\nJosé — grabado de una sola toma. 🎙\n"
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---\n" + body)
    assertBody(document, isExactly: body)
  }

  func testDelimiterLineWithTrailingWhitespaceStillCloses() throws {
    let document = try parser.parse(content: "---\ntype: cast\ncast: []\n---  \n# Notes\n")
    assertBody(document, isExactly: "# Notes\n")
    XCTAssertEqual(document.cast, [])
  }

  // MARK: - Typed errors (RQ-12)

  func testNoFrontMatterWhenTheContentDoesNotBeginWithADelimiter() {
    assertThrows(.noFrontMatter, try parser.parse(content: "# Notes\n\nJust markdown.\n"))
  }

  func testNoFrontMatterWhenTheContentIsEmpty() {
    assertThrows(.noFrontMatter, try parser.parse(content: ""))
  }

  func testNoFrontMatterWhenTheDelimiterIsNotOnTheFirstLine() {
    assertThrows(
      .noFrontMatter,
      try parser.parse(content: "\n---\ntype: cast\ncast: []\n---\n"))
  }

  func testNoFrontMatterWhenTheClosingDelimiterIsMissing() {
    assertThrows(.noFrontMatter, try parser.parse(content: "---\ntype: cast\ncast: []\n"))
  }

  func testNoFrontMatterWhenTheOpeningDelimiterIsTheWholeFile() {
    assertThrows(.noFrontMatter, try parser.parse(content: "---"))
  }

  func testNoFrontMatterWhenTheOpeningLineIsAHorizontalRule() {
    assertThrows(.noFrontMatter, try parser.parse(content: "----\ntype: cast\ncast: []\n----\n"))
  }

  func testInvalidYAMLCarriesTheParsersOwnMessage() {
    XCTAssertThrowsError(
      try parser.parse(content: "---\ntype: cast\ncast: [a, b\n---\n# Notes\n")
    ) { error in
      guard case .invalidYAML(let message)? = error as? CastParseError else {
        return XCTFail("expected .invalidYAML, got \(error)")
      }
      XCTAssertFalse(message.isEmpty)
    }
  }

  func testMissingTypeCastWhenTheDocumentDeclaresNoType() {
    assertThrows(.missingTypeCast, try parser.parse(content: "---\ncast: []\n---\n"))
  }

  /// RQ-1's actual motivation: a `PROJECT.md` carrying a `cast:` key is not a
  /// cast document, and must not be rewritten as one.
  func testMissingTypeCastWhenTheDocumentIsAProject() {
    assertThrows(
      .missingTypeCast,
      try parser.parse(
        content: """
          ---
          type: project
          cast:
            - character: NARRATOR
          ---
          """))
  }

  func testMissingCastKeyWhenTheKeyIsAbsent() {
    assertThrows(.missingCastKey, try parser.parse(content: "---\ntype: cast\n---\n"))
  }

  /// A bare, valueless `cast:` resolves to null. That is not a roster, and it
  /// is deliberately a different answer from `cast: []`.
  func testMissingCastKeyWhenTheKeyIsValueless() {
    assertThrows(.missingCastKey, try parser.parse(content: "---\ntype: cast\ncast:\n---\n"))
  }

  func testMissingCharacterCarriesTheOffendingMemberIndex() {
    assertThrows(
      .missingCharacter(index: 1),
      try parser.parse(
        content: """
          ---
          type: cast
          cast:
            - character: NARRATOR
            - actor: Nobody In Particular
          ---
          """))
  }

  /// The regression test for the `CastParseError` passthrough added to
  /// `decodeYAML`: without it this arrives as a `DecodingError.dataCorrupted`
  /// with the real cause buried in `underlyingError`, and every assertion above
  /// that names a specific case fails.
  func testUnsupportedSchemaVersionIsRefusedWithBothNumbers() {
    assertThrows(
      .unsupportedSchemaVersion(found: 2, supported: CastSchemaVersion.current),
      try parser.parse(content: "---\ntype: cast\nschemaVersion: 2\ncast: []\n---\n"))
  }

  // MARK: - Path relativization (D-7, RQ-7)

  private func castFileContent(voicePath: String) -> String {
    """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: NARRATOR
        voices:
          voxalta:
            - \(voicePath)
    ---
    # Notes
    """
  }

  func testParseFileURLRelativizesAnAbsolutePathUnderTheFilesOwnDirectory() throws {
    let directory = try makeTemporaryDirectory()
    let fileURL = directory.appending(path: "CAST.md")
    let absolute = directory.appending(path: "voices/NARRATOR.vox").path(percentEncoded: false)
    try Data(castFileContent(voicePath: absolute).utf8).write(to: fileURL)

    let document = try parser.parse(fileURL: fileURL)

    XCTAssertEqual(document.cast[0].voices["voxalta"], ["voices/NARRATOR.vox"])
  }

  func testParseFileURLLeavesAnAbsolutePathOutsideTheDirectoryVerbatim() throws {
    let outside = "/Volumes/SwiftRepartoTests-elsewhere/voices/NARRATOR.vox"
    let fileURL = try writeCastFile(castFileContent(voicePath: outside))

    let document = try parser.parse(fileURL: fileURL)

    let path = try XCTUnwrap(document.cast[0].voices["voxalta"]?.first)
    XCTAssertEqual(path, outside)

    // No `../` chain is synthesized to reach it. Whether such a path would even
    // be meaningful depends on facts only the disk has, and RQ-7 forbids asking.
    XCTAssertFalse(path.contains(".."))
  }

  /// A sibling directory whose name *begins* with the base directory's name.
  /// The separator in the prefix is what stops this from matching.
  func testParseFileURLDoesNotRelativizeASiblingWithASharedNamePrefix() throws {
    let directory = try makeTemporaryDirectory()
    let fileURL = directory.appending(path: "CAST.md")
    let neighbor =
      directory
      .deletingLastPathComponent()
      .appending(path: directory.lastPathComponent + "-backup", directoryHint: .isDirectory)
      .appending(path: "voices/NARRATOR.vox")
      .path(percentEncoded: false)
    try Data(castFileContent(voicePath: neighbor).utf8).write(to: fileURL)

    let document = try parser.parse(fileURL: fileURL)

    XCTAssertEqual(document.cast[0].voices["voxalta"], [neighbor])
  }

  func testParseFileURLLeavesAlreadyRelativePathsUnchanged() throws {
    let fileURL = try writeCastFile(castFileContent(voicePath: "voices/NARRATOR.vox"))
    let document = try parser.parse(fileURL: fileURL)
    XCTAssertEqual(document.cast[0].voices["voxalta"], ["voices/NARRATOR.vox"])
  }

  /// `parse(content:)` has no directory, so it normalizes nothing — the same
  /// input that relativizes through `parse(fileURL:)` comes back untouched here.
  func testParseContentLeavesAnAbsolutePathVerbatim() throws {
    let directory = try makeTemporaryDirectory()
    let absolute = directory.appending(path: "voices/NARRATOR.vox").path(percentEncoded: false)

    let document = try parser.parse(content: castFileContent(voicePath: absolute))

    XCTAssertEqual(document.cast[0].voices["voxalta"], [absolute])
  }

  // MARK: - Reading from disk

  func testParseFileURLPreservesBodyBytesThroughTheFilesystem() throws {
    let body = "# Notes\r\n\r\nNo trailing newline."
    let fileURL = try writeCastFile("---\r\ntype: cast\r\ncast: []\r\n---\r\n" + body)

    let document = try parser.parse(fileURL: fileURL)

    assertBody(document, isExactly: body)
  }

  /// A missing file is not a statement about cast documents, so it is not a
  /// `CastParseError`.
  func testParseFileURLPropagatesTheReadErrorForAMissingFile() throws {
    let directory = try makeTemporaryDirectory()
    let missing = directory.appending(path: "CAST.md")

    XCTAssertThrowsError(try parser.parse(fileURL: missing)) { error in
      XCTAssertNil(error as? CastParseError)
    }
  }

  func testParseFileURLReportsMalformedContentAsACastParseError() throws {
    let fileURL = try writeCastFile("# Notes\n\nJust markdown.\n")
    assertThrows(.noFrontMatter, try parser.parse(fileURL: fileURL))
  }
}
