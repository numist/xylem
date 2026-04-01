// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import XMLCore

// MARK: - AttributeView

/// A scoped, non-copyable cursor onto a single attribute.
///
/// Obtained from a ``NodeView`` via ``NodeView/attribute(at:)``. Its lifetime
/// is bounded by the same document as the `NodeView` it came from.
public struct AttributeView: ~Copyable, ~Escapable {
  private let storage: Span<XML.Byte>
  private let record: Document.Attribute

  @_lifetime(copy storage)
  internal init(_ record: Document.Attribute, storage: borrowing Span<XML.Byte>) {
    self.record = record
    self.storage = copy storage
  }

  @inline(__always)
  @_lifetime(borrow self)
  private func span(_ slice: Document.Slice) -> Span<XML.Byte> {
    storage.extracting(slice.range)
  }

  /// The qualified name of the attribute.
  public var name: XML.QualifiedNameView {
    @_lifetime(borrow self) get {
      XML.QualifiedNameView(unvalidated: storage,
                            range: SourceRange(record.name.spelling.range),
                            colon: record.colon >= 0 ? Int(record.colon) : nil)
    }
  }

  /// The normalised attribute value.
  public var value: Span<XML.Byte> {
    @_lifetime(borrow self) get { span(record.value) }
  }

  /// The namespace URI of the attribute, or `nil` if the attribute is in no
  /// namespace.
  public var namespace: Span<XML.Byte>? {
    @_lifetime(borrow self) get {
      guard record.namespace.present else { return nil }
      return storage.extracting(record.namespace.range)
    }
  }
}
