// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import DOMParser
internal import XMLCore

extension XPath.Expression {
  internal func evaluate(context name: borrowing String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value? {
    switch name {
    case "last":
      guard arguments.isEmpty else { throw .typeError("last() takes no arguments") }
      return .number(Double(context.size))

    case "position":
      guard arguments.isEmpty else { throw .typeError("position() takes no arguments") }
      return .number(Double(context.position))

    case "count":
      guard arguments.count == 1 else { throw .typeError("count() requires exactly 1 argument") }
      if case .path = arguments[0] {
        return try .number(Double(count(arguments[0], in: document, context: context)))
      }
      let value = try evaluate(arguments[0], in: document, context: context)
      guard case let .set(nodes) = value else {
        throw .typeError("count() requires a node-set argument")
      }
      return .number(Double(nodes.count))

    default:
      return nil
    }
  }

  internal func evaluate(boolean name: borrowing String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value? {
    switch name {
    case "true":
      guard arguments.isEmpty else { throw .typeError("true() takes no arguments") }
      return .bool(true)

    case "false":
      guard arguments.isEmpty else { throw .typeError("false() takes no arguments") }
      return .bool(false)

    case "not":
      guard arguments.count == 1 else { throw .typeError("not() requires exactly 1 argument") }
      let value = try evaluate(arguments[0], in: document, context: context)
      return .bool(!value.boolean)

    case "boolean":
      guard arguments.count == 1 else { throw .typeError("boolean() requires exactly 1 argument") }
      let value = try evaluate(arguments[0], in: document, context: context)
      return .bool(value.boolean)

    default:
      return nil
    }
  }

  internal func evaluate(number name: borrowing String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value? {
    switch name {
    case "number":
      if arguments.isEmpty { return .number(document.number(of: context.node)) }
      guard arguments.count == 1 else { throw .typeError("number() requires 0 or 1 arguments") }
      let value = try evaluate(arguments[0], in: document, context: context)
      return .number(value.number(in: document))

    case "sum":
      guard arguments.count == 1 else { throw .typeError("sum() requires exactly 1 argument") }
      let value = try evaluate(arguments[0], in: document, context: context)
      guard case let .set(nodes) = value else {
        throw .typeError("sum() requires a node-set argument")
      }
      var total = 0.0
      for node in nodes {
        total += document.number(of: node)
      }
      return .number(total)

    case "floor", "ceiling", "round":
      guard arguments.count == 1 else { throw .typeError("\(name)() requires exactly 1 argument") }
      let rule: FloatingPointRoundingRule = switch name {
      case "floor":   .down
      case "ceiling": .up
      default:        .toNearestOrAwayFromZero
      }
      let value = try evaluate(arguments[0], in: document, context: context).number(in: document)
      if name == "round" { return .number(rounding(value)) }
      return .number(value.rounded(rule))

    default:
      return nil
    }
  }

  internal func rounding(_ value: Double) -> Double {
    guard value.isFinite else { return value }
    let lower = value.rounded(.down)
    let fraction = value - lower
    return fraction >= 0.5 ? lower + 1 : lower
  }
}
