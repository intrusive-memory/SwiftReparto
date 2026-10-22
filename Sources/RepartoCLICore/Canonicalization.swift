//
//  Canonicalization.swift
//  RepartoCLICore
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

import Foundation
import SwiftReparto

/// What making a roster's names canonical would do (RQ-22).
///
/// Computed purely from ``SwiftReparto/CastMember/canonicalName(_:)``; nothing
/// here decides what a canonical name is. Shared by `canonicalize` (which
/// reports or applies it) and `import` (which must canonicalize), so the two
/// cannot disagree about a rename or a collision.
struct CanonicalizationPlan: Equatable {

  /// One member whose name would change.
  struct Rename: Equatable {
    let index: Int
    let from: String
    let to: String
  }

  /// One member whose name has no canonical form. It is left exactly as
  /// written — canonicalization never substitutes characters.
  struct Failure: Equatable {
    let index: Int
    let character: String
    let error: CharacterNameError
  }

  /// Two or more members that would end up with the same canonical name.
  struct Collision: Equatable {
    let canonical: String
    let characters: [String]
  }

  let renames: [Rename]
  let failures: [Failure]
  let collisions: [Collision]

  /// Plans canonicalization of `cast`, in roster order.
  init(for cast: [CastMember]) {
    var renames: [Rename] = []
    var failures: [Failure] = []
    var groups: [String: [String]] = [:]
    var groupOrder: [String] = []

    for (index, member) in cast.enumerated() {
      do throws(CharacterNameError) {
        let canonical = try CastMember.canonicalName(member.character)
        if canonical != member.character {
          renames.append(Rename(index: index, from: member.character, to: canonical))
        }
        if groups[canonical] == nil { groupOrder.append(canonical) }
        groups[canonical, default: []].append(member.character)
      } catch {
        failures.append(Failure(index: index, character: member.character, error: error))
      }
    }

    self.renames = renames
    self.failures = failures
    self.collisions = groupOrder.compactMap { canonical in
      guard let characters = groups[canonical], characters.count > 1 else { return nil }
      return Collision(canonical: canonical, characters: characters)
    }
  }

  /// `document` with every planned rename applied. Members with no canonical
  /// form are untouched.
  func applied(to document: CastDocument) -> CastDocument {
    var renamed = document
    for rename in renames {
      renamed.cast[rename.index].character = rename.to
    }
    return renamed
  }

  /// One warning line per member whose name has no canonical form.
  var failureWarnings: [String] {
    failures.map { failure in
      "warning: cast member \(failure.index) ('\(failure.character)') has no canonical name and "
        + "was left as written: \(failure.error.errorDescription ?? "\(failure.error)")"
    }
  }
}

/// Refusal to canonicalize because two members would share a name.
enum CanonicalizationError: Error, LocalizedError, Equatable {
  case collision([CanonicalizationPlan.Collision])

  var errorDescription: String? {
    switch self {
    case .collision(let collisions):
      let lines = collisions.map { collision in
        "  \(collision.canonical): "
          + collision.characters.map { "'\($0)'" }.joined(separator: ", ")
      }
      return
        "Refusing to canonicalize: these members would share a canonical name. "
        + "Merge or rename them by hand first.\n" + lines.joined(separator: "\n")
    }
  }
}
