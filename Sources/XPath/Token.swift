// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XPath {
  internal enum Token: Equatable {
    case slash            // /
    case doubleSlash      // //
    case dot              // .
    case dotDot           // ..
    case at               // @
    case star             // *
    case doubleColon      // ::
    case lbracket         // [
    case rbracket         // ]
    case lparen           // (
    case rparen           // )
    case comma            // ,
    case pipe             // |
    case plus             // +
    case minus            // -
    case eq               // =
    case neq              // !=
    case lt               // <
    case lte              // <=
    case gt               // >
    case gte              // >=
    case dollar           // $
    case name(String)
    case string(String)
    case number(Double)
    case end

    internal var isNodeType: Bool {
      self == .name("text") || self == .name("comment") ||
      self == .name("node") || self == .name("processing-instruction")
    }

    internal var terminator: Bool {
      switch self {
      case .end, .rbracket, .rparen, .pipe,
           .eq, .neq, .lt, .lte, .gt, .gte,
           .plus, .minus,
           .name("and"), .name("or"), .name("div"), .name("mod"): true
      default: false
      }
    }
  }
}
