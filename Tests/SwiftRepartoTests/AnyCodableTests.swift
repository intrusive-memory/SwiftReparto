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

  // MARK: - Sortie 8a: an order-recording `Encoder`
  //
  // `JSONEncoder`, absent `.sortedKeys`, does not preserve keyed-container
  // encode-call order in its serialized output on this platform — verified
  // empirically while writing these tests: a set of `encode(forKey:)` calls
  // already made in sorted order by `AnyCodable` still came back out of
  // `JSONEncoder`'s JSON text in a third, different order, because
  // `JSONEncoder`'s keyed-container storage here is not order-preserving
  // without that flag. Forcing `.sortedKeys` on the *outer* encoder would
  // hide a regression rather than catch one: it reorders the final bytes
  // unconditionally, so it would report success even if `AnyCodable.encode(to:)`
  // stopped sorting and went back to handing the encoder a raw dictionary.
  //
  // What's actually under test is the *sequence* of `encode(_:forKey:)` calls
  // `AnyCodable.encode(to:)` makes — that is a property of `AnyCodable`
  // itself, independent of which real encoder eventually consumes it (Yams
  // preserves that call order, as `YAMLCoding.swift` documents; this
  // recorder exists so these tests do not have to take that on faith or
  // depend on Yams to prove it). It observes the call sequence directly by
  // implementing the minimum `Encoder` surface `AnyCodable.encode(to:)`
  // touches.

  private final class KeyOrderRecorder {
    /// One entry per `encode(_:forKey:)` call: the coding path leading to the
    /// container (dot-joined key strings) and the key encoded, in call order.
    private(set) var calls: [(path: String, key: String)] = []

    func record(path: [String], key: String) {
      calls.append((path: path.joined(separator: "."), key: key))
    }

    /// The keys recorded at a given coding path, in call order.
    func keys(atPath path: [String]) -> [String] {
      let joined = path.joined(separator: ".")
      return calls.filter { $0.path == joined }.map { $0.key }
    }
  }

  private struct RecordingIndexKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }

    init?(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = Int(stringValue)
    }
  }

  private struct RecordingEncoder: Encoder {
    let recorder: KeyOrderRecorder
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
      KeyedEncodingContainer(
        RecordingKeyedContainer<Key>(recorder: recorder, codingPath: codingPath))
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
      RecordingUnkeyedContainer(recorder: recorder, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
      RecordingSingleValueContainer(recorder: recorder, codingPath: codingPath)
    }
  }

  /// A keyed container that records every `encode(forKey:)` call and, for the
  /// generic (`Encodable`) overload `AnyCodable` actually uses, recurses into
  /// the value on a fresh `RecordingEncoder` scoped one level deeper — which
  /// is how a three-level-deep mapping gets observed at all three depths
  /// without any explicit depth tracking on the test's part.
  private struct RecordingKeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let recorder: KeyOrderRecorder
    var codingPath: [CodingKey]

    private var pathStrings: [String] { codingPath.map { $0.stringValue } }

    mutating func encodeNil(forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
      let nested = RecordingEncoder(recorder: recorder, codingPath: codingPath + [key])
      try value.encode(to: nested)
    }

    // Required by the protocol; never exercised by `AnyCodable`, which only
    // ever hands this container an `AnyCodable` (routed through the generic
    // overload above), never a bare primitive. Recorded for completeness.
    mutating func encode(_ value: Bool, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: String, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Double, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Float, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Int, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Int8, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Int16, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Int32, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: Int64, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: UInt, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: UInt8, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: UInt16, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: UInt32, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }
    mutating func encode(_ value: UInt64, forKey key: Key) throws {
      recorder.record(path: pathStrings, key: key.stringValue)
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
      keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
      KeyedEncodingContainer(
        RecordingKeyedContainer<NestedKey>(recorder: recorder, codingPath: codingPath + [key]))
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
      RecordingUnkeyedContainer(recorder: recorder, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
      RecordingEncoder(recorder: recorder, codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
      RecordingEncoder(recorder: recorder, codingPath: codingPath + [key])
    }
  }

  /// An unkeyed container that assigns each element an index-shaped coding
  /// path (`"0"`, `"1"`, ...) and recurses into it, so a mapping nested
  /// inside an array element is observed at its own path — this is what
  /// lets the array-of-mappings test assert each element's keys
  /// independently, while never sorting the elements themselves (this
  /// container has no notion of "sorted"; it only ever appends in call
  /// order, which is exactly the property under test).
  private struct RecordingUnkeyedContainer: UnkeyedEncodingContainer {
    let recorder: KeyOrderRecorder
    var codingPath: [CodingKey]
    var count: Int = 0

    mutating func encodeNil() throws { count += 1 }

    mutating func encode<T: Encodable>(_ value: T) throws {
      let nested = RecordingEncoder(
        recorder: recorder, codingPath: codingPath + [RecordingIndexKey(intValue: count)])
      count += 1
      try value.encode(to: nested)
    }

    mutating func encode(_ value: Bool) throws { count += 1 }
    mutating func encode(_ value: String) throws { count += 1 }
    mutating func encode(_ value: Double) throws { count += 1 }
    mutating func encode(_ value: Float) throws { count += 1 }
    mutating func encode(_ value: Int) throws { count += 1 }
    mutating func encode(_ value: Int8) throws { count += 1 }
    mutating func encode(_ value: Int16) throws { count += 1 }
    mutating func encode(_ value: Int32) throws { count += 1 }
    mutating func encode(_ value: Int64) throws { count += 1 }
    mutating func encode(_ value: UInt) throws { count += 1 }
    mutating func encode(_ value: UInt8) throws { count += 1 }
    mutating func encode(_ value: UInt16) throws { count += 1 }
    mutating func encode(_ value: UInt32) throws { count += 1 }
    mutating func encode(_ value: UInt64) throws { count += 1 }

    mutating func nestedContainer<NestedKey: CodingKey>(
      keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
      let container = KeyedEncodingContainer(
        RecordingKeyedContainer<NestedKey>(
          recorder: recorder, codingPath: codingPath + [RecordingIndexKey(intValue: count)]))
      count += 1
      return container
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
      let container = RecordingUnkeyedContainer(
        recorder: recorder, codingPath: codingPath + [RecordingIndexKey(intValue: count)])
      count += 1
      return container
    }

    mutating func superEncoder() -> Encoder {
      RecordingEncoder(recorder: recorder, codingPath: codingPath)
    }
  }

  /// A single-value container that simply forwards to a same-path
  /// `RecordingEncoder` for the generic (`Encodable`) case — this is the
  /// container `AnyCodable.encode(to:)` requests for scalars, `null`, and
  /// arrays, none of which involve key ordering, so nothing here records
  /// anything; it exists only so recursion through an array element that is
  /// itself an `AnyCodable` keeps working.
  private struct RecordingSingleValueContainer: SingleValueEncodingContainer {
    let recorder: KeyOrderRecorder
    var codingPath: [CodingKey]

    mutating func encodeNil() throws {}
    mutating func encode(_ value: Bool) throws {}
    mutating func encode(_ value: String) throws {}
    mutating func encode(_ value: Double) throws {}
    mutating func encode(_ value: Float) throws {}
    mutating func encode(_ value: Int) throws {}
    mutating func encode(_ value: Int8) throws {}
    mutating func encode(_ value: Int16) throws {}
    mutating func encode(_ value: Int32) throws {}
    mutating func encode(_ value: Int64) throws {}
    mutating func encode(_ value: UInt) throws {}
    mutating func encode(_ value: UInt8) throws {}
    mutating func encode(_ value: UInt16) throws {}
    mutating func encode(_ value: UInt32) throws {}
    mutating func encode(_ value: UInt64) throws {}

    mutating func encode<T: Encodable>(_ value: T) throws {
      let nested = RecordingEncoder(recorder: recorder, codingPath: codingPath)
      try value.encode(to: nested)
    }
  }

  // MARK: - Sortie 8a: byte-stability of nested mapping key order

  /// A nested mapping built by inserting keys in scrambled order re-encodes
  /// its keys sorted, regardless of the order they were inserted in.
  ///
  /// This is the direct regression test for the defect: `AnyCodable.encode(to:)`
  /// used to decode into `[String: AnyCodable]` and hand that dictionary to
  /// the encoder, which walks the dictionary's own (per-process-seeded)
  /// storage order rather than a deterministic one.
  func testNestedMappingWithScrambledInsertionOrderEmitsKeysSorted() throws {
    // Insertion order is neither declaration order nor sorted order, so a
    // pass-through of insertion order would fail this test too.
    let dict: [String: AnyCodable] = try [
      "zeta": AnyCodable(1),
      "alpha": AnyCodable(2),
      "mike": AnyCodable(3),
      "bravo": AnyCodable(4),
    ]
    let wrapped = try AnyCodable(dict)

    let recorder = KeyOrderRecorder()
    try wrapped.encode(to: RecordingEncoder(recorder: recorder, codingPath: []))

    XCTAssertEqual(
      recorder.keys(atPath: []),
      ["alpha", "bravo", "mike", "zeta"],
      "nested mapping did not emit keys in lexicographic order")

    // Sorting keys for byte order must not change the decoded value.
    let decoded = try roundTrip(wrapped)
    XCTAssertEqual(wrapped, decoded)
  }

  /// A three-level nested mapping is sorted at all three levels, not just the
  /// top one.
  ///
  /// Each level is built with scrambled insertion order. If sorting were only
  /// applied once (at the outermost `encode(to:)` call) rather than recursing
  /// naturally through nested `AnyCodable` values, the inner two levels would
  /// still leak dictionary storage order.
  func testThreeLevelNestedMappingIsSortedAtEveryLevel() throws {
    let level3: [String: AnyCodable] = try [
      "zulu": AnyCodable("z-value"),
      "delta": AnyCodable("d-value"),
      "charlie": AnyCodable("c-value"),
    ]
    let level2: [String: AnyCodable] = try [
      "whiskey": AnyCodable(level3),
      "foxtrot": AnyCodable("f-value"),
      "echo": AnyCodable("e-value"),
    ]
    let level1: [String: AnyCodable] = try [
      "tango": AnyCodable(level2),
      "bravo": AnyCodable("b-value"),
      "alpha": AnyCodable("a-value"),
    ]
    let wrapped = try AnyCodable(level1)

    let recorder = KeyOrderRecorder()
    try wrapped.encode(to: RecordingEncoder(recorder: recorder, codingPath: []))

    XCTAssertEqual(
      recorder.keys(atPath: []), ["alpha", "bravo", "tango"],
      "level 1 was not sorted")
    XCTAssertEqual(
      recorder.keys(atPath: ["tango"]), ["echo", "foxtrot", "whiskey"],
      "level 2 (nested under `tango`) was not sorted")
    XCTAssertEqual(
      recorder.keys(atPath: ["tango", "whiskey"]), ["charlie", "delta", "zulu"],
      "level 3 (nested under `tango.whiskey`) was not sorted")

    // Sorting keys for byte order must not change the decoded value: the
    // round trip still compares equal, and nothing was flattened or dropped.
    let decoded = try roundTrip(wrapped)
    XCTAssertEqual(wrapped, decoded)
    let recoveredLevel1 = try decoded.decode([String: AnyCodable].self)
    let recoveredLevel2 = try recoveredLevel1["tango"]?.decode([String: AnyCodable].self)
    let recoveredLevel3 = try recoveredLevel2?["whiskey"]?.decode([String: AnyCodable].self)
    XCTAssertEqual(try recoveredLevel1["alpha"]?.decode(String.self), "a-value")
    XCTAssertEqual(try recoveredLevel2?["echo"]?.decode(String.self), "e-value")
    XCTAssertEqual(try recoveredLevel3?["zulu"]?.decode(String.self), "z-value")
  }

  /// Array element order is preserved — sorting is a mapping-key rule only.
  ///
  /// An array of mappings exercises both rules in one shape: the array keeps
  /// its own (deliberately non-alphabetical) element order, while each
  /// mapping element is independently sorted.
  func testArrayElementOrderIsPreservedWhileElementMappingsAreSorted() throws {
    let firstElement: [String: AnyCodable] = try [
      "zeta": AnyCodable("z1"),
      "alpha": AnyCodable("a1"),
    ]
    let secondElement: [String: AnyCodable] = try [
      "yankee": AnyCodable("y2"),
      "bravo": AnyCodable("b2"),
    ]
    // Deliberately not alphabetical, and deliberately not the order the
    // dictionaries above were declared in, so a bug that sorted the array
    // itself (rather than leaving it alone) would be caught.
    let array = try [AnyCodable(secondElement), AnyCodable(firstElement)]
    let wrapped = try AnyCodable(array)

    let recorder = KeyOrderRecorder()
    try wrapped.encode(to: RecordingEncoder(recorder: recorder, codingPath: []))

    // Array element order preserved: element 0 is `secondElement`
    // (yankee/bravo), element 1 is `firstElement` (alpha/zeta) — the array
    // was never reordered even though its two mappings, individually, are
    // not in alphabetical order relative to each other.
    XCTAssertEqual(
      recorder.keys(atPath: ["0"]), ["bravo", "yankee"],
      "first array element's mapping was not sorted")
    XCTAssertEqual(
      recorder.keys(atPath: ["1"]), ["alpha", "zeta"],
      "second array element's mapping was not sorted")

    // Round trip still compares equal and preserves array order by value.
    let decoded = try roundTrip(wrapped)
    XCTAssertEqual(wrapped, decoded)
    let recovered = try decoded.decode([AnyCodable].self)
    XCTAssertEqual(recovered.count, 2)
    let recoveredFirst = try recovered[0].decode([String: AnyCodable].self)
    let recoveredSecond = try recovered[1].decode([String: AnyCodable].self)
    XCTAssertEqual(try recoveredFirst["yankee"]?.decode(String.self), "y2")
    XCTAssertEqual(try recoveredSecond["zeta"]?.decode(String.self), "z1")
  }
}
