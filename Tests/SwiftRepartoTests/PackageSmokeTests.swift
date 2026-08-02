// PackageSmokeTests.swift
// SwiftRepartoTests
//
// Sortie 1 smoke test. Its only job is to prove the package skeleton links and
// that Yams builds and round-trips under this package's floor — Swift 6.2
// tools, `.macOS(.v26)` / `.iOS(.v26)`, `swiftLanguageModes: [.v6]`, strict
// concurrency — on both macOS and the iOS Simulator, before any library code
// depends on it (AR-1).
//
// The `import Yams` here is temporary and deliberate. Sortie 8 replaces this
// file with the real coding tests, after which the only file permitted to
// import Yams is `Sources/SwiftReparto/YAMLCoding.swift`.

import Foundation
import XCTest
import Yams

import RepartoCLICore
import SwiftReparto

final class PackageSmokeTests: XCTestCase {

  /// A minimal `Codable` value that exercises the encoder and decoder on the
  /// shapes the cast schema actually uses: a scalar, an optional, and an array.
  private struct Probe: Codable, Equatable {
    var character: String
    var voicePrompt: String?
    var voices: [String]
  }

  // MARK: - AR-1: Yams builds and round-trips under this package's floor

  func testYamsEncodeDecodeRoundTrip() throws {
    let original = Probe(
      character: "THE PRACTITIONER",
      voicePrompt: "A measured voice: unhurried, precise.",
      voices: ["voices/practitioner.vox"]
    )

    let encoded = try YAMLEncoder().encode(original)
    let decoded = try YAMLDecoder().decode(Probe.self, from: encoded)

    XCTAssertEqual(decoded, original)
    XCTAssertFalse(encoded.isEmpty)
  }

  // MARK: - The package's own targets link

  func testTargetsLink() {
    // `SwiftReparto` is intentionally API-free at this point, so the assertion
    // that matters is that both modules import and link at all.
    RepartoCLI.main()
    XCTAssertTrue(true)
  }
}
