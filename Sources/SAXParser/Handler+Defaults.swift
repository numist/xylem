// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import XMLCore

extension Handler {
  public var location: XML.Location? {
    get { nil }
    set {}
  }

  public mutating func start(document: Void) throws(Failure) {}
  public mutating func end(document: Void) throws(Failure) {}

  public mutating func declaration(version: Span<XML.Byte>, encoding: Span<XML.Byte>?,
                                   standalone: Span<XML.Byte>?) throws(Failure) {}

  public mutating func processing(target: Span<XML.Byte>, data: Span<XML.Byte>?) throws(Failure) {}

  public mutating func comment(_ content: Span<XML.Byte>) throws(Failure) {}

  public mutating func characters(_ data: Span<XML.Byte>) throws(Failure) {}

  public mutating func character(data: Span<XML.Byte>) throws(Failure) {}

  public mutating func start(mapping prefix: Span<XML.Byte>?, uri: Span<XML.Byte>) throws(Failure) {}
  public mutating func end(mapping prefix: Span<XML.Byte>?) throws(Failure) {}

  public mutating func start(element name: XML.QualifiedNameView,
                             namespace uri: Span<XML.Byte>?,
                             attributes: XML.ResolvedAttributesView) throws(Failure) {}

  public mutating func end(element name: XML.QualifiedNameView,
                           namespace uri: Span<XML.Byte>?) throws(Failure) {}

  public mutating func start(dtd name: Span<XML.Byte>,
                             id: (public: Span<XML.Byte>?, system: Span<XML.Byte>?)) throws(Failure) {}

  public mutating func end(dtd: Void) throws(Failure) {}
}
