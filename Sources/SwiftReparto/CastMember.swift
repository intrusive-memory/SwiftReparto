//
//  CastMember.swift
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

/// One entry in a `CAST.md` roster: a character, plus whatever is known about
/// who plays them and how they sound.
///
/// The field set is REQUIREMENTS.md §3.2. Everything the schema does not
/// declare is swept into ``extraKeys`` on decode and re-emitted verbatim on
/// encode (RQ-4), which is how a hand-written `bio:` note survives every write
/// by every consumer in the ecosystem.
///
/// ## `appearance:` is deliberately absent, and that costs no data
///
/// There is no `Appearance` type in this beta and no `appearance` case in
/// ``CodingKeys``. This is D-3, and it is a deferral, not an omission: the
/// shape SwiftSemblanzas needs (one `lora` path, or a list of adapters with
/// per-adapter rank, scale, and engine compatibility) is genuinely unscoped,
/// and shipping a guess in a released schema turns a cheap later addition into
/// an expensive change.
///
/// **Because `appearance` is not a declared key, an `appearance:` block in
/// existing data is swept into ``extraKeys`` and re-emitted verbatim — the
/// deferral costs no data.** Do not "fix" its absence by declaring it here.
/// When it is eventually declared, those keys move from ``extraKeys`` to a
/// typed field, which is a schema change and exactly what the document's
/// schema version exists to make tractable.
///
/// ## Decoding leniency (RQ-3)
///
/// Every form of this record that exists in the wild decodes:
///
/// - `voicePrompt:` (preferred) and the legacy `voiceDescription:` alias.
/// - `voices:` with a provider mapped to a bare scalar (`voxalta: a.vox`) as
///   well as to an array. Emission always normalizes to the array form.
///
/// ## Example
///
/// ```swift
/// let narrator = CastMember(
///   character: "NARRATOR",
///   actor: "Tom Stovall",
///   gender: .male,
///   language: "en",
///   voicePrompt: "Deep authoritative British baritone.",
///   voices: ["voxalta": ["voices/NARRATOR.vox"]]
/// )
/// ```
public struct CastMember: Codable, Sendable, Equatable, Hashable, Identifiable {

  // MARK: - Declared fields (REQUIREMENTS.md §3.2)

  /// Character name, as it appears in a screenplay's CHARACTER cues.
  ///
  /// Example: `"NARRATOR"`, `"THE PRACTITIONER"`. Mutable so a character can
  /// be renamed without rebuilding the member.
  public var character: String

  /// Actor / voice-artist name. Credits and reference only — nothing in this
  /// library resolves it to anything.
  public var actor: String?

  /// Gender specification for the role. See ``Gender``.
  public var gender: Gender?

  /// Spoken language for this character's lines, as a BCP-47 tag (`"en"`,
  /// `"es-MX"`).
  ///
  /// When `nil`, a generator falls back to language inference. It must never
  /// silently force English.
  public var language: String?

  /// Prose description of the desired voice, consumed downstream by
  /// SwiftEchada to synthesize a `.vox` identity.
  ///
  /// This is the preferred Swift identifier and the preferred wire key (D-2).
  /// The wire format did not change when the Swift name did: SwiftProyecto
  /// already emitted the key `voicePrompt` while calling the property
  /// something else. A document carrying the legacy `voiceDescription:` key
  /// still decodes into this property and re-emits as `voicePrompt:`.
  public var voicePrompt: String?

  /// Deprecated Swift-side alias for ``voicePrompt`` (D-2).
  ///
  /// Both accessors are present so a consumer mid-migration can read *and*
  /// write through it while the compiler points at every call site. It is a
  /// Swift identifier only — it is not a ``CodingKeys`` case and it never
  /// appears in emitted output; the decoder handles the legacy wire key
  /// separately, in ``init(from:)``.
  ///
  /// **Removed in this package's next major release version.**
  @available(*, deprecated, renamed: "voicePrompt")
  public var voiceDescription: String? {
    get { voicePrompt }
    set { voicePrompt = newValue }
  }

