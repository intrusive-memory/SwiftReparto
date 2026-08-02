// RejectionFixtureTests.swift
// SwiftRepartoTests
//
// Sortie 15: the seven pinned rejection fixtures under `Fixtures/`, each
// proving a *specific* `CastParseError` case (REQUIREMENTS.md §8 acceptance
// criterion 8, RQ-1, RQ-12, D-12).
//
// Every assertion here compares the thrown error against a named
// `CastParseError` case — with its payload, where the case has one — via
// `XCTAssertEqual` on the typed error. None of them merely proves that
// *something* was thrown: a parser that threw the wrong typed error for the
// wrong reason must fail these tests exactly as surely as a parser that threw
// nothing at all.
//
// The fixtures are reached exclusively through `TestFixture` /
// `Bundle.module` (Sortie 13's rule): nothing here names a path outside the
// package, and nothing here writes under `Fixtures/`.
//
// The import is plain, not `@testable`: `CastParseError` is public API and
// these tests exercise it exactly as a real caller would.

import Foundation
import SwiftReparto
import XCTest

final class RejectionFixtureTests: XCTestCase {

  private let parser = CastMarkdownParser()

  /// Parses `fixture` and asserts it throws exactly `expected` — the specific
  /// `CastParseError` case, compared by `==`, never merely "threw something."
  private func assertRejected(
    _ fixture: TestFixture,
    throws expected: CastParseError,
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let content = try fixture.contents()
    XCTAssertThrowsError(try parser.parse(content: content), file: file, line: line) { error in
      XCTAssertEqual(error as? CastParseError, expected, file: file, line: line)
    }
  }

  // MARK: - Task 1: `type: cast` present, `cast:` absent -> CastParseError.missingCastKey

  func testTypeOnlyFixtureThrowsMissingCastKey() throws {
    try assertRejected(.rejectTypeOnly, throws: CastParseError.missingCastKey)
  }

  // MARK: - Task 2: `cast:` present, `type:` absent -> CastParseError.missingTypeCast

  func testCastOnlyFixtureThrowsMissingTypeCast() throws {
    try assertRejected(.rejectCastOnly, throws: CastParseError.missingTypeCast)
  }

  // MARK: - Task 3: neither key, real front matter -> CastParseError.missingTypeCast

  /// The arbitrary-prose case RQ-1's dual check exists to reject: real,
  /// plausible front-matter keys (`title`, `author`, `date`), but neither
  /// `type:` nor `cast:`.
  func testNeitherKeyFixtureThrowsMissingTypeCast() throws {
    try assertRejected(.rejectNeither, throws: CastParseError.missingTypeCast)
  }

  // MARK: - Task 4: no front matter at all -> CastParseError.noFrontMatter

  func testNoFrontMatterFixtureThrowsNoFrontMatter() throws {
    try assertRejected(.rejectNoFrontMatter, throws: CastParseError.noFrontMatter)
  }

  // MARK: - Task 5: delimiters present, contents not valid YAML -> CastParseError.invalidYAML

  /// Only the case is pinned, not the parser's own message text — the
  /// underlying YAML library owns the wording, and RQ-12's contract is the
  /// case, not the string.
  func testMalformedYAMLFixtureThrowsInvalidYAML() throws {
    let content = try TestFixture.rejectMalformedYAML.contents()
    XCTAssertThrowsError(try parser.parse(content: content)) { error in
      guard case CastParseError.invalidYAML(let message)? = error as? CastParseError else {
        return XCTFail("expected CastParseError.invalidYAML, got \(error)")
      }
      XCTAssertFalse(message.isEmpty)
    }
  }

  // MARK: - Task 6: a member lacking `character` -> CastParseError.missingCharacter(index: 0)

  func testMissingCharacterFixtureThrowsMissingCharacterAtIndexZero() throws {
    try assertRejected(.rejectMissingCharacter, throws: CastParseError.missingCharacter(index: 0))
  }

  // MARK: - Task 7: `schemaVersion: 2` -> CastParseError.unsupportedSchemaVersion(found: 2, supported: 1)

  /// Otherwise well-formed (`type: cast`, a real `cast:` array), proving the
  /// version gate fires on a document that would otherwise parse, not on one
  /// that was doomed anyway (D-12, supervisor directive C).
  func testFutureVersionFixtureThrowsUnsupportedSchemaVersion() throws {
    try assertRejected(
      .rejectFutureVersion,
      throws: CastParseError.unsupportedSchemaVersion(
        found: 2, supported: CastSchemaVersion.current))
  }

  // MARK: - Positive control (supervisor directive G / §8 criterion 8's boundary)

  /// `type: cast` with `cast: []` is the boundary RQ-12 exists to draw: it is
  /// a *successful* parse of an empty roster, not a rejection. Placed
  /// adjacent to the rejection suite on purpose, so the "not a cast document"
  /// / "empty cast document" distinction is visible in one file. Reuses an
  /// inline string rather than a new fixture, per directive G.
  func testEmptyCastArrayIsASuccessfulParseNotARejection() throws {
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
  }
}
