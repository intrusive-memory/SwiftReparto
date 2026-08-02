// swift-tools-version: 6.2

import PackageDescription

// SwiftReparto is a leaf package (RQ-INV-1): it declares no dependency on any
// first-party org package, and never will. That is what makes every consumer
// relationship acyclic by construction rather than by discipline.
//
// Because there are no first-party dependencies here, the org's local-checkout
// development helper is deliberately absent from this manifest — there is
// nothing for it to resolve against. Do not add it.
//
// Exactly two dependencies, and the split between them is load-bearing:
//   * Yams                  — YAML coding, used only by the `SwiftReparto`
//                             library target (D-1).
//   * swift-argument-parser — CLI plumbing, used only by `RepartoCLICore`
//                             (D-6).
//
// `ArgumentParser` must never appear in the `SwiftReparto` target's dependency
// list. A consumer that only wants to read a cast list should not link an
// argument parser to do it.

let package = Package(
  name: "SwiftReparto",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),
  ],
  products: [
    .library(
      name: "SwiftReparto",
      targets: ["SwiftReparto"]
    ),
    .executable(
      name: "reparto",
      targets: ["reparto"]
    ),
    // `RepartoCLICore` is deliberately NOT a product (D-6). It exists so
    // command logic is unit-testable without spawning a subprocess, and so
    // that nothing becomes public API by accident. Consumers get the library
    // and the binary, and nothing else.
  ],
  dependencies: [
    .package(url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "6.2.2")),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
  ],
  targets: [
    .target(
      name: "SwiftReparto",
      dependencies: [
        .product(name: "Yams", package: "Yams")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "RepartoCLICore",
      dependencies: [
        "SwiftReparto",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(
      name: "reparto",
      dependencies: [
        "RepartoCLICore"
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftRepartoTests",
      dependencies: [
        "SwiftReparto",
        "RepartoCLICore",
      ],
      // `.copy`, never `.process` (Sortie 13). The fixtures under `Fixtures/`
      // are the SHA-256 anchors for WU-4's acceptance gates, and a resource
      // rule entitled to transform a file — re-encoding it, stripping a BOM,
      // normalizing line endings — would launder away exactly the bytes under
      // test. `.copy` preserves the directory (and every fixture's bytes)
      // verbatim inside the test bundle, reachable through `Bundle.module`.
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
