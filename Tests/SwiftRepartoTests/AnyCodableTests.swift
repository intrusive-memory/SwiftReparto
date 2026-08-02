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

  // MARK: - Sortie 5a: null support

  func testBareNullDecodesAndReencodesAsNull() throws {
    let nullJSON = Data("null".utf8)
    let decoded = try JSONDecoder().decode(AnyCodable.self, from: nullJSON)
    XCTAssertTrue(decoded.isNull)

    let reencoded = try JSONEncoder().encode(decoded)
    XCTAssertEqual(String(data: reencoded, encoding: .utf8), "null")
  }

  func testDictionaryWithNullValueRoundTrip() throws {
    let json = Data(#"{"note": null}"#.utf8)
    let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)
    XCTAssertEqual(decoded.count, 1)
    XCTAssertEqual(decoded["note"]?.isNull, true)

    let wrapped = try AnyCodable(decoded)
    let reencodedData = try JSONEncoder().encode(wrapped)
    let roundTripped = try JSONDecoder().decode([String: AnyCodable].self, from: reencodedData)
    XCTAssertEqual(roundTripped.count, 1)
    XCTAssertEqual(roundTripped["note"]?.isNull, true)
  }

  func testArrayWithNullInPositionRoundTrip() throws {
    let json = Data(#"[1, null, "x"]"#.utf8)
    let decoded = try JSONDecoder().decode([AnyCodable].self, from: json)
    XCTAssertEqual(decoded.count, 3)
    XCTAssertEqual(try decoded[0].decode(Int.self), 1)
    XCTAssertTrue(decoded[1].isNull)
    XCTAssertEqual(try decoded[2].decode(String.self), "x")

    let wrapped = try AnyCodable(decoded)
    let reencodedData = try JSONEncoder().encode(wrapped)
    let roundTripped = try JSONDecoder().decode([AnyCodable].self, from: reencodedData)
    XCTAssertEqual(roundTripped.count, 3)
    XCTAssertEqual(try roundTripped[0].decode(Int.self), 1)
    XCTAssertTrue(roundTripped[1].isNull)
    XCTAssertEqual(try roundTripped[2].decode(String.self), "x")
  }

  func testThreeLevelNestedDictionaryWithNullAtDeepestLevelRoundTrip() throws {
    let json = Data(#"{"level1":{"level2":{"level3":null,"other":"value"}}}"#.utf8)
    let decoded = try JSONDecoder().decode([String: AnyCodable].self, from: json)

    let level1 = try decoded["level1"]?.decode([String: AnyCodable].self)
    let level2 = try level1?["level2"]?.decode([String: AnyCodable].self)
    XCTAssertEqual(level2?["level3"]?.isNull, true)
    XCTAssertEqual(try level2?["other"]?.decode(String.self), "value")

    let wrapped = try AnyCodable(decoded)
    let reencodedData = try JSONEncoder().encode(wrapped)
    let roundTripped = try JSONDecoder().decode([String: AnyCodable].self, from: reencodedData)

    let rtLevel1 = try roundTripped["level1"]?.decode([String: AnyCodable].self)
    let rtLevel2 = try rtLevel1?["level2"]?.decode([String: AnyCodable].self)
    XCTAssertEqual(rtLevel2?["level3"]?.isNull, true)
    XCTAssertEqual(try rtLevel2?["other"]?.decode(String.self), "value")
  }

  func testIsNullTrueForNullFalseForOtherFalsyValues() throws {
    let nullValue = try JSONDecoder().decode(AnyCodable.self, from: Data("null".utf8))
    XCTAssertTrue(nullValue.isNull)

    XCTAssertFalse(try AnyCodable(false).isNull)
    XCTAssertFalse(try AnyCodable(0).isNull)
    XCTAssertFalse(try AnyCodable("").isNull)
    XCTAssertFalse(try AnyCodable([AnyCodable]()).isNull)
    XCTAssertFalse(try AnyCodable([String: AnyCodable]()).isNull)
  }

  func testNullNotEqualToOtherFalsyValues() throws {
    let nullValue = try JSONDecoder().decode(AnyCodable.self, from: Data("null".utf8))

    XCTAssertNotEqual(nullValue, try AnyCodable(false))
    XCTAssertNotEqual(nullValue, try AnyCodable(0))
    XCTAssertNotEqual(nullValue, try AnyCodable(""))
    XCTAssertNotEqual(nullValue, try AnyCodable([AnyCodable]()))
    XCTAssertNotEqual(nullValue, try AnyCodable([String: AnyCodable]()))
  }
}
