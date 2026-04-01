// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import DOMParser
internal import XMLCore

extension XPath.Expression {
  internal func evaluate(string name: borrowing String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value? {
    switch name {
    case "string":
      if arguments.isEmpty { return .string(document.string(of: context.node)) }
      guard arguments.count == 1 else { throw .typeError("string() requires 0 or 1 arguments") }
      let value = try evaluate(arguments[0], in: document, context: context)
      return .string(value.string(in: document))

    case "normalize-space":
      let string = try argument(arguments, for: "normalize-space",
                                in: document, context: context)
      return .string(collapse(string))

    case "string-length":
      let string = try argument(arguments, for: "string-length",
                                in: document, context: context)
      return .number(Double(string.unicodeScalars.count))

    case "concat":
      guard arguments.count >= 2 else { throw .typeError("concat() requires at least 2 arguments") }
      let first = try string(arguments[0], in: document, context: context)
      let second = try string(arguments[1], in: document, context: context)
      var out = first
      out.reserveCapacity(first.utf8.count + second.utf8.count)
      out += second
      for index in 2 ..< arguments.count {
        out += try string(arguments[index], in: document, context: context)
      }
      return .string(out)

    case "contains":
      guard arguments.count == 2 else { throw .typeError("contains() requires exactly 2 arguments") }
      let haystack = try string(arguments[0], in: document, context: context)
      let needle = try string(arguments[1], in: document, context: context)
      return .bool(haystack.utf8.firstRange(of: needle.utf8) != nil)

    case "starts-with":
      guard arguments.count == 2 else { throw .typeError("starts-with() requires exactly 2 arguments") }
      let value = try string(arguments[0], in: document, context: context)
      let prefix = try string(arguments[1], in: document, context: context)
      return .bool(value.hasPrefix(prefix))

    case "substring-before":
      guard arguments.count == 2 else { throw .typeError("substring-before() requires exactly 2 arguments") }
      let value = try string(arguments[0], in: document, context: context)
      let separator = try string(arguments[1], in: document, context: context)
      return .string(segment(of: value, on: separator, after: false))

    case "substring-after":
      guard arguments.count == 2 else { throw .typeError("substring-after() requires exactly 2 arguments") }
      let value = try string(arguments[0], in: document, context: context)
      let separator = try string(arguments[1], in: document, context: context)
      return .string(segment(of: value, on: separator, after: true))

    case "substring":
      guard arguments.count == 2 || arguments.count == 3 else {
        throw .typeError("substring() requires 2 or 3 arguments")
      }
      let value = try string(arguments[0], in: document, context: context)
      let start = try evaluate(arguments[1], in: document, context: context).number(in: document)
      let lower = rounding(start)
      let upper: Double
      if arguments.count == 3 {
        let value = try evaluate(arguments[2], in: document, context: context)
        upper = lower + rounding(value.number(in: document))
      } else {
        upper = .infinity
      }

      var result = String.UnicodeScalarView()
      for (offset, scalar) in value.unicodeScalars.enumerated() {
        let position = Double(offset + 1)
        if position >= lower && position < upper {
          result.append(scalar)
        }
      }
      return .string(String(result))

    case "translate":
      guard arguments.count == 3 else { throw .typeError("translate() requires exactly 3 arguments") }
      let value = try string(arguments[0], in: document, context: context)
      let from = try string(arguments[1], in: document, context: context)
      let to = try string(arguments[2], in: document, context: context)
      return .string(translate(value, from: from, to: to))

    default:
      return nil
    }
  }

  private func argument(_ args: borrowing [Node], for fn: borrowing String,
                        in document: borrowing Document,
                        context: borrowing XPath.Context) throws(XPath.Error) -> String {
    if args.isEmpty { return document.string(of: context.node) }
    guard args.count == 1 else {
      let fn = copy fn
      throw .typeError("\(fn)() requires 0 or 1 arguments")
    }
    return try string(args[0], in: document, context: context)
  }

  private func collapse(_ string: borrowing String) -> String {
    var out = ""
    out.reserveCapacity(string.utf8.count)

    var gap = false
    for scalar in string.unicodeScalars {
      guard !scalar.isXMLSpace else {
        gap = !out.isEmpty
        continue
      }
      if gap { out.append(" ") }
      gap = false
      out.unicodeScalars.append(scalar)
    }

    return out
  }

  private func segment(of string: borrowing String,
                       on separator: borrowing String,
                       after: Bool) -> String {
    let string = copy string
    guard let range = string.utf8.firstRange(of: separator.utf8),
          let lower = String.Index(range.lowerBound, within: string),
          let upper = String.Index(range.upperBound, within: string) else {
      return ""
    }
    if after { return String(string[upper...]) }
    return String(string[string.startIndex ..< lower])
  }

  private func translate(_ string: borrowing String, from: borrowing String, to: borrowing String) -> String {
    var table: [Unicode.Scalar: Unicode.Scalar?] = [:]
    table.reserveCapacity(from.unicodeScalars.count)
    var replacements = to.unicodeScalars.makeIterator()
    for character in from.unicodeScalars where table[character] == nil {
      table[character] = replacements.next()
    }

    var out = String.UnicodeScalarView()
    out.reserveCapacity(string.unicodeScalars.count)
    for scalar in string.unicodeScalars {
      switch table[scalar] {
      case .none:
        out.append(scalar)
      case let .some(replacement?):
        out.append(replacement)
      case .some(nil):
        break
      }
    }
    return String(out)
  }
}
