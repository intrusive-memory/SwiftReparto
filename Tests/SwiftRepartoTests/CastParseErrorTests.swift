// CastParseErrorTests.swift
// SwiftRepartoTests
//
// Sortie 7 tests for the error vocabulary RQ-12 defines.
//
// The whole point of `CastParseError` is that a caller can tell one failure
// from another, so these tests assert exactly that property and nothing softer:
// every case is pairwise distinguishable by `==`, and every case carries a
// non-empty `errorDescription` that no other case shares. A test that only
// checked "each case has a description" would pass with all six descriptions
// identical, which is the failure RQ-12 exists to prevent.
//
// The import is plain, not `@testable`: this vocabulary is public API that
// consumers switch over, and asserting on it through a testing-only door would
// prove nothing about the surface they actually get.

import Foundation
import SwiftReparto
import XCTest

final class CastParseErrorTests: XCTestCase {

  /// One instance of every case, which is the list the exhaustiveness of these
  /// tests depends on. Adding a case to `CastParseError` without adding it here
  /// leaves it untested — the compiler will not complain, so the switch below
  /// exists to make the omission loud.
  private static let allCases: [CastParseError] = [
    .noFrontMatter,
    .invalidYAML("mapping values are not allowed in this context at line 3"),
    .missingTypeCast,
    .missingCastKey,
    .missingCharacter(index: 0),
    .invalidRole(index: 0, value: "star"),
    .unsupportedSchemaVersion(found: 2, supported: 1),
  ]

  /// Fails if a case is added to `CastParseError` and not added to
  /// ``allCases``.
  ///
  /// The switch is exhaustive, so a new case breaks the build here rather than
  /// silently shipping untested. Update both this switch and ``allCases``.
  func testEveryCaseIsRepresentedInTheFixtureList() {
    for error in Self.allCases {
      switch error {
      case .noFrontMatter, .invalidYAML, .missingTypeCast, .missingCastKey,
        .missingCharacter, .invalidRole, .unsupportedSchemaVersion:
        continue
      }
    }
    XCTAssertEqual(Self.allCases.count, 7)
  }

  // MARK: - Distinguishability by `==`

  func testEveryCaseEqualsItself() {
    for error in Self.allCases {
      XCTAssertEqual(error, error, "\(error) should equal itself")
    }
  }

  func testEveryPairOfCasesIsDistinguishable() {
    let cases = Self.allCases
    for (leftIndex, left) in cases.enumerated() {
      for (rightIndex, right) in cases.enumerated() where leftIndex != rightIndex {
        XCTAssertNotEqual(
          left, right,
          "\(left) and \(right) must be distinguishable by == (RQ-12)")
      }
    }
  }

  // MARK: - Payloads participate in equality

  func testInvalidYAMLDistinguishesItsMessage() {
    XCTAssertEqual(CastParseError.invalidYAML("a"), .invalidYAML("a"))
    XCTAssertNotEqual(CastParseError.invalidYAML("a"), .invalidYAML("b"))
  }

  func testMissingCharacterDistinguishesItsIndex() {
    XCTAssertEqual(CastParseError.missingCharacter(index: 3), .missingCharacter(index: 3))
    XCTAssertNotEqual(CastParseError.missingCharacter(index: 0), .missingCharacter(index: 1))
  }

  func testInvalidRoleDistinguishesBothPayloads() {
    XCTAssertEqual(
      CastParseError.invalidRole(index: 1, value: "star"), .invalidRole(index: 1, value: "star"))
    XCTAssertNotEqual(
      CastParseError.invalidRole(index: 1, value: "star"), .invalidRole(index: 2, value: "star"))
    XCTAssertNotEqual(
      CastParseError.invalidRole(index: 1, value: "star"), .invalidRole(index: 1, value: "extra"))
  }

  func testUnsupportedSchemaVersionDistinguishesBothOperands() {
    XCTAssertEqual(
      CastParseError.unsupportedSchemaVersion(found: 2, supported: 1),
      .unsupportedSchemaVersion(found: 2, supported: 1))
    XCTAssertNotEqual(
      CastParseError.unsupportedSchemaVersion(found: 2, supported: 1),
      .unsupportedSchemaVersion(found: 3, supported: 1))
    XCTAssertNotEqual(
      CastParseError.unsupportedSchemaVersion(found: 2, supported: 1),
      .unsupportedSchemaVersion(found: 2, supported: 2))
  }

  // MARK: - `errorDescription`

  func testEveryCaseHasANonEmptyErrorDescription() {
    for error in Self.allCases {
      let description = error.errorDescription
      XCTAssertNotNil(description, "\(error) has no errorDescription")
      XCTAssertFalse(
        (description ?? "").isEmpty,
        "\(error) has an empty errorDescription")
    }
  }

  func testEveryCaseHasADistinctErrorDescription() {
    let descriptions = Self.allCases.compactMap { $0.errorDescription }
    XCTAssertEqual(descriptions.count, Self.allCases.count)
    XCTAssertEqual(
      Set(descriptions).count, descriptions.count,
      "Two cases share an errorDescription, which makes them indistinguishable in a log")
  }

  func testDescriptionsCarryTheirPayloads() {
    let yaml = CastParseError.invalidYAML("line 3, column 5").errorDescription ?? ""
    XCTAssertTrue(yaml.contains("line 3, column 5"))

    let member = CastParseError.missingCharacter(index: 7).errorDescription ?? ""
    XCTAssertTrue(member.contains("7"))

    let role = CastParseError.invalidRole(index: 5, value: "star").errorDescription ?? ""
    XCTAssertTrue(role.contains("5"))
    XCTAssertTrue(role.contains("star"))
    XCTAssertTrue(role.contains("underfive"), "lists the allowed roles")

    let version =
      CastParseError.unsupportedSchemaVersion(found: 4, supported: 1).errorDescription ?? ""
    XCTAssertTrue(version.contains("4"))
    XCTAssertTrue(version.contains("1"))
  }

  /// `LocalizedError` conformance is what makes `localizedDescription` useful.
  ///
  /// Without it, `(error as Error).localizedDescription` degrades to a generic
  /// "The operation couldn't be completed" string, and every caller that logs
  /// errors the ordinary way loses the vocabulary RQ-12 built.
  func testLocalizedDescriptionRoutesThroughErrorDescription() {
    for error in Self.allCases {
      let localized = (error as Error).localizedDescription
      XCTAssertEqual(localized, error.errorDescription)
    }
  }
}
