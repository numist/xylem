// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Testing
import XMLCore
import SAXParser

private enum SAXFixtureError: Error {
  case missingRootStart
  case missingRootText
}

private struct SAXAttribute: Equatable {
  let name: String
  let namespace: String?
  let value: String
}

private enum SAXEvent: Equatable {
  case startDocument
  case endDocument
  case declaration(version: String, encoding: String?, standalone: String?)
  case processing(target: String, data: String?)
  case comment(String)
  case characters(String)
  case cdata(String)
  case startMapping(prefix: String?, uri: String)
  case endMapping(prefix: String?)
  case startElement(name: String, namespace: String?, attributes: [SAXAttribute])
  case endElement(name: String, namespace: String?)
  case startDTD(name: String, publicID: String?, systemID: String?)
  case endDTD
}

private struct ElementLocation: Equatable {
  let phase: String
  let name: String
  let location: XML.Location
}

extension Span where Element == XML.Byte {
  @inline(__always)
  fileprivate var string: String {
    withUnsafeBufferPointer { String(decoding: $0, as: UTF8.self) }
  }
}

extension Optional where Wrapped == Span<XML.Byte> {
  @inline(__always)
  fileprivate var string: String? {
    if let self { return self.string }
    return nil
  }
}

private struct RecordingHandler: Handler {
  fileprivate var location: XML.Location?
  fileprivate var events: [SAXEvent] = []

  fileprivate mutating func start(document: Void) {
    events.append(.startDocument)
  }

  fileprivate mutating func end(document: Void) {
    events.append(.endDocument)
  }

  fileprivate mutating func declaration(version: Span<XML.Byte>, encoding: Span<XML.Byte>?,
                                        standalone: Span<XML.Byte>?) {
    events.append(.declaration(version: version.string,
                               encoding: encoding.string,
                               standalone: standalone.string))
  }

  fileprivate mutating func processing(target: Span<XML.Byte>, data: Span<XML.Byte>?) {
    events.append(.processing(target: target.string, data: data.string))
  }

  fileprivate mutating func comment(_ content: Span<XML.Byte>) {
    events.append(.comment(content.string))
  }

  fileprivate mutating func characters(_ data: Span<XML.Byte>) {
    events.append(.characters(data.string))
  }

  fileprivate mutating func character(data: Span<XML.Byte>) {
    events.append(.cdata(data.string))
  }

  fileprivate mutating func start(mapping prefix: Span<XML.Byte>?, uri: Span<XML.Byte>) {
    events.append(.startMapping(prefix: prefix.string, uri: uri.string))
  }

  fileprivate mutating func end(mapping prefix: Span<XML.Byte>?) {
    events.append(.endMapping(prefix: prefix.string))
  }

  fileprivate mutating func start(element name: XML.QualifiedNameView,
                                  namespace uri: Span<XML.Byte>?,
                                  attributes: XML.ResolvedAttributes) {
    var resolved: [SAXAttribute] = []
    resolved.reserveCapacity(attributes.count)
    for index in attributes.indices {
      let attribute = SAXAttribute(name: attributes.name(at: index).bytes.string,
                                   namespace: attributes.namespace(at: index).string,
                                   value: attributes.value(at: index).string)
      resolved.append(attribute)
    }
    events.append(.startElement(name: name.bytes.string,
                                namespace: uri.string,
                                attributes: resolved))
  }

  fileprivate mutating func end(element name: XML.QualifiedNameView,
                                namespace uri: Span<XML.Byte>?) {
    events.append(.endElement(name: name.bytes.string, namespace: uri.string))
  }

  fileprivate mutating func start(dtd name: Span<XML.Byte>,
                                  id: (public: Span<XML.Byte>?, system: Span<XML.Byte>?)) {
    events.append(.startDTD(name: name.string,
                            publicID: id.public.string,
                            systemID: id.system.string))
  }

  fileprivate mutating func end(dtd: Void) {
    events.append(.endDTD)
  }
}

private struct LocationHandler: Handler {
  fileprivate var location: XML.Location?
  fileprivate var elements: [ElementLocation] = []

  fileprivate mutating func start(element name: XML.QualifiedNameView,
                                  namespace _: Span<XML.Byte>?,
                                  attributes _: XML.ResolvedAttributes) {
    if let location {
      elements.append(ElementLocation(phase: "start", name: name.bytes.string, location: location))
    }
  }

  fileprivate mutating func end(element name: XML.QualifiedNameView, namespace _: Span<XML.Byte>?) {
    if let location {
      elements.append(ElementLocation(phase: "end", name: name.bytes.string, location: location))
    }
  }
}

private enum HandlerFailure: Error {
  case injected
}

private struct FailingHandler: Handler {
  fileprivate typealias Failure = HandlerFailure
  fileprivate var location: XML.Location?

