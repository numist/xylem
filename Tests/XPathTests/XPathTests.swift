// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Testing
import XMLCore
import DOMParser
import XPath

@Suite("XPath")
internal struct XPathTests {
  fileprivate static let fixture = XPathFixture(
    """
    <?top start?><root xml:lang="en" xmlns:p="urn:p"><a id="a" class="A"><b id="b1">one</b><!--gap--><?mid data?><b id="b2"><c id="c1"/></b><b id="b3" xml:lang="en-US">two</b></a><d id="d" p:flag="yes"><p:item id="p1">three</p:item></d></root>
    """
  )

  fileprivate static let numbers = XPathFixture(
    """
    <root><n>3.5</n><m>-4.5</m><v>1</v><v>2</v><v>3</v></root>
    """
  )

  fileprivate static let namespaceSensitive = XPathFixture(
    """
    <root xmlns:p="urn:p"><p:item id="ns">3</p:item><item id="plain">1</item></root>
    """
  )

  @Suite("Axes")
  internal struct Axes {
    @Test("forward axes return the expected nodes")
    internal func forward() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.ids("child::b", from: "id('a')") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("b", from: "id('a')") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("descendant::c", from: "id('a')") == ["c1"])
      #expect(try fixture.ids("descendant-or-self::b", from: "id('a')") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("following-sibling::*", from: "id('a')") == ["d"])
      #expect(try fixture.ids("following::*", from: "id('b2')") == ["b3", "d", "p1"])
    }

    @Test("reverse axes preserve XPath axis semantics")
    internal func reverse() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.ids("parent::*", from: "id('b2')") == ["a"])
      #expect(try fixture.ids("..", from: "id('b2')") == ["a"])
      #expect(try fixture.ids("ancestor::*", from: "id('c1')") == ["root", "a", "b2"])
      #expect(try fixture.ids("ancestor-or-self::*", from: "id('c1')") == ["root", "a", "b2", "c1"])
      #expect(try fixture.ids("preceding-sibling::*", from: "id('b3')") == ["b1", "b2"])
      #expect(try fixture.ids("preceding::*", from: "id('d')") == ["a", "b1", "b2", "c1", "b3"])
      #expect(try fixture.ids("preceding-sibling::*[1]", from: "id('b3')") == ["b2"])
    }

    @Test("abbreviated axis syntax stays readable and equivalent")
    internal func abbreviations() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.ids(".", from: "id('b2')") == ["b2"])
      #expect(try fixture.names("@*", from: "id('a')") == ["id", "class"])
      #expect(try fixture.ids("@class", from: "id('a')") == ["A"])
      #expect(try fixture.ids("//c") == ["c1"])
      #expect(try fixture.ids("/root/a/b") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("child::*", from: "id('a')/@id") == [])
      #expect(try fixture.ids("descendant::*", from: "id('a')/@id") == [])
    }

    @Test("namespace axis requires namespace-node storage", .disabled("DOMParser does not model namespace nodes yet"))
    internal func namespaceAxis() throws {
      let fixture = XPathTests.fixture
      #expect(try fixture.names("namespace::*", from: "id('d')") == ["xml", "p"])
    }
  }

  @Suite("Node Tests")
  internal struct NodeTests {
    @Test("name tests and wildcards match elements and attributes")
    internal func namesAndWildcards() throws {
      let fixture = XPathTests.fixture
      let namespaces = ["p": "urn:p"]

      #expect(try fixture.ids("child::*", from: "id('a')") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("child::b", from: "id('a')") == ["b1", "b2", "b3"])
      #expect(try fixture.ids("child::p:*", from: "id('d')", namespaces: namespaces) == ["p1"])
      #expect(try fixture.ids("child::p:item", from: "id('d')", namespaces: namespaces) == ["p1"])
      #expect(try fixture.names("attribute::*", from: "id('d')") == ["id", "p:flag"])
      #expect(try fixture.names("attribute::p:*", from: "id('d')", namespaces: namespaces) == ["p:flag"])
    }

    @Test("node-type tests cover text, comment, processing instructions, and node()")
    internal func nodeTypes() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.values("child::text()", from: "id('b1')") == ["one"])
      #expect(try fixture.values("child::comment()", from: "id('a')") == ["gap"])
      #expect(try fixture.names("child::processing-instruction()", from: "id('a')") == ["mid"])
      #expect(try fixture.names("child::processing-instruction('mid')", from: "id('a')") == ["mid"])
      let expected: [Document.NodeKind] = [.element, .comment, .processingInstruction, .element, .element]
      #expect(try fixture.kinds("child::node()", from: "id('a')") == expected)
    }

    @Test("expression prefixes resolve through the static namespace context")
    internal func namespaceQualifiedNameResolution() throws {
      let fixture = XPathFixture(
        """
        <root xmlns:x="urn:p" xmlns:y="urn:p"><x:item id="left"/><y:item id="right"/></root>
        """
      )
      #expect(try fixture.ids("//p:item", namespaces: ["p": "urn:p"]) == ["left", "right"])
    }

    @Test("unprefixed QName tests do not match namespaced elements")
    internal func unprefixedQNameNamespaceSemantics() throws {
      let fixture = XPathTests.namespaceSensitive

      #expect(try fixture.ids("/root/item") == ["plain"])
      #expect(try fixture.ids("//item") == ["plain"])
      #expect(try fixture.ids("child::item", from: "/root") == ["plain"])
    }
  }

  @Suite("Predicates And Expressions")
  internal struct PredicatesAndExpressions {
    @Test("predicates cover numeric, boolean, and positional filters")
    internal func predicates() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.ids("/root/a/b[1]") == ["b1"])
      #expect(try fixture.ids("/root/a/b[2.0]") == ["b2"])
      #expect(try fixture.ids("/root/a/b[1.9]") == [])
      #expect(try fixture.ids("/root/a/b[0 div 0]") == [])
      #expect(try fixture.ids("/root/a/b[1 div 0]") == [])
      #expect(try fixture.ids("/root/a/b[last()]") == ["b3"])
      #expect(try fixture.ids("/root/a/b[position() = 2]") == ["b2"])
      #expect(try fixture.ids("/root/a/b[@id = 'b2']") == ["b2"])
      #expect(try fixture.ids("/root/a/b[@id = 'b2'][position() = 1]") == ["b2"])
      #expect(try fixture.ids("preceding-sibling::*[1]", from: "id('b3')") == ["b2"])
    }

    @Test("operators and grouping respect XPath precedence")
    internal func operators() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.bool("1 + 2 * 3 = 7"))
      #expect(try fixture.bool("(1 + 2) * 3 = 9"))
      #expect(try fixture.bool("5 div 2 = 2.5"))
      #expect(try fixture.bool("5 mod 2 = 1"))
      #expect(try fixture.bool("-3 < -2"))
      #expect(try fixture.bool("1 < 2 and 3 > 2"))
      #expect(try fixture.bool("false() or true()"))
      #expect(try fixture.bool("/root/a/b/@id = 'b2'"))
      #expect(try fixture.bool("true() = 2"))
      #expect(try fixture.bool("false() = 0"))

      let namespaced = XPathTests.namespaceSensitive
      #expect(try namespaced.bool("number(item) < 2", from: "/root"))
      #expect(try namespaced.bool("number(item) > 2", from: "/root") == false)
    }

    @Test("union and filter-path expressions exercise the full path grammar")
    internal func pathGrammar() throws {
      let fixture = XPathTests.fixture
      let namespaces = ["p": "urn:p"]

      #expect(try fixture.ids("/root/a/b[1] | /root/d/p:item", namespaces: namespaces) == ["b1", "p1"])
      #expect(try fixture.string("(//b)[1]/@id") == "b1")
      #expect(try fixture.ids("id('a')/b[2]/c") == ["c1"])
    }

    @Test("representative grammar productions parse")
    internal func grammarSurface() throws {
      let expressions = [
        "$value",
        "(1)",
        "'literal'",
        "3.5",
        ".",
        "..",
        "@id",
        "/root/a/b",
        "//b",
        "child::b",
        "ancestor-or-self::node()",
        "processing-instruction('mid')",
        "count(/root/a/b)",
        "1 or 0",
        "1 and 0",
        "1 = 1",
        "1 != 2",
        "1 < 2",
        "1 <= 2",
        "2 > 1",
        "2 >= 1",
        "1 + 2",
        "3 - 1",
        "2 * 3",
        "6 div 2",
        "7 mod 3",
        "-1",
        "/root/a/b | /root/d/p:item",
      ]

      for expression in expressions {
        _ = try XPath.Expression.parse(expression)
      }
    }

    @Test("variable references evaluate through the dynamic context")
    internal func variables() throws {
      #expect(try XPathTests.fixture.string("$value",
                                           variables: [XML.ExpandedName(local: "value"): .string("bound")]) == "bound")
    }

    @Test("prefixed variable references resolve by expanded name")
    internal func expandedNameVariables() throws {
      let qualified = XML.ExpandedName(namespace: "urn:variables", local: "value")
      #expect(try XPathTests.fixture.string("$p:value",
                                           namespaces: ["p": "urn:variables"],
                                           variables: [qualified: .string("bound")]) == "bound")
    }
  }

  @Suite("Functions")
  internal struct Functions {
    @Test("node-set functions return spec-shaped values")
    internal func nodeSetFunctions() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.number("count(/root/a/b)") == 3)
      #expect(try fixture.ids("id('c1 b2 c1')") == ["b2", "c1"])
      #expect(try fixture.string("local-name(/root/d/*[1])") == "item")
      #expect(try fixture.string("name(/root/d/*[1])") == "p:item")
      #expect(try fixture.string("namespace-uri(/root/d/*[1])") == "urn:p")
      #expect(try fixture.string("name(/root/d/*[99])", from: "id('d')") == "")
      #expect(try fixture.bool("lang('en')", from: "id('b3')"))
      #expect(try fixture.bool("lang('fr')", from: "id('b3')") == false)
    }

    @Test("string functions stay correct for literals and node-set arguments")
    internal func stringFunctions() throws {
      let fixture = XPathTests.fixture

      #expect(try fixture.string("string(/root/a/b[1])") == "one")
      #expect(try fixture.string("concat('a', 'b', 'c')") == "abc")
      #expect(try fixture.bool("contains('abracadabra', 'cad')"))
      #expect(try fixture.bool("contains(/root/a/b[1], 'on')"))
      #expect(try fixture.bool("starts-with('abracadabra', 'abra')"))
      #expect(try fixture.bool("starts-with(/root/a/b[1], 'on')"))
      #expect(try fixture.string("substring-before('1999/04/01', '/')") == "1999")
      #expect(try fixture.string("substring-after('1999/04/01', '/')") == "04/01")
      #expect(try fixture.string("substring('12345', 1.5, 2.6)") == "234")
      #expect(try fixture.string("substring('12345', 0, 3)") == "12")
      #expect(try fixture.number("string-length(/root/a/b[1])") == 3)
      #expect(try fixture.string("normalize-space('  a \t b \n c  ')") == "a b c")
      #expect(try fixture.string("translate('bar', 'abc', 'ABC')") == "BAr")
    }

    @Test("boolean and number functions follow XPath 1.0 conversion rules")
    internal func booleanAndNumberFunctions() throws {
      let fixture = XPathTests.fixture
      let numbers = XPathTests.numbers

      #expect(try fixture.bool("boolean(/root/a/b)"))
      #expect(try fixture.bool("not(/root/missing)"))
      #expect(try fixture.bool("true()"))
      #expect(try fixture.bool("false()") == false)
      #expect(throws: XPath.Error.self) { try fixture.bool("true(1)") }
      #expect(throws: XPath.Error.self) { try fixture.bool("false(1)") }

      #expect(try numbers.number("number(/root/n)") == 3.5)
      #expect(try numbers.number("sum(/root/v)") == 6)
      #expect(try numbers.number("floor(3.9)") == 3)
      #expect(try numbers.number("ceiling(3.1)") == 4)
      #expect(try numbers.number("round(-4.5)") == -4)
    }

    @Test("node-set functions reject non-node-set arguments")
    internal func strictNodeSetFunctionTyping() throws {
      let fixture = XPathTests.fixture

      #expect(throws: XPath.Error.self) { try fixture.string("local-name(1)") }
      #expect(throws: XPath.Error.self) { try fixture.string("name(true())") }
      #expect(throws: XPath.Error.self) { try fixture.string("namespace-uri('x')") }
      #expect(throws: XPath.Error.self) { try fixture.number("count(1)") }
      #expect(throws: XPath.Error.self) { try fixture.number("sum('x')") }
    }
  }
}

