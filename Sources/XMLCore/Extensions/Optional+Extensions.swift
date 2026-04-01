// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension Optional where Wrapped == Span<XML.Byte> {
  @inline(__always)
  package static func == (_ lhs: borrowing Self, _ rhs: StaticString) -> Bool {
    switch lhs {
    case .none: return false
    case .some(let span): return span == rhs
    }
  }

  @inline(__always)
  package static func == (_ lhs: borrowing Self, _ rhs: borrowing String) -> Bool {
    switch lhs {
    case .none: return false
    case .some(let span): return span == rhs
    }
  }
}
