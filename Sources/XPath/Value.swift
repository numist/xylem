// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import DOMParser
internal import XMLCore

extension XPath {
  /// An XPath 1.0 value: a node-set, string, number, or boolean.
  public enum Value {
    case set([Document.Reference])
    case string(String)
    case number(Double)
    case bool(Bool)

    // Coerce to number per XPath 1.0 section 4.4.
    internal var numeric: Double {
      switch self {
      case let .number(number): return number
      case let .bool(boolean): return boolean ? 1 : 0
      case let .string(string):
        guard !string.isEmpty else { return .nan }
        if string.utf8.first! > 0x20, string.utf8.last! > 0x20 { return Double(string) ?? .nan }
        return Double(string.trimmed()) ?? .nan
      case .set: return .nan
      }
    }

    // Coerce to boolean per XPath 1.0 section 4.3.
    internal var boolean: Bool {
      switch self {
      case let .bool(value): value
      case let .number(value): !value.isNaN && value != 0
      case let .string(value): !value.isEmpty
      case let .set(value): !value.isEmpty
      }
    }

    internal var nodes: [Document.Reference] {
      switch self {
      case let .set(nodes): nodes
      default: []
      }
    }

    // Coerce to string per XPath 1.0 section 4.3.
    // For node sets, use `string(of:)` to get the full text content.
    internal var string: String {
      switch self {
      case .string(let string): return string
      case let .bool(value): return value ? "true" : "false"
      case .set: return ""
      case let .number(value):
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
        if value == value.rounded(.towardZero), let i = Int64(exactly: value) { return String(i) }
        return String(value)
      }
    }

    internal func string(in document: borrowing Document) -> String {
      switch self {
      case let .set(nodes):
        nodes.first.map { document.string(of: $0) } ?? ""
      default:
        string
      }
    }

    internal func number(in document: borrowing Document) -> Double {
      switch self {
      case let .set(nodes):
        nodes.first.map { document.number(of: $0) } ?? .nan
      default:
        numeric
      }
    }
  }
}