private extension XPathTests {
  struct XPathFixture {
    let xml: String

    init(_ xml: String) {
      self.xml = xml
    }

    func nodes(_ expression: String,
               from context: String? = nil,
               namespaces: [String: String] = [:],
               variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> [Document.Reference] {
      try withDocument { document in
        try resolve(expression, from: context, in: document,
                    namespaces: namespaces, variables: variables)
      }
    }

    func string(_ expression: String,
                from context: String? = nil,
                namespaces: [String: String] = [:],
                variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> String {
      try withDocument { document in
        let compiled = try XPath.Expression.parse(expression, namespaces: namespaces)
        guard let context else {
          return try compiled.string(in: document,
                                     with: XPath.Context(node: document.root,
                                                         variables: variables))
        }
        return try compiled.string(in: document,
                                   with: XPath.Context(node: try one(context, in: document,
                                                                     namespaces: namespaces,
                                                                     variables: variables),
                                                       variables: variables))
      }
    }

    func number(_ expression: String,
                from context: String? = nil,
                namespaces: [String: String] = [:],
                variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> Double {
      try withDocument { document in
        let compiled = try XPath.Expression.parse(expression, namespaces: namespaces)
        guard let context else {
          return try compiled.number(in: document,
                                     with: XPath.Context(node: document.root,
                                                         variables: variables))
        }
        return try compiled.number(in: document,
                                   with: XPath.Context(node: try one(context, in: document,
                                                                     namespaces: namespaces,
                                                                     variables: variables),
                                                       variables: variables))
      }
    }

    func bool(_ expression: String,
              from context: String? = nil,
              namespaces: [String: String] = [:],
              variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> Bool {
      try withDocument { document in
        let compiled = try XPath.Expression.parse(expression, namespaces: namespaces)
        guard let context else {
          return try compiled.bool(in: document,
                                   with: XPath.Context(node: document.root,
                                                       variables: variables))
        }
        return try compiled.bool(in: document,
                                 with: XPath.Context(node: try one(context, in: document,
                                                                   namespaces: namespaces,
                                                                   variables: variables),
                                                     variables: variables))
      }
    }

    func ids(_ expression: String,
             from context: String? = nil,
             namespaces: [String: String] = [:],
             variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> [String] {
      try withDocument { document in
        let refs = try resolve(expression, from: context, in: document,
                               namespaces: namespaces, variables: variables)
        return refs.map { reference in
          if document.kind(of: reference) == .attribute {
            return value(of: reference, in: document)
          }
          return id(of: reference, in: document) ?? localName(of: reference, in: document)
        }
      }
    }

    func names(_ expression: String,
               from context: String? = nil,
               namespaces: [String: String] = [:],
               variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> [String] {
      try withDocument { document in
        try resolve(expression, from: context, in: document,
                    namespaces: namespaces, variables: variables)
          .map { name(of: $0, in: document) }
      }
    }

    func values(_ expression: String,
                from context: String? = nil,
                namespaces: [String: String] = [:],
                variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> [String] {
      try withDocument { document in
        try resolve(expression, from: context, in: document,
                    namespaces: namespaces, variables: variables)
          .map { value(of: $0, in: document) }
      }
    }

    func kinds(_ expression: String,
               from context: String? = nil,
               namespaces: [String: String] = [:],
               variables: [XML.ExpandedName: XPath.Value] = [:]) throws -> [Document.NodeKind] {
      try withDocument { document in
        try resolve(expression, from: context, in: document,
                    namespaces: namespaces, variables: variables)
          .map { document.kind(of: $0) }
      }
    }

    private func withDocument<Result>(_ body: (borrowing Document) throws -> Result) throws -> Result {
      let bytes = Array(xml.utf8)
      let document = try DOMParser.parse(bytes: bytes.span)
      return try body(document)
    }

    private func one(_ expression: String, in document: borrowing Document,
                     namespaces: [String: String],
                     variables: [XML.ExpandedName: XPath.Value]) throws -> Document.Reference {
      let refs = try XPath.Expression.parse(expression, namespaces: namespaces)
        .nodes(in: document,
               with: XPath.Context(node: document.root,
                                   variables: variables))
      guard let first = refs.first else {
        Issue.record("missing context node for \(expression)")
        struct MissingContext: Error {}
        throw MissingContext()
      }
      return first
    }

    private func resolve(_ expression: String, from context: String?,
                         in document: borrowing Document,
                         namespaces: [String: String],
                         variables: [XML.ExpandedName: XPath.Value]) throws -> [Document.Reference] {
      let compiled = try XPath.Expression.parse(expression, namespaces: namespaces)
      guard let context else {
        return try compiled.nodes(in: document,
                                  with: XPath.Context(node: document.root,
                                                      variables: variables))
      }
      return try compiled.nodes(in: document,
                                with: XPath.Context(node: try one(context, in: document,
                                                                  namespaces: namespaces,
                                                                  variables: variables),
                                                    variables: variables))
    }

    private func id(of reference: Document.Reference, in document: borrowing Document) -> String? {
      var attribute = document.firstAttribute(of: reference)
      while let current = attribute {
        let view = document.view(of: current)
        if let name = view.name, String(name.local) == "id", let value = view.value {
          return String(value)
        }
        attribute = document.nextAttribute(after: current)
      }
      return nil
    }

    private func localName(of reference: Document.Reference, in document: borrowing Document) -> String {
      let view = document.view(of: reference)
      guard let name = view.name else { return "" }
      return String(name.local)
    }

    private func name(of reference: Document.Reference, in document: borrowing Document) -> String {
      let view = document.view(of: reference)
      guard let name = view.name else { return "" }
      return String(name.bytes)
    }

    private func value(of reference: Document.Reference, in document: borrowing Document) -> String {
      let view = document.view(of: reference)
      switch view.kind {
      case .document, .element:
        var text = ""
        var child = document.firstChild(of: reference)
        while let node = child {
          text += value(of: node, in: document)
          child = document.nextSibling(of: node)
        }
        return text
      default:
        guard let value = view.value else { return "" }
        return String(value)
      }
    }
  }
}
