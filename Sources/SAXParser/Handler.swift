// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import XMLCore

/// Receives XML parse events from a ``SAXParser``.
///
/// Implement this protocol to consume a document as it is parsed without
/// building an in-memory tree. All `Span` parameters borrow directly from the
/// source buffer and are valid only for the duration of the callback.
///
/// The `Failure` associated type controls error propagation. Use the default
/// `Failure == Never` when callbacks cannot throw — this lets the parser use an
/// optimised non-boxing path internally. Provide a concrete `Error` type only
/// when handlers need to propagate failures.
///
/// All methods have default no-op implementations; override only what you need.
public protocol Handler {
  /// The error type that handler callbacks may throw.
  associatedtype Failure: Error = Never

  // MARK: - Location

  /// The source position last reported by the parser.
  ///
  /// The parser updates this property before each callback so the handler can
  /// record where in the document each event originated.
  var location: XML.Location? { get set }

  // MARK: - Document lifecycle

  /// Called once before any other event, at the start of the document.
  mutating func start(document: Void) throws(Failure)

  /// Called once after all events, at the end of the document.
  mutating func end(document: Void) throws(Failure)

  // MARK: - Content events

  /// Called when an XML declaration (`<?xml … ?>`) is encountered.
  ///
  /// - Parameters:
  ///   - version: The value of the `version` pseudo-attribute.
  ///   - encoding: The value of the `encoding` pseudo-attribute, or `nil`.
  ///   - standalone: The value of the `standalone` pseudo-attribute, or `nil`.
  mutating func declaration(version: Span<XML.Byte>, encoding: Span<XML.Byte>?,
                            standalone: Span<XML.Byte>?) throws(Failure)

  /// Called when a processing instruction other than the XML declaration is
  /// encountered.
  mutating func processing(target: Span<XML.Byte>, data: Span<XML.Byte>?) throws(Failure)

  /// Called when a comment (`<!-- … -->`) is encountered.
  mutating func comment(_ content: Span<XML.Byte>) throws(Failure)

  /// Called for character data in element content, with entity references
  /// already expanded. Analogous to the `characters` / `ignorableWhitespace`
  /// callbacks in libxml2.
  mutating func characters(_ data: Span<XML.Byte>) throws(Failure)

  /// Called for the raw bytes of a `<![CDATA[ … ]]>` section (no entity
  /// expansion). Analogous to the `cdataBlock` callback in libxml2.
  mutating func character(data: Span<XML.Byte>) throws(Failure)

  // MARK: - Namespace prefix mapping

  /// Called when a namespace binding comes into scope, before the
  /// corresponding ``start(element:namespace:attributes:)`` callback.
  ///
  /// - Parameters:
  ///   - prefix: The namespace prefix, or `nil` for the default namespace.
  ///   - uri: The namespace URI being bound to the prefix.
  mutating func start(mapping prefix: Span<XML.Byte>?, uri: Span<XML.Byte>) throws(Failure)

  /// Called when a namespace binding goes out of scope, after the
  /// corresponding ``end(element:namespace:)`` callback.
  ///
  /// - Parameter prefix: The namespace prefix, or `nil` for the default namespace.
  mutating func end(mapping prefix: Span<XML.Byte>?) throws(Failure)

  // MARK: - Element events

  /// Called when an element start tag (or empty-element tag) is opened.
  ///
  /// - Parameters:
  ///   - name: The qualified name of the element.
  ///   - uri: The namespace URI of the element, or `nil` if unqualified.
  ///   - attributes: The resolved attribute list.
  mutating func start(element name: XML.QualifiedNameView,
                      namespace uri: Span<XML.Byte>?,
                      attributes: XML.ResolvedAttributesView) throws(Failure)

  /// Called when an element end tag is encountered, including the implicit end
  /// tag of an empty-element tag.
  mutating func end(element name: XML.QualifiedNameView,
                    namespace uri: Span<XML.Byte>?) throws(Failure)

  // MARK: - DTD events

  /// Called when a `<!DOCTYPE …>` declaration is encountered.
  ///
  /// - Parameters:
  ///   - name: The document type name.
  ///   - id: The optional public and system identifiers.
  mutating func start(dtd name: Span<XML.Byte>,
                      id: (public: Span<XML.Byte>?, system: Span<XML.Byte>?)) throws(Failure)

  /// Called immediately after ``start(dtd:id:)`` to mark the end of the
  /// DOCTYPE declaration.
  mutating func end(dtd: Void) throws(Failure)
}
