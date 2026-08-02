//
//  CastSchemaVersion.swift
//  SwiftReparto
//
//  Copyright (c) 2026 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// The `CAST.md` document schema version: a **monotonic integer starting at
/// 1** (D-12).
///
/// This namespace holds the three facts every consumer of the version needs —
/// the front-matter key, the version this build supports, and the sentinel
/// that stands for a document which declared no version at all — plus the two
/// predicates and the one throwing check that keep those facts from being
/// re-derived at each call site.
///
/// ## The version is an integer, and that is the whole point
///
/// It is not a string, not semver, and not this package's release version.
/// Three consequences follow, and each one is a bug that cannot happen:
///
/// - **Ordering is total and correct.** As strings, `1.10` sorts *before*
///   `1.9`; as integers, 10 is unambiguously newer than 9. The newer-than
///   check in ``isSupported(_:)`` is a plain `<=` on `Int` and needs no
///   comparator of its own.
/// - **There is no patch dimension to misuse.** A document schema either
///   changed or it did not. A three-component version invites a "patch" that
///   readers are expected to ignore, and the first time one of them does not
///   ignore it, documents diverge.
/// - **It cannot be mistaken for the package version.** Nothing here tracks
///   SwiftReparto's release number, and nothing should try to.
///
/// ## Legacy in, current out
///
/// A document with no version key is *legacy, not invalid* (D-5). It decodes
/// carrying ``unversioned`` and is stamped with ``current`` the next time it is
/// emitted, so hand-written files keep working and normalize on first write.
/// See ``CastDocument`` for where that happens.
///
/// ## Newer in, typed rejection out
///
/// A document declaring a version greater than ``current`` is refused with
/// ``CastParseError/unsupportedSchemaVersion(found:supported:)``, never parsed
/// best-effort. An older writer that *accepts* a newer document will
/// confidently rewrite it and drop every field it did not understand — RQ-INV-2
/// with a version number attached. A caller who wants best-effort behavior can
/// catch the typed error and decide for itself; a caller handed a silent lossy
/// parse has no such option.
public enum CastSchemaVersion {

  /// The schema version this build of SwiftReparto reads and writes.
  ///
  /// Emission always stamps this value (D-5, Sortie 10), regardless of what
  /// the source document declared.
  ///
  /// Bump it by exactly one whenever the front-matter shape changes in a way
  /// an older reader would misinterpret — declaring the deferred `appearance`
  /// field (D-3) is the change already on the books.
  public static let current: Int = 1

  /// The sentinel carried by a document that declared no version at all.
  ///
  /// Zero, and never a legal declared version: real versions are monotonic
  /// from 1 upward, so `unversioned < current` holds by ordinary integer
  /// ordering and no comparison site needs to special-case it. Prefer
  /// ``isUnversioned(_:)`` and ``CastDocument/isUnversioned`` over comparing
  /// against this constant directly.
  public static let unversioned: Int = 0

  /// The front-matter key this version is written under: `schemaVersion`.
  ///
  /// Qualified rather than a bare `version` on purpose (D-12) — the name says
  /// *which* thing is versioned, which was RQ-Q3's original objection to
  /// carrying a version field at all.
  public static let key: String = "schemaVersion"

  /// Whether a version is the legacy ``unversioned`` sentinel.
  ///
  /// - Parameter version: A version read from a document.
  /// - Returns: `true` when the document declared no version.
  public static func isUnversioned(_ version: Int) -> Bool {
    version == unversioned
  }

  /// Whether this build can safely read a document declaring `version`.
  ///
  /// Anything at or below ``current`` is readable, including the
  /// ``unversioned`` sentinel. Anything above it is not.
  ///
  /// - Parameter version: A version read from a document.
  /// - Returns: `true` when the version is at or below ``current``.
  public static func isSupported(_ version: Int) -> Bool {
    version <= current
  }

  /// Throws unless this build can safely read a document declaring `version`.
  ///
  /// This is the single place the newer-than check lives; decoding, parsing,
  /// and importing all route through it so the three cannot drift.
  ///
  /// - Parameter version: A version read from a document.
  /// - Throws: ``CastParseError/unsupportedSchemaVersion(found:supported:)``
  ///   when `version` is greater than ``current``.
  public static func validate(_ version: Int) throws {
    guard isSupported(version) else {
      throw CastParseError.unsupportedSchemaVersion(found: version, supported: current)
    }
  }
}
