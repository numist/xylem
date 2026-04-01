// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML {
  /// An expanded XML name resolved against a namespace context.
  ///
  /// Unlike ``XML/QualifiedName``, this stores the namespace URI rather than
  /// the lexical prefix, so names that differ only by prefix but resolve to
  /// the same URI compare equal.
  public struct ExpandedName: Hashable {
    public let namespace: String?
    public let local: String

    public init(namespace: String? = nil, local: String) {
      self.namespace = namespace
      self.local = local
    }

    /// Creates an expanded name by resolving an XML qualified name against a
    /// namespace context.
    ///
    /// Unqualified names remain in no namespace. Prefixed names fail to
    /// initialize when the prefix is not bound in `namespaces`.
    public init?(expanding name: borrowing String, using namespaces: borrowing [String: String]) {
      if let colon = name.firstIndex(of: ":") {
        let prefix = String(name[..<colon])
        let local = String(name[name.index(after: colon)...])
        guard let namespace = namespaces[prefix] else { return nil }
        self.init(namespace: namespace, local: local)
      } else {
        self.init(local: copy name)
      }
    }
  }
}
