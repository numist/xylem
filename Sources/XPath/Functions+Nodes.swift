// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import DOMParser
internal import XMLCore

extension XPath.Expression {
  internal func evaluate(node name: borrowing String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value? {
    switch name {
    case "local-name", "name", "namespace-uri":
      guard let node = try target(arguments, for: name, in: document, context: context) else {
        return .string("")
      }
      switch name {
      case "local-name":
        if let name = document.name(of: node, type: .local) { return .string(name) }
      case "name":
        if let name = document.name(of: node, type: .qualified) { return .string(name) }
      default:
        if let namespace = document.namespace(of: node) { return .string(String(namespace)) }
      }
      return .string("")

    case "lang":
      guard arguments.count == 1 else { throw .typeError("lang() requires exactly 1 argument") }
      let target = try string(arguments[0], in: document, context: context).lowercased()
      var cursor: Document.Reference? = context.node
      while let node = cursor {
        if let value = language(of: node, in: document),
           matches(language: value, target: target) {
          return .bool(true)
        }
        cursor = document.parent(of: node)
      }
      return .bool(false)

    case "id":
      guard arguments.count == 1 else { throw .typeError("id() requires exactly 1 argument") }
      let argument = try evaluate(arguments[0], in: document, context: context)
      var result: [Document.Reference] = []
      var seen: Set<Document.Reference> = []
      if case let .set(nodes) = argument {
        result.reserveCapacity(nodes.count)
        seen.reserveCapacity(nodes.count)
        for node in nodes {
          insert(ids: document.string(of: node), from: document, into: &result, seen: &seen)
        }
      } else {
        insert(ids: argument.string, from: document, into: &result, seen: &seen)
      }
      if result.count > 1 {
        result.sort { $0.index < $1.index }
      }
      return .set(result)

    default:
      return nil
    }
  }

  @_lifetime(borrow document)
  private func language(of node: Document.Reference,
                        in document: borrowing Document) -> Span<XML.Byte>? {
    guard node.attribute == nil else { return nil }

    let storage = document.storage.span
    let nodes = document.nodes
    let attributes = document.attributes
    let element = nodes[Int(node.index)]
    guard element.attributes.base >= 0 else { return nil }

    let base = Int(element.attributes.base)
    let count = Int(element.attributes.count)
    for index in 0 ..< count {
      let record = attributes[base + index]
      if record.colon == 3,
         storage.extracting(record.name.spelling.range) == StaticString("xml:lang") {
        return storage.extracting(record.value.range)
      }
    }
    return nil
  }

  private func target(_ args: borrowing [Node], for fn: borrowing String,
                      in document: borrowing Document,
                      context: borrowing XPath.Context) throws(XPath.Error) -> Document.Reference? {
    if args.isEmpty { return context.node }
    guard args.count == 1 else {
      let fn = copy fn
      throw .typeError("\(fn)() requires 0 or 1 arguments")
    }
    let value = try evaluate(args[0], in: document, context: context)
    guard case let .set(nodes) = value else {
      let fn = copy fn
      throw .typeError("\(fn)() requires a node-set argument")
    }
    return nodes.first
  }

  private func insert(ids string: String,
                      from document: borrowing Document,
                      into result: inout [Document.Reference],
                      seen: inout Set<Document.Reference>) {
    guard !string.isEmpty else { return }
    if !string.unicodeScalars.contains(where: \.isXMLSpace) {
      if let node = document.ids[string], seen.insert(node).inserted { result.append(node) }
      return
    }
    for word in string.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }) {
      if let node = document.ids[String(word)], seen.insert(node).inserted { result.append(node) }
    }
  }

  private func matches(language: borrowing Span<XML.Byte>,
                       target: borrowing String) -> Bool {
    var target = copy target
    return target.withUTF8 { target in
      guard language.count >= target.count else { return false }
      return language.withUnsafeBufferPointer { language in
        for index in 0 ..< target.count {
          if fold(language[index]) != fold(target[index]) { return false }
        }
        return language.count == target.count || language[target.count] == UInt8(ascii: "-")
      }
    }
  }

  @inline(__always)
  private func fold(_ byte: UInt8) -> UInt8 {
    if byte >= UInt8(ascii: "A"), byte <= UInt8(ascii: "Z") { return byte | 0x20 }
    return byte
  }
}
