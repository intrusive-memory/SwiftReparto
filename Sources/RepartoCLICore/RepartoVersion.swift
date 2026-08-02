//
//  RepartoVersion.swift
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
//

/// The single place `reparto --version`'s value is declared.
///
/// **Unprefixed by design.** The git tag is `v`-prefixed (`v0.1.0`,
/// per org convention); this constant is not. `release.yml` derives its
/// tarball name from `VERSION="${TAG#v}"`, so `reparto --version` printing
/// `0.1.0` is exactly the string embedded in
/// `reparto-0.1.0-arm64-macos.tar.gz` and exactly what SwiftPM's
/// `exact:` requirement takes. The single `v` lives in the tag and nowhere
/// else.
public enum RepartoVersion {

  /// The released version, without the tag's leading `v`.
  public static let current: String = "0.1.0"
}
