// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

// [6] AxisName ::= 'ancestor' | 'ancestor-or-self' | 'attribute' | 'child' | 'descendant'
//               | 'descendant-or-self' | 'following' | 'following-sibling' | 'namespace'
//               | 'parent' | 'preceding' | 'preceding-sibling' | 'self'
extension XPath {
  internal enum Axis {
    case child
    case descendant
    case descendantOrSelf
    case parent
    case ancestor
    case ancestorOrSelf
    case `self`
    case attribute
    case following
    case followingSibling
    case preceding
    case precedingSibling
    case namespace

    internal var reverse: Bool {
      switch self {
      case .ancestor, .ancestorOrSelf, .preceding, .precedingSibling: return true
      default: return false
      }
    }

    // Visits from distinct origin nodes are guaranteed not to overlap, so
    // deduplication can be skipped. True for child, attribute, and self.
    internal var disjoint: Bool {
      switch self {
      case .child, .attribute, .`self`: return true
      default: return false
      }
    }

    internal init?(name: String) {
      switch name {
      case "child":                self = .child
      case "descendant":           self = .descendant
      case "descendant-or-self":   self = .descendantOrSelf
      case "parent":               self = .parent
      case "ancestor":             self = .ancestor
      case "ancestor-or-self":     self = .ancestorOrSelf
      case "self":                 self = .`self`
      case "attribute":            self = .attribute
      case "following":            self = .following
      case "following-sibling":    self = .followingSibling
      case "preceding":            self = .preceding
      case "preceding-sibling":    self = .precedingSibling
      case "namespace":            self = .namespace
      default:                     return nil
      }
    }
  }
}
