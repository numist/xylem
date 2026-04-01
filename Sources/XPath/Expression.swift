// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

public import DOMParser

extension XPath {
  /// A compiled, reusable XPath 1.0 expression.
  ///
  /// Parse an expression string once with ``parse(_:)`` and evaluate it
  /// against any number of documents. The compiled tree is immutable, so the
  /// same `Expression` value can be evaluated concurrently.
  ///
  /// ```swift
  /// let expr = try XPath.Expression.parse("/library/book[@available='yes']")
  /// let nodes = try expr.evaluate(in: document)
  /// for node in nodes {
  ///     let view = document.view(of: node)
  ///     print(view.name?.local ?? "-")
  /// }
  /// ```
  public struct Expression {
    private let root: Node
    internal let namespaces: [String:String]

    internal init(root: consuming Node, namespaces: consuming [String:String]) {
      self.root = consume root
      self.namespaces = consume namespaces
    }

    /// Compiles an XPath 1.0 expression string.
    ///
    /// - Parameter string: A valid XPath 1.0 expression.
    /// - Returns: A compiled ``Expression`` ready for evaluation.
    /// - Throws: ``XPath/Error/invalidExpression(_:)`` if `string` is not
    ///   valid XPath 1.0 syntax.
    public static func parse(_ string: borrowing String,
                             namespaces: consuming [String:String] = [:]) throws(XPath.Error) -> Expression {
      let string = copy string
      var parser = XPath.Parser(string)
      let root = try parser.expression()
      guard try parser.done() else {
        throw .invalidExpression("unexpected token after expression end")
      }
      var bindings = consume namespaces
      bindings["xml"] = "http://www.w3.org/XML/1998/namespace"
      return Expression(root: root, namespaces: bindings)
    }

    /// Evaluates this expression starting from the document root and returns
    /// the matching nodes in document order.
    ///
    /// Equivalent to ``nodes(in:)``.
    public func evaluate(in document: borrowing Document) throws(XPath.Error) -> [Document.Reference] {
      try nodes(in: document)
    }

    /// Evaluates this expression with `context` as the XPath context and
    /// returns the matching nodes in document order.
    ///
    /// Equivalent to ``nodes(in:with:)``.
    public func evaluate(in document: borrowing Document,
                         with context: borrowing XPath.Context) throws(XPath.Error) -> [Document.Reference] {
      try nodes(in: document, with: context)
    }

    /// Evaluates this expression and returns the number of matching nodes,
    /// without materialising the node-set array.
    ///
    /// For single-step location paths (including fused `//name` paths), the
    /// traversal counts in-place and allocates nothing beyond the initial
    /// context.  Falls back to `evaluate(in:).count` for multi-step paths and
    /// other expression kinds.
    public func count(in document: borrowing Document) throws(XPath.Error) -> Int {
      let context = XPath.Context(node: document.root)
      return try count(root, in: document, context: context)
    }

    /// Evaluates this expression as a node-set from the document root.
    ///
    /// Returns matching nodes in document order.
    public func nodes(in document: borrowing Document) throws(XPath.Error) -> [Document.Reference] {
      let context = XPath.Context(node: document.root)
      return try evaluate(root, in: document, context: context).nodes
    }

    /// Evaluates this expression as a node-set with `context` as the XPath
    /// context.
    ///
    /// Returns matching nodes in document order.
    public func nodes(in document: borrowing Document,
                      with context: borrowing XPath.Context) throws(XPath.Error) -> [Document.Reference] {
      return try evaluate(root, in: document, context: context).nodes
    }

    /// Evaluates this expression as an XPath string from the document root.
    ///
    /// For node-set results, returns the string value of the first node in
    /// document order, or an empty string if the set is empty.
    public func string(in document: borrowing Document) throws(XPath.Error) -> String {
      let context = XPath.Context(node: document.root)
      return try evaluate(root, in: document, context: context).string(in: document)
    }

    /// Evaluates this expression as an XPath string with `context` as the
    /// context.
    ///
    /// For node-set results, returns the string value of the first node in
    /// document order, or an empty string if the set is empty.
    public func string(in document: borrowing Document,
                       with context: borrowing XPath.Context) throws(XPath.Error) -> String {
      return try evaluate(root, in: document, context: context).string(in: document)
    }

    /// Evaluates this expression as an XPath number from the document root.
    public func number(in document: borrowing Document) throws(XPath.Error) -> Double {
      let context = XPath.Context(node: document.root)
      return try evaluate(root, in: document, context: context).number(in: document)
    }

    /// Evaluates this expression as an XPath number with `context` as the
    /// context.
    public func number(in document: borrowing Document,
                       with context: borrowing XPath.Context) throws(XPath.Error) -> Double {
      return try evaluate(root, in: document, context: context).number(in: document)
    }

    /// Evaluates this expression as an XPath boolean from the document root.
    public func bool(in document: borrowing Document) throws(XPath.Error) -> Bool {
      let context = XPath.Context(node: document.root)
      return try evaluate(root, in: document, context: context).boolean
    }

    /// Evaluates this expression as an XPath boolean with `context` as the
    /// context.
    public func bool(in document: borrowing Document,
                     with context: borrowing XPath.Context) throws(XPath.Error) -> Bool {
      return try evaluate(root, in: document, context: context).boolean
    }

    // MARK: - Syntax tree

    internal indirect enum Node {
      case path(LocationPath)
      case compose(Node, LocationPath)
      case filter(Node, [Node])  // FilterExpr: primary + predicates
      case union(Node, Node)
      case binary(BinaryOperation, Node, Node)
      case negate(Node)
      case function(String, [Node])
      case string(String)
      case number(Double)
      case bool(Bool)
      case variable(String)

      var positional: Bool {
        switch self {
        case .number: true
        case .function("position", _): true
        case .function("last", _): true
        case let .binary(operation, lhs, rhs):
          switch operation {
          // Arithmetic: result is a number — propagate position-sensitivity.
          case .add, .subtract, .multiply, .divide, .mod: lhs.positional || rhs.positional
          // Comparison/logical: result is always boolean, so a bare `.number` operand
          // (e.g. the 20 in `number(price) > 20`) does not make this positional.
          // Still require apply() when position() or last() appears anywhere inside,
          // since those calls need accurate context position/size.
          case .eq, .neq, .lt, .lte, .gt, .gte, .and, .or:
            lhs.contextual || rhs.contextual
          }
        case .negate(let expression): expression.positional
        case .compose(let primary, _): primary.positional
        case .filter(let primary, let predicates):
          primary.positional || predicates.contains(where: \.positional)
        default: false
        }
      }

      // True when position() or last() appears anywhere in this expression.
      // Used by binary comparison cases: the comparison evaluates to boolean
      // (not a number), yet still requires accurate context position/size.
      private var contextual: Bool {
        switch self {
        case .function("position", _): true
        case .function("last", _): true
        case let .binary(_, lhs, rhs): lhs.contextual || rhs.contextual
        case let .negate(expression): expression.contextual
        case let .compose(primary, _): primary.contextual
        case let .filter(primary, predicates):
          primary.contextual || predicates.contains(where: \.contextual)
        default: false
        }
      }

    }
  }
}
