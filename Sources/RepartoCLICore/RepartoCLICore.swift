// RepartoCLICore.swift
// RepartoCLICore
//
// Command implementations for the `reparto` executable, kept in a library
// target so they are unit-testable without spawning a subprocess, and so that
// `ArgumentParser` never lands on the `SwiftReparto` library target (D-6).
//
// This target is deliberately not a product: consumers get the `SwiftReparto`
// library and the `reparto` binary, and nothing here becomes public API by
// accident.
//
// The binary is a shell over the library. It parses no YAML, splits no front
// matter, and builds no markdown — it calls into SwiftReparto and does nothing
// else, which is what keeps RQ-INV-2's one-writer rule true with a CLI in the
// picture.
//
// Placeholder only. The `validate` and `import` commands arrive in WU-5.

/// Namespace for the `reparto` command implementations.
///
/// Empty by design until WU-5 fills it in; it exists now so the target, the
/// product, and the release pipeline have something real to build.
public enum RepartoCLI {
  /// Entry point invoked by the `reparto` executable target.
  ///
  /// Does nothing until WU-5 wires up `validate` and `import`.
  public static func main() {}
}
