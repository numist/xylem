// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import DOMParser
internal import XMLCore

extension XPath.Expression {
  // MARK: - Functions

  internal func evaluate(function name: String, arguments: [Node],
                         in document: borrowing Document,
                         context: borrowing XPath.Context) throws(XPath.Error) -> XPath.Value {
    if let value = try evaluate(context: name, arguments: arguments,
                                in: document, context: context) {
      return value
    }
    if let value = try evaluate(boolean: name, arguments: arguments,
                                in: document, context: context) {
      return value
    }
    if let value = try evaluate(node: name, arguments: arguments,
                                in: document, context: context) {
      return value
    }
    if let value = try evaluate(string: name, arguments: arguments,
                                in: document, context: context) {
      return value
    }
    if let value = try evaluate(number: name, arguments: arguments,
                                in: document, context: context) {
      return value
    }
    throw .unknownFunction(name)
  }
}
