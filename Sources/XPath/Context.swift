// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import DOMParser
public import XMLCore

// Shared, copy-on-write container for variable bindings.
// Copying a Context retains the same Variables instance; CoW triggers only on
// mutation — which is rare, since variables are almost always read-only during
// evaluation.
internal final class Variables {
  var bindings: [XML.ExpandedName:XPath.Value]
  init(_ bindings: [XML.ExpandedName:XPath.Value] = [:]) { self.bindings = bindings }
}

extension XPath {
  /// The evaluation context for an XPath expression: a context node and
  /// optional variable bindings.
  public struct Context {
    /// The context node for expression evaluation.
    public var node: Document.Reference
    internal var _vars: Variables
    internal var position: Int = 1
    internal var size: Int = 1

    /// Variable bindings available during expression evaluation.
    public var variables: [XML.ExpandedName:XPath.Value] {
      get { _vars.bindings }
      set {
        if !isKnownUniquelyReferenced(&_vars) { _vars = Variables(_vars.bindings) }
        _vars.bindings = newValue
      }
    }

    public init(node: Document.Reference,
                variables: [XML.ExpandedName:XPath.Value] = [:]) {
      self.node = node
      self._vars = Variables(variables)
    }

    public init(node: Document.Reference,
                variables: [String:XPath.Value]) {
      self.node = node
      self._vars = Variables(variables.reduce(into: [:]) { partial, entry in
        partial[XML.ExpandedName(local: entry.key)] = entry.value
      })
    }

    // Internal init used by the evaluator: shares the Variables reference
    // instead of copying the dictionary — O(1) retain instead of O(n) copy.
    internal init(node: Document.Reference, position: Int = 1, size: Int = 1,
                  sharing vars: Variables) {
      self.node = node
      self.position = position
      self.size = size
      self._vars = vars
    }
  }
}
