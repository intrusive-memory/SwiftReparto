//
//  Gender.swift
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

// Ported verbatim from `SwiftProyecto/Sources/SwiftProyecto/Models/CastMember.swift:32`
// (RQ-2). SwiftProyecto has zero references to this type outside its own
// defining file, so `CAST.md`'s owner is where it belongs. The four raw values
// are the wire format and must not change: `M`, `F`, `NB`, `NS`.

/// Gender specification for character roles.
///
/// Used to specify the expected or preferred gender for a character role,
/// or to indicate that gender is not a factor for the role.
public enum Gender: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
  /// Male
  case male = "M"

  /// Female
  case female = "F"

  /// Non-binary
  case nonBinary = "NB"

  /// Not specified - role doesn't depend on character's gender
  case notSpecified = "NS"

  /// Display name for UI presentation
  public var displayName: String {
    switch self {
    case .male: return "Male"
    case .female: return "Female"
    case .nonBinary: return "Non-Binary"
    case .notSpecified: return "Not Specified"
    }
  }
}
