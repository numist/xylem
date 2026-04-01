// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

internal import XMLCore

extension XPath {
  internal enum NodeTest {
    case any(namespace: String? = nil)
    // hash: FNV-1a32 over the UTF-8 of `local`, computed at parse time for
    // fast pre-filtering in matches().
    case name(prefix: String?, local: String, hash: UInt32)
    case text
    case comment
    case processing(target: String? = nil)
    case node
  }
}

extension XPath.NodeTest {
  internal var unprefixed: (local: String, hash: UInt32)? {
    guard case .name(nil, let local, let hash) = self else { return nil }
    return (local, hash)
  }

  internal var hash: UInt32? {
    unprefixed?.hash
  }

  internal var namespaced: Bool {
    switch self {
    case .any(namespace: let ns): return ns != nil
    case .name(let prefix, _, _): return prefix != nil
    default:                      return false
    }
  }
}

extension XPath.NodeTest {
  internal init(name raw: String) {
    if let colon = raw.firstIndex(of: ":") {
      let prefix = String(raw[..<colon])
      let local  = String(raw[raw.index(after: colon)...])
      self = local == "*" ? .any(namespace: prefix)
                          : .name(prefix: prefix, local: local, hash: local.fnv1a32())
    } else {
      self = .name(prefix: nil, local: raw, hash: raw.fnv1a32())
    }
  }
}
