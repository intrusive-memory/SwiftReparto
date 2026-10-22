//
//  CastRole.swift
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

// The seven raw values below are the wire format (RQ-19) and must not change.
// The pattern is `Gender`'s: a `String`-backed enum whose raw values are what
// `CAST.md` carries, with a separate `displayName` for presentation.

/// A cast member's casting tier (RQ-19).
///
/// The tiers follow the screen-acting categories a production already uses
/// to book performers. SwiftReparto carries the value and nothing more: what
/// assets each tier requires is SwiftSemblanzas' business (its §5.4), not this
/// library's.
///
/// Decoding is strict, exactly like ``Gender``: a value outside this set fails
/// the parse with ``CastParseError/invalidRole(index:value:)`` rather than
/// being carried as an unknown string.
public enum CastRole: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  /// Principal performer, series regular.
  case lead

  /// Principal, series regular or recurring.
  case supporting

  /// Principal, single-episode featured.
  case guest

  /// Voice-over principal.
  case narrator

  /// Principal, day performer.
  case costar

  /// SAG-AFTRA under-five: five lines or fewer.
  case underfive

  /// Background actor.
  case background

  /// Display name for UI presentation.
  public var displayName: String {
    switch self {
    case .lead: return "Lead"
    case .supporting: return "Supporting"
    case .guest: return "Guest Star"
    case .narrator: return "Narrator"
    case .costar: return "Co-Star"
    case .underfive: return "Under-Five"
    case .background: return "Background"
    }
  }

  /// Whether this tier belongs in the Major half of the `CAST.md` body's
  /// planned Major / Minor split (RQ-8).
  ///
  /// `true` for ``lead``, ``supporting``, ``guest`` and ``narrator``; `false`
  /// for ``costar``, ``underfive`` and ``background``.
  public var isMajor: Bool {
    switch self {
    case .lead, .supporting, .guest, .narrator: return true
    case .costar, .underfive, .background: return false
    }
  }
}
