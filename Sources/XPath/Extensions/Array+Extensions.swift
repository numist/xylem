// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import DOMParser

extension Array where Element == XPath.Step {
  // Fuse a `//` shorthand into `descendant::` when possible: if the next step
  // uses the `child` axis it is promoted; otherwise a `descendant-or-self::node()`
  // bridge is prepended.
  mutating func fuse(_ next: XPath.Step) {
    if next.axis == .child {
      append(XPath.Step(axis: .descendant, test: next.test, predicates: next.predicates))
    } else {
      append(XPath.Step(axis: .descendantOrSelf, test: .node, predicates: []))
      append(next)
    }
  }
}

extension Array where Element == Document.Reference {
  @inline(__always)
  internal func union(with other: [Element]) -> [Element] {
    guard !other.isEmpty else { return self }
    var seen = Set(self)
    var result = self
    result.reserveCapacity(count + other.count)
    for element in other where seen.insert(element).inserted {
      result.append(element)
    }
    return result
  }
}
