// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

/// A half-open byte range within the original source document.
public struct SourceRange: Equatable {
  /// The underlying half-open range of byte indices.
  public let bounds: Range<Int>

  /// Creates a `SourceRange` wrapping `bounds`.
  public init(_ bounds: Range<Int>) {
    self.bounds = bounds
  }

  /// The first byte index included in the range.
  public var lowerBound: Int { bounds.lowerBound }

  /// The first byte index beyond the end of the range.
  public var upperBound: Int { bounds.upperBound }

  /// The number of bytes covered by the range.
  public var count: Int { bounds.count }

  /// `true` when the range covers zero bytes.
  public var isEmpty: Bool { bounds.isEmpty }

  /// Returns a copy of `self` shifted by `base.lowerBound`.
  ///
  /// Converts a range expressed relative to a sub-span (e.g. an attribute
  /// value slice) into an absolute position within the containing document.
  @inline(__always)
  public func absolute(in base: SourceRange) -> SourceRange {
    SourceRange(base.lowerBound + lowerBound ..< base.lowerBound + upperBound)
  }
}

package struct Located<Value>: ~Escapable where Value: ~Escapable {
  package let value: Value
  package let source: SourceRange
  package let processed: Bool

  @_lifetime(copy value)
  package init(value: consuming Value, source: SourceRange, processed: Bool = true) {
    self.value = consume value
    self.source = source
    self.processed = processed
  }
}