  /// Voice pointers, keyed by provider.
  ///
  /// Keys are provider names (`"voxalta"`, `"apple"`, `"elevenlabs"`),
  /// lower-cased on decode so lookups cannot drift on case. Values are file
  /// paths relative to the directory containing `CAST.md` (RQ-6).
  ///
  /// A provider whose value is a bare scalar in the source document decodes to
  /// a one-element array; emission always writes the array form (RQ-3).
  ///
  /// This library carries these strings and nothing more. It does not resolve,
  /// validate, stat, or canonicalize them (RQ-7).
  public var voices: [String: [String]]

  /// Every per-member key the schema does not declare, preserved verbatim.
  ///
  /// `bio:` is the live case — it exists in production data, nothing in the
  /// ecosystem declares it, and it must survive every write by every consumer
  /// (RQ-4). An `appearance:` block rides the same path while that field is
  /// deferred (D-3).
  ///
  /// The setter is private on purpose (D-8). Nothing needs to replace this
  /// dictionary wholesale, and permitting it reintroduces the exact overwrite
  /// failure RQ-INV-2 exists to prevent: one assignment silently discarding
  /// every key the writer did not know about. Read through
  /// ``subscript(extra:)`` and write through ``setExtra(_:forKey:)``.
  public private(set) var extraKeys: [String: AnyCodable]

  /// Unique identifier, based on the character name.
  public var id: String { character }

  /// Create a cast member.
  public init(
    character: String,
    actor: String? = nil,
    gender: Gender? = nil,
    language: String? = nil,
    voicePrompt: String? = nil,
    voices: [String: [String]] = [:],
    extraKeys: [String: AnyCodable] = [:]
  ) {
    self.character = character
    self.actor = actor
    self.gender = gender
    self.language = language
    self.voicePrompt = voicePrompt
    self.voices = voices
    self.extraKeys = extraKeys
  }

  // MARK: - Undeclared-key access (D-8)

  /// Read an undeclared key by name.
  ///
  /// This is the public door onto ``extraKeys``, and it is deliberately the
  /// *only* read path a consumer needs: SwiftSemblanzas reads `bio` through
  /// it, and everything routed through the deferred `appearance` field arrives
  /// the same way.
  ///
  /// ```swift
  /// let bio = member[extra: "bio"]
  /// ```
  ///
  /// - Parameter key: The undeclared key's name, exactly as it appears in the
  ///   source document.
  /// - Returns: The preserved value, or `nil` if the document carried no such
  ///   key. A key present in the document with a `null` value returns a
  ///   non-`nil` ``AnyCodable`` whose `isNull` is `true` — absent and
  ///   explicitly null are different facts and this API keeps them apart.
  public subscript(extra key: String) -> AnyCodable? {
    extraKeys[key]
  }

  /// Write or remove a single undeclared key.
  ///
  /// One key at a time, by name, so a writer can never discard extras it did
  /// not know about (D-8).
  ///
  /// - Parameters:
  ///   - value: The value to store, or `nil` to remove the key entirely. Note
  ///     that removing a key and storing a null value are different
  ///     operations with different emitted output.
  ///   - key: The undeclared key's name.
  public mutating func setExtra(_ value: AnyCodable?, forKey key: String) {
    extraKeys[key] = value
  }

  // MARK: - Convenience

  /// Whether at least one voice pointer is assigned.
  public var hasVoices: Bool {
    !voices.isEmpty
  }

  /// Whether a non-empty actor name is assigned.
  public var hasActor: Bool {
    actor != nil && !(actor?.isEmpty ?? true)
  }

  /// The first voice pointer recorded for a provider, if any.
  ///
  /// Provider lookup is case-insensitive, matching the lower-casing applied on
  /// decode.
  ///
  /// - Parameter provider: Provider name, e.g. `"voxalta"`.
  /// - Returns: The first pointer for that provider, or `nil`.
  public func voice(for provider: String) -> String? {
    voices[provider.lowercased()]?.first
  }

  /// Provider names that have voice pointers assigned, sorted alphabetically.
  public var providers: [String] {
    Array(voices.keys).sorted()
  }

  // MARK: - Hashable