  fileprivate mutating func start(element _: XML.QualifiedNameView,
                                  namespace _: Span<XML.Byte>?,
                                  attributes _: XML.ResolvedAttributes) throws(HandlerFailure) {
    throw .injected
  }
}

@inline(__always)
private func parseEvents(_ xml: String) throws -> [SAXEvent] {
  try parseEvents(bytes: Array(xml.utf8))
}

@inline(__always)
private func parseEvents(bytes: [XML.Byte]) throws -> [SAXEvent] {
  var parser = SAXParser(handler: RecordingHandler())
  try parser.parse(bytes: bytes.span)
  return parser.handler.events
}

@inline(__always)
private func parse(_ xml: String) throws {
  _ = try parseEvents(xml)
}

@inline(__always)
private func rootStart(in events: [SAXEvent]) throws -> (namespace: String?, attributes: [SAXAttribute]) {
  for event in events {
    if case let .startElement(name, namespace, attributes) = event, name == "r" {
      return (namespace: namespace, attributes: attributes)
    }
  }
  throw SAXFixtureError.missingRootStart
}

@inline(__always)
private func rootText(in events: [SAXEvent]) throws -> String {
  for event in events {
    if case let .characters(text) = event {
      return text
    }
  }
  throw SAXFixtureError.missingRootText
}

