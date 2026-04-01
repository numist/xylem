// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XPath {
  internal enum BinaryOperation: Equatable {
    case and, or
    case eq, neq
    case lt, lte, gt, gte
    case add, subtract, multiply, divide, mod
  }
}