  /// Hashes the character name only.
  ///
  /// Equality is structural (synthesized across every stored property), so a
  /// name-only hash is coarse but consistent: equal members always share a
  /// character name and therefore always hash alike. A structural hash is not
  /// available because ``AnyCodable`` is `Equatable` but not `Hashable`.
  public func hash(into hasher: inout Hasher) {
    hasher.combine(character)
  }

  // MARK: - Codable

  /// The declared wire keys, in emission order.
  ///
  /// Declaration order is load-bearing: ``encode(to:)`` writes these in this
  /// order and then appends ``extraKeys`` sorted lexicographically, which is
  /// what makes emitted output byte-stable across runs. `[String: AnyCodable]`
  /// iteration order is not stable, and an intermittent hash mismatch under
  /// RQ-11's SHA-256 gate reads as a corruption bug rather than as an ordering
  /// bug.
  ///
  /// `legacyVoiceDescription` carries the raw value `voiceDescription`: it is
  /// a *wire* key this decoder accepts, not a property. It must stay in
  /// `allCases` so the undeclared-key sweep below does not capture it into
  /// ``extraKeys`` and re-emit it alongside `voicePrompt`.
  ///
  /// There is deliberately no `appearance` case (D-3) — see the type's
  /// documentation.
  enum CodingKeys: String, CodingKey, CaseIterable {
    case character
    case actor
    case gender
    case language
    case voicePrompt
    case legacyVoiceDescription = "voiceDescription"
    case voices
  }

