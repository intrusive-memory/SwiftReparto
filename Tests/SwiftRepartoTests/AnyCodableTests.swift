import Foundation
import SwiftReparto
import XCTest

/// Encode -> decode identity tests for the vendored `AnyCodable` (Sortie 5,
/// RQ-13). Each of the eight shapes named in the sortie plan gets exactly one
/// test function. The three-level nested dictionary is the load-bearing case:
/// SwiftProyecto issue #55 was a nested structure silently flattened through
/// `NSDictionary.description` instead of round-tripping through `Codable`.
final class AnyCodableTests: XCTestCase {

  /// A struct with an `Optional<AnyCodable>` slot. Standard `Codable`
  /// short-circuits a JSON `null` at the *container* level via
  /// `decodeIfPresent`/`decodeNil` before `AnyCodable.init(from:)` is ever
  /// invoked, which is the only shape in which this vendored type currently
  /// tolerates a `null` value. See the sortie report for why a bare or
  /// dictionary-valued `null` is not yet supported.
  private struct Slot: Codable, Equatable {
    let value: AnyCodable?
  }

  private func roundTrip(_ wrapped: AnyCodable) throws -> AnyCodable {
    let encoded = try JSONEncoder().encode(wrapped)
    return try JSONDecoder().decode(AnyCodable.self, from: encoded)
  }

  func testStringRoundTrip() throws {
    let wrapped = try AnyCodable("hello world")
    XCTAssertEqual(wrapped, try roundTrip(wrapped))
    XCTAssertEqual(try roundTrip(wrapped).decode(String.self), "hello world")
  }

  func testIntRoundTrip() throws {
    let wrapped = try AnyCodable(42)
    XCTAssertEqual(wrapped, try roundTrip(wrapped))
    XCTAssertEqual(try roundTrip(wrapped).decode(Int.self), 42)
  }

  func testDoubleRoundTrip() throws {
    let wrapped = try AnyCodable(3.14159)
    XCTAssertEqual(wrapped, try roundTrip(wrapped))
    XCTAssertEqual(try roundTrip(wrapped).decode(Double.self), 3.14159)
  }

  func testBoolRoundTrip() throws {
    let wrapped = try AnyCodable(true)
    XCTAssertEqual(wrapped, try roundTrip(wrapped))
    XCTAssertEqual(try roundTrip(wrapped).decode(Bool.self), true)
  }

  func testNullRoundTrip() throws {
    let original = Slot(value: nil)
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Slot.self, from: encoded)
    XCTAssertEqual(decoded, original)
    XCTAssertNil(decoded.value)
  }

  func testNestedArrayRoundTrip() throws {
    let array = try [AnyCodable(1), AnyCodable("two"), AnyCodable(3.0)]
    let wrapped = try AnyCodable(array)
    let decoded = try roundTrip(wrapped)
    XCTAssertEqual(wrapped, decoded)

    let recovered = try decoded.decode([AnyCodable].self)
    XCTAssertEqual(recovered.count, 3)
    XCTAssertEqual(try recovered[0].decode(Int.self), 1)
    XCTAssertEqual(try recovered[1].decode(String.self), "two")
    XCTAssertEqual(try recovered[2].decode(Double.self), 3.0)
  }

  func testNestedDictionaryRoundTrip() throws {
    let dict: [String: AnyCodable] = try [
      "a": AnyCodable(1),
      "b": AnyCodable("two"),
    ]
    let wrapped = try AnyCodable(dict)
    let decoded = try roundTrip(wrapped)
    XCTAssertEqual(wrapped, decoded)

    let recovered = try decoded.decode([String: AnyCodable].self)
    XCTAssertEqual(try recovered["a"]?.decode(Int.self), 1)
    XCTAssertEqual(try recovered["b"]?.decode(String.self), "two")
  }

  func testThreeLevelNestedDictionaryRoundTrip() throws {
    let level3: [String: AnyCodable] = try [
      "leaf": AnyCodable("deep value"),
      "count": AnyCodable(3),
    ]
    let level2: [String: AnyCodable] = try [
      "level3": AnyCodable(level3),
      "flag": AnyCodable(true),
    ]
    let level1: [String: AnyCodable] = try [
      "level2": AnyCodable(level2),
      "name": AnyCodable("root"),
    ]

    let wrapped = try AnyCodable(level1)
    let decoded = try roundTrip(wrapped)

    // The identity assertion the exit criteria require: the whole three-level
    // structure compares equal after a full encode/decode cycle.
    XCTAssertEqual(wrapped, decoded)

    // Walk back down to the leaf to prove nothing was flattened or dropped
    // along the way (SwiftProyecto issue #55).
    let recoveredLevel1 = try decoded.decode([String: AnyCodable].self)
    let recoveredLevel2 = try recoveredLevel1["level2"]?.decode([String: AnyCodable].self)
    let recoveredLevel3 = try recoveredLevel2?["level3"]?.decode([String: AnyCodable].self)

    XCTAssertEqual(try recoveredLevel1["name"]?.decode(String.self), "root")
    XCTAssertEqual(try recoveredLevel2?["flag"]?.decode(Bool.self), true)
    XCTAssertEqual(try recoveredLevel3?["leaf"]?.decode(String.self), "deep value")
    XCTAssertEqual(try recoveredLevel3?["count"]?.decode(Int.self), 3)
  }
}