@Suite("SAXParser")
internal struct SAXParserTests {
  @Test("emits ordered events for mixed markup and namespace-aware elements")
  internal func mixedEventStream() throws {
    let events = try parseEvents(
      """
      <?xml version="1.0"?><!--lead--><?meta x?><!DOCTYPE root SYSTEM "urn:test"><root xmlns="urn:default" xmlns:p="urn:p" a="1" p:b="2">t<![CDATA[c]]><!--x--><?q r?><child/></root><!--tail-->
      """
    )

    #expect(events == [
      .startDocument,
      .declaration(version: "1.0", encoding: nil, standalone: nil),
      .comment("lead"),
      .processing(target: "meta", data: "x"),
      .startDTD(name: "root", publicID: nil, systemID: "urn:test"),
      .endDTD,
      .startMapping(prefix: nil, uri: "urn:default"),
      .startMapping(prefix: "p", uri: "urn:p"),
      .startElement(name: "root", namespace: "urn:default",
                    attributes: [
                      SAXAttribute(name: "a", namespace: nil, value: "1"),
                      SAXAttribute(name: "p:b", namespace: "urn:p", value: "2"),
                    ]),
      .characters("t"),
      .cdata("c"),
      .comment("x"),
      .processing(target: "q", data: "r"),
      .startElement(name: "child", namespace: "urn:default", attributes: []),
      .endElement(name: "child", namespace: "urn:default"),
      .endElement(name: "root", namespace: "urn:default"),
      .endMapping(prefix: "p"),
      .endMapping(prefix: nil),
      .comment("tail"),
      .endDocument,
    ])
  }

  @Test("scopes and unwinds namespace mappings in LIFO order")
  internal func namespaceScopeLifecycle() throws {
    let events = try parseEvents("<r xmlns='urn:r' xmlns:p='urn:p1'><p:a xmlns:p='urn:p2'/></r>")
    #expect(events == [
      .startDocument,
      .startMapping(prefix: nil, uri: "urn:r"),
      .startMapping(prefix: "p", uri: "urn:p1"),
      .startElement(name: "r", namespace: "urn:r", attributes: []),
      .startMapping(prefix: "p", uri: "urn:p2"),
      .startElement(name: "p:a", namespace: "urn:p2", attributes: []),
      .endElement(name: "p:a", namespace: "urn:p2"),
      .endMapping(prefix: "p"),
      .endElement(name: "r", namespace: "urn:r"),
      .endMapping(prefix: "p"),
      .endMapping(prefix: nil),
      .endDocument,
    ])
  }

  @Test("normalizes attributes and expands predefined entities before callbacks")
  internal func normalizedAttributeValues() throws {
    let events = try parseEvents("<r a=\"x&#x41;&#65;&lt;&gt;&amp;&apos;&quot;y\" ws=\"a&#x09;b&#x0A;c&#x0D;d&#x0D;&#x0A;e\"/>")
    let root = try rootStart(in: events)
    #expect(root.attributes == [
      SAXAttribute(name: "a", namespace: nil, value: "xAA<>&'\"y"),
      SAXAttribute(name: "ws", namespace: nil, value: "a b c d  e"),
    ])
  }

  @Test("sends character data and CDATA to distinct callbacks")
  internal func textAndCDataCallbacks() throws {
    let events = try parseEvents("<r>a&amp;b<![CDATA[c&d]]>e</r>")
    #expect(events == [
      .startDocument,
      .startElement(name: "r", namespace: nil, attributes: []),
      .characters("a&b"),
      .cdata("c&d"),
      .characters("e"),
      .endElement(name: "r", namespace: nil),
      .endDocument,
    ])
  }

  @Test("accepts compact XML declaration permutations")
  internal func xmlDeclarationAcceptanceMatrix() throws {
    for xml in [
      "<?xml version='1.0'?><r/>",
      "<?xml version='1.0' encoding='UTF-8'?><r/>",
      "<?xml version='1.0' standalone='yes'?><r/>",
      "<?xml version='1.0' standalone='no'?><r/>",
      "<?xml version='1.0' encoding='UTF-8' standalone='yes'?><r/>",
    ] {
      try parse(xml)
    }
  }

  @Test("rejects malformed XML declarations")
  internal func xmlDeclarationRejectionMatrix() {
    for xml in [
      "<?xml encoding='UTF-8'?><r/>",
      "<?xml version='1.0' version='1.0'?><r/>",
      "<?xml version='1.1'?><r/>",
      "<?xml version='1.0' bogus='1'?><r/>",
      "<?xml version='1.0' standalone='maybe'?><r/>",
    ] {
      #expect(throws: XML.Error.self) { try parse(xml) }
    }
  }

  @Test("expands character references at XML Char boundaries")
  internal func characterReferenceBoundaryAcceptance() throws {
    let events = try parseEvents("<r>&#x9;&#xA;&#xD;&#x20;&#xD7FF;&#xE000;&#xFFFD;&#x10000;&#x10FFFF;</r>")
    let text = try rootText(in: events)
    let scalars = [0x9, 0xa, 0xd, 0x20, 0xd7ff, 0xe000, 0xfffd, 0x10000, 0x10ffff]
    let expected = String(String.UnicodeScalarView(scalars.compactMap(Unicode.Scalar.init)))
    #expect(text == expected)
  }

  @Test("rejects disallowed character references")
  internal func characterReferenceBoundaryRejection() {
    for xml in [
      "<r>&#xD800;</r>",
      "<r>&#xDFFF;</r>",
      "<r>&#xFFFE;</r>",
      "<r>&#xFFFF;</r>",
      "<r>&#x110000;</r>",
      "<r>&#55296;</r>",
    ] {
      #expect(throws: XML.Error.self) { try parse(xml) }
    }
  }

  @Test("accepts representative XML Name boundaries")
  internal func nameBoundaryAcceptance() throws {
    for xml in [
      "<a/>",
      "<_a-1.2/>",
      "<\u{03b1}/>",
      "<a\u{0301}/>",
      "<\u{10000}n/>",
    ] {
      try parse(xml)
    }
  }

  @Test("rejects invalid XML Name starts")
  internal func nameBoundaryRejection() {
    for xml in [
      "<1a/>",
      "<.a/>",
      "<\u{0301}a/>",
      "<-a/>",
    ] {
      #expect(throws: XML.Error.self) { try parse(xml) }
    }
  }

  @Test("rejects undeclared namespace prefixes")
  internal func rejectsUndeclaredPrefix() {
    #expect(throws: XML.Error.self) { try parse("<p:r/>") }
  }

  @Test("rejects invalid QName forms with multiple colons")
  internal func rejectsMultipleColonQNames() {
    #expect(throws: XML.Error.self) { try parse("<r xmlns:a='urn:u'><a:b:c/></r>") }
    #expect(throws: XML.Error.self) { try parse("<r xmlns:a='urn:u' a:b:c='1'/>") }
  }

  @Test("rejects duplicate qualified attributes")
  internal func rejectsDuplicateQualifiedAttributes() {
    #expect(throws: XML.Error.self) { try parse("<r a='1' a='2'/>") }
  }

  @Test("rejects duplicate expanded-name attributes")
  internal func rejectsDuplicateExpandedAttributes() {
    #expect(throws: XML.Error.self) { try parse("<r xmlns:a='urn:u' xmlns:b='urn:u' a:x='1' b:x='2'/>") }
  }

  @Test("rejects invalid reserved namespace bindings")
  internal func rejectsReservedNamespaceViolations() {
    #expect(throws: XML.Error.self) { try parse("<r xmlns:xml='urn:not-xml'/>") }
    #expect(throws: XML.Error.self) { try parse("<r xmlns:p='http://www.w3.org/XML/1998/namespace'/>") }
  }

  @Test("rejects malformed namespace declaration prefixes")
  internal func rejectsMalformedNamespaceDeclarationPrefixes() {
    #expect(throws: XML.Error.self) { try parse("<r xmlns:='urn:u'/>") }
    #expect(throws: XML.Error.self) { try parse("<r xmlns:1p='urn:u'/>") }
    #expect(throws: XML.Error.self) { try parse("<r xmlns:a:b='urn:u'/>") }
  }

  @Test("rejects mismatched end tags")
  internal func rejectsMismatchedEndTags() {
    #expect(throws: XML.Error.self) { try parse("<a></b>") }
  }

  @Test("rejects multiple roots and top-level non-whitespace")
  internal func rejectsMultipleRootsAndTopLevelData() {
    #expect(throws: XML.Error.self) { try parse("<a/><b/>") }
    #expect(throws: XML.Error.self) { try parse("x<a/>") }
  }

  @Test("rejects misplaced XML declarations")
  internal func rejectsMisplacedDeclaration() {
    #expect(throws: XML.Error.self) { try parse(" \n<?xml version='1.0'?><a/>") }
  }

  @Test("rejects malformed character data and comments")
  internal func rejectsMalformedCharacterDataAndComments() {
    #expect(throws: XML.Error.self) { try parse("<a>]]></a>") }
    #expect(throws: XML.Error.self) { try parse("<a><!-- bad -- nope --></a>") }
  }

  @Test("rejects additional document-structure edge cases")
  internal func rejectsAdditionalDocumentStructureEdges() {
    for xml in [
      "</r>",
      "<r>",
      "<!DOCTYPE r><!DOCTYPE r><r/>",
      "<r/><!DOCTYPE r>",
      "<r/>tail",
    ] {
      #expect(throws: XML.Error.self) { try parse(xml) }
    }
  }

  @Test("rejects invalid UTF-8 byte sequences")
  internal func rejectsInvalidUTF8() {
    let bytes: [XML.Byte] = [0x3c, 0x72, 0x3e, 0xc3, 0x28, 0x3c, 0x2f, 0x72, 0x3e]
    do {
      _ = try parseEvents(bytes: bytes)
      Issue.record("expected invalidEncoding")
    } catch XML.Error.invalidEncoding {
    } catch {
      Issue.record("unexpected error: \(String(describing: error))")
    }
  }

  @Test("propagates handler-thrown failures")
  internal func propagatesHandlerFailure() {
    let bytes = Array("<r/>".utf8)
    do {
      var parser = SAXParser(handler: FailingHandler())
      try parser.parse(bytes: bytes.span)
      Issue.record("expected handler failure")
    } catch HandlerFailure.injected {
    } catch {
      Issue.record("unexpected error: \(String(describing: error))")
    }
  }

  @Test("updates handler locations before element callbacks")
  internal func callbackLocationTracking() throws {
    let bytes = Array("<r>\n<a/>\n</r>".utf8)
    var parser = SAXParser(handler: LocationHandler())
    try parser.parse(bytes: bytes.span)
    let elements = parser.handler.elements

    #expect(elements == [
      ElementLocation(phase: "start", name: "r", location: XML.Location(line: 1, offset: 1)),
      ElementLocation(phase: "start", name: "a", location: XML.Location(line: 2, offset: 1)),
      ElementLocation(phase: "end", name: "a", location: XML.Location(line: 2, offset: 1)),
      ElementLocation(phase: "end", name: "r", location: XML.Location(line: 3, offset: 1)),
    ])
  }

  @Test("internal subset entities should expand in content",
        .disabled("DTD internal subset support is not implemented yet"))
  internal func internalSubsetGeneralEntityExpansion() throws {
    let events = try parseEvents("<!DOCTYPE r [<!ENTITY e 'ok'>]><r>&e;</r>")
    let text = try rootText(in: events)
    #expect(text == "ok")
  }

  @Test("internal subset parameter entities should be usable in declarations",
        .disabled("DTD internal subset support is not implemented yet"))
  internal func internalSubsetParameterEntities() throws {
    let events = try parseEvents(
      """
      <!DOCTYPE r [
        <!ENTITY % pe "ok">
        <!ENTITY e "%pe;">
      ]>
      <r>&e;</r>
      """
    )
    let text = try rootText(in: events)
    #expect(text == "ok")
  }

  @Test("internal subset default attributes should be materialized",
        .disabled("DTD internal subset support is not implemented yet"))
  internal func internalSubsetDefaultAttributes() throws {
    let events = try parseEvents(
      """
      <!DOCTYPE r [
        <!ATTLIST r mode CDATA "safe">
      ]>
      <r/>
      """
    )
    let root = try rootStart(in: events)
    #expect(root.attributes == [
      SAXAttribute(name: "mode", namespace: nil, value: "safe"),
    ])
  }

  @Test("internal subset entities should expand in attribute values",
        .disabled("DTD internal subset support is not implemented yet"))
  internal func internalSubsetEntityInAttributeValue() throws {
    let events = try parseEvents(
      """
      <!DOCTYPE r [
        <!ENTITY e "safe">
      ]>
      <r mode="&e;"/>
      """
    )
    let root = try rootStart(in: events)
    #expect(root.attributes == [
      SAXAttribute(name: "mode", namespace: nil, value: "safe"),
    ])
  }
}
