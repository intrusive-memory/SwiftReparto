//
//  CastMember+Merging.swift
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

/// The single source of truth for matching two `character` names as "the same
/// role" (RQ-14).
///
/// This exists so `merging(_:)` and any future lookup share one definition
/// rather than two that quietly drift. It is used **for matching only** — the
/// normalized string is never stored anywhere and never written back into a
/// `CastMember`. The `character` field a caller reads back is always exactly
/// the bytes some real document carried, never this function's output.
///
/// ## Definition
///
/// Two names match when, after the following transform, they are equal:
///
/// 1. Split the string on any run of one or more Unicode whitespace
///    characters — this includes ordinary spaces, tabs, newlines, and
///    non-breaking space (U+00A0), all of which fall under
///    `CharacterSet.whitespacesAndNewlines`.
/// 2. Drop empty pieces produced by leading/trailing whitespace, and rejoin
///    the remaining pieces with a single ASCII space. This simultaneously
///    trims the ends and collapses internal runs: `"THE  PRACTITIONER"` (two
///    spaces) and `"THE PRACTITIONER"` (one) both normalize to
///    `"the practitioner"`, as does a name with a leading/trailing tab or a
///    stray non-breaking space.
/// 3. Lowercase the result, so `"narrator"` and `"NARRATOR"` match.
///
/// Nothing here canonicalizes Unicode form (e.g. NFC/NFD) or strips
/// diacritics — only whitespace shape and case are normalized.
func normalizedCastMemberMatchKey(_ character: String) -> String {
  character
    .components(separatedBy: .whitespacesAndNewlines)
    .filter { !$0.isEmpty }
    .joined(separator: " ")
    .lowercased()
}

extension Array where Element == CastMember {

  /// Additively merges `discovered` members into the receiver (RQ-14).
  ///
  /// This exists to prevent one specific, already-observed failure:
  /// Produciesta's `CastWriter` rebuilds a roster from the *current
  /// screenplay's* discovered characters and discards anything absent from
  /// it. Run against a project-wide `CAST.md`, that would drop 11 of 12
  /// characters in a single write — along with their hand-written `bio`,
  /// their `voicePrompt`, and every `.vox` pointer those prompts produced.
  /// `merging(_:)` is the alternative: it can only add, never remove, and it
  /// can only fill gaps, never clobber a field a human already set.
  ///
  /// ## Matching
  ///
  /// A `discovered` member is matched to a receiver member when their
  /// `character` values are equal under ``normalizedCastMemberMatchKey(_:)``
  /// — case- and whitespace-insensitive. `"narrator"` matches `"NARRATOR"`;
  /// `"THE  PRACTITIONER"` (two spaces) matches `"THE PRACTITIONER"` (one).
  ///
  /// ## What happens on a match — gap-filling, not a no-op
  ///
  /// The receiver's member is returned with every field it already has
  /// **untouched**: an existing `voicePrompt`, `bio`, `actor`, `gender`,
  /// `language`, a `voices` entry for a provider it already carries, or any
  /// other `extraKeys` entry is never overwritten by the discovered version,
  /// no matter what that version holds.
  ///
  /// A field the receiver's member does **not** have, but the matched
  /// `discovered` member does, is filled in from `discovered`. This applies
  /// per-field for `actor`/`gender`/`language`/`voicePrompt`, per-provider for
  /// `voices` (a provider key absent from the receiver is added; a provider
  /// key the receiver already has is left exactly as it is, even if
  /// `discovered` carries different paths for that same provider — a shared
  /// provider is never overwritten, only a *new* provider is a gap), and
  /// per-key for `extraKeys`.
  ///
  /// This reading — gap-filling rather than strict pass-through — is what
  /// makes `merging(_:)` useful on the import path from `PROJECT.md`: a
  /// hand-maintained `CAST.md` that is missing a field a fresher
  /// `PROJECT.md` happens to carry gains that field instead of staying
  /// permanently blank. It does not weaken the no-overwrite guarantee in any
  /// way — a field the receiver already set is never revisited.
  ///
  /// The stored `character` on a matched result is always the receiver's,
  /// byte for byte. It is never replaced by `discovered`'s spelling and never
  /// replaced by the normalized matching key.
  ///
  /// ## What happens when there is no match
  ///
  /// The `discovered` member is appended, in `discovered` order, after every
  /// receiver member — carrying its own `character` value exactly as
  /// `discovered` provided it.
  ///
  /// ## Guarantee
  ///
  /// `result.count >= self.count` always. Members are only ever added to the
  /// receiver's list; none is ever removed, replaced, or reordered. Pruning a
  /// roster is a consumer's own explicit, flagged operation — never a side
  /// effect of this function.
  ///
  /// - Parameter discovered: Members found by some other process (e.g. a
  ///   `PROJECT.md` import, or a screenplay scan). Never mutated; the
  ///   receiver decides what, if anything, it accepts from each one.
  /// - Returns: The receiver's members, each backfilled with any field it was
  ///   missing, followed by every unmatched `discovered` member in its
  ///   original order.
  public func merging(_ discovered: [CastMember]) -> [CastMember] {
    var result = self

    var indexByKey: [String: Int] = [:]
    indexByKey.reserveCapacity(result.count)
    for (index, member) in result.enumerated() {
      indexByKey[normalizedCastMemberMatchKey(member.character)] = index
    }

    for candidate in discovered {
      let key = normalizedCastMemberMatchKey(candidate.character)
      if let index = indexByKey[key] {
        result[index] = result[index].backfilled(from: candidate)
      } else {
        result.append(candidate)
        indexByKey[key] = result.count - 1
      }
    }

    return result
  }
}

extension CastMember {

  /// Returns a copy of `self` with any field it lacks filled in from
  /// `discovered`, never overwriting a field `self` already has.
  ///
  /// This is the per-member policy `merging(_:)` applies on a match. `self`'s
  /// `character` is always preserved verbatim — this function never reads
  /// `discovered.character` into the result.
  fileprivate func backfilled(from discovered: CastMember) -> CastMember {
    var merged = self

    if merged.actor == nil {
      merged.actor = discovered.actor
    }
    if merged.gender == nil {
      merged.gender = discovered.gender
    }
    if merged.language == nil {
      merged.language = discovered.language
    }
    if merged.voicePrompt == nil {
      merged.voicePrompt = discovered.voicePrompt
    }

    // Per-provider gap-fill: a provider the receiver already has is left
    // exactly as it is, even if `discovered` carries different paths for it.
    // Only a provider absent from the receiver counts as a gap.
    for (provider, paths) in discovered.voices where merged.voices[provider] == nil {
      merged.voices[provider] = paths
    }

    // `extraKeys` is `public private(set)` (D-8): reached only through
    // `subscript(extra:)` / `setExtra(_:forKey:)`, never by touching the
    // dictionary directly.
    for key in discovered.extraKeys.keys where merged[extra: key] == nil {
      merged.setExtra(discovered[extra: key], forKey: key)
    }

    return merged
  }
}
