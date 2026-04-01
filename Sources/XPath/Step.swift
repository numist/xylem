// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XPath {
  internal struct LocationPath {
    internal var absolute: Bool
    internal var steps: [Step]
  }

  internal struct Step {
    internal var axis: Axis
    internal var test: NodeTest
    internal var predicates: [Expression.Node]

    internal var positional: Bool {
      predicates.contains(where: \.positional)
    }
  }
}