  /// Dynamic key used to enumerate and re-emit keys the schema does not
  /// declare.
  ///
  /// This is the mechanism RQ-4 depends on, ported from
  /// `SwiftProyecto/Sources/SwiftProyecto/Models/CastMember.swift:438-451`.
  private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
      self.stringValue = stringValue
      self.intValue = nil
    }

    init?(intValue: Int) {
      self.stringValue = "\(intValue)"
      self.intValue = intValue
    }
  }

  /// Decodes a member, applying every RQ-3 leniency and capturing every
  /// undeclared key (RQ-4).
  ///
  /// This is the mechanism ``CodingKeys``' and ``DynamicCodingKey``'s
  /// documentation both describe: `voicePrompt` and legacy `voiceDescription`
  /// land in the same property, a scalar `voices` provider becomes a
  /// one-element array, and anything not named above — `bio:`, a deferred
  /// `appearance:` block — is swept into ``extraKeys`` rather than discarded.
  ///
  /// - Parameter decoder: The decoder to read a cast member from.
  /// - Throws: `DecodingError` if `character` is missing or any declared
  ///   field has the wrong shape.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    character = try container.decode(String.self, forKey: .character)
    actor = try container.decodeIfPresent(String.self, forKey: .actor)
    gender = try container.decodeIfPresent(Gender.self, forKey: .gender)
    language = try container.decodeIfPresent(String.self, forKey: .language)

    // RQ-3: accept `voicePrompt` (preferred) and `voiceDescription` (legacy).
    // Both land in the same property, and only `voicePrompt` is ever emitted.
    voicePrompt =
      try container.decodeIfPresent(String.self, forKey: .voicePrompt)
      ?? container.decodeIfPresent(String.self, forKey: .legacyVoiceDescription)

    // RQ-3: accept both shapes of a provider's value.
    // - scalar:  { voxalta: "a.vox" }   -> { "voxalta": ["a.vox"] }
    // - array:   { voxalta: ["a.vox"] } -> used as-is
    // Decoding never rejects the scalar; emission always normalizes to array.
    var decodedVoices: [String: [String]] = [:]
    if let voicesContainer = try container.decodeIfPresent(
      [String: AnyCodable].self, forKey: .voices)
    {
      for (provider, value) in voicesContainer {
        let lowercaseProvider = provider.lowercased()

        if let arrayValue = try? value.decode([String].self) {
          decodedVoices[lowercaseProvider] = arrayValue
        } else if let stringValue = try? value.decode(String.self) {
          decodedVoices[lowercaseProvider] = [stringValue]
        }
      }
    }
    voices = decodedVoices

    // Capture every key the schema does not declare so user-maintained content
    // (a `bio:` note, an `appearance:` block) is preserved rather than
    // destroyed on the next write-back (RQ-4, D-3).
    let knownKeys = Set(CodingKeys.allCases.map { $0.stringValue })
    let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKey.self)
    var capturedExtras: [String: AnyCodable] = [:]
    for key in dynamicContainer.allKeys where !knownKeys.contains(key.stringValue) {
      capturedExtras[key.stringValue] = try dynamicContainer.decode(AnyCodable.self, forKey: key)
    }
    extraKeys = capturedExtras
  }

  /// Encodes a member with deterministic, byte-stable key order.
  ///
  /// Declared fields are written in ``CodingKeys``' declaration order, the
  /// legacy `voiceDescription` alias is never written (only `voicePrompt`
  /// is), `voices` is always written in array form with providers sorted,
  /// and ``extraKeys`` is appended last, sorted lexicographically. This
  /// exact order is what RQ-11's SHA-256 gate depends on — see
  /// ``CodingKeys``'s documentation for why it cannot come from
  /// `sortKeys = true` at the YAML layer instead.
  ///
  /// - Parameter encoder: The encoder to write this member to.
  /// - Throws: `EncodingError` if some value cannot be represented.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(character, forKey: .character)
    try container.encodeIfPresent(actor, forKey: .actor)
    try container.encodeIfPresent(gender, forKey: .gender)
    try container.encodeIfPresent(language, forKey: .language)

    // The legacy alias is accepted on the way in and never written on the way
    // out — a document decoded from `voiceDescription:` re-emits as
    // `voicePrompt:` and carries no `voiceDescription` key at all.
    try container.encodeIfPresent(voicePrompt, forKey: .voicePrompt)

    // Always the array form, never the scalar the decoder tolerates (RQ-3).
    // Written through a nested keyed container over the sorted provider keys,
    // mirroring the extraKeys loop below: a plain `container.encode(voices,
    // forKey: .voices)` emits in Swift's Dictionary iteration order, which is
    // seeded per process and not even stable between two dictionaries holding
    // the same keys within one process, and RQ-11's SHA-256 gate would fail
    // intermittently otherwise. Per-provider path arrays are encoded as-is —
    // that order is data, not incidental, and only the provider keys are
    // sorted. `voices.isEmpty` still opens and closes the nested container, so
    // a member with no voices still emits `voices: {}` unchanged.
    //
    // The `do` block is load-bearing, not stylistic: Yams' `_ReferencingEncoder`
    // (the object backing a `nestedContainer`) writes itself into the parent
    // mapping only when it is deallocated, not when `nestedContainer(forKey:)`
    // is called. Left inline in this function's top-level scope,
    // `voicesContainer` would stay alive — and `voices` therefore stay
    // unwritten in the parent mapping — until `encode(to:)` returns, which is
    // after the `extraKeys` block below runs and writes its own keys first.
    // That reordered `voices` to the end, after every extra key, which is
    // exactly the byte instability this fix exists to remove. Scoping the
    // container to this block forces it to deallocate — and therefore commit
    // `voices` into the parent mapping in this position — before `extraKeys`
    // gets its turn.
    do {
      var voicesContainer = container.nestedContainer(
        keyedBy: DynamicCodingKey.self, forKey: .voices)
      for provider in voices.keys.sorted() {
        guard let paths = voices[provider] else { continue }
        try voicesContainer.encode(paths, forKey: DynamicCodingKey(stringValue: provider))
      }
    }

    // Re-emit preserved undeclared keys so round-trips are lossless (RQ-4).
    // Sorted, because dictionary iteration order is not stable across runs and
    // RQ-11's SHA-256 gate would fail intermittently otherwise.
    if !extraKeys.isEmpty {
      var dynamicContainer = encoder.container(keyedBy: DynamicCodingKey.self)
      for key in extraKeys.keys.sorted() {
        guard let value = extraKeys[key] else { continue }
        try dynamicContainer.encode(value, forKey: DynamicCodingKey(stringValue: key))
      }
    }
  }
}
