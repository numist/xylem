// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

// XML 1.0 character grammar productions (https://www.w3.org/TR/xml/#charsets)

extension Unicode.Scalar {
  // [2]: Char — any legal XML 1.0 character.
  internal var isXMLChar: Bool {
    return switch value {
    case 0x0009, 0x000a, 0x000d: true
    case 0x0020 ... 0x0d7ff:     true
    case 0x0e000 ... 0x0fffd:    true
    case 0x10000 ... 0x10ffff:   true
    default:                     false
    }
  }

  // [3]: S — XML whitespace.
  package var isXMLSpace: Bool {
    switch value {
    case 0x0009, 0x000a, 0x000d, 0x0020:
      true
    default:
      false
    }
  }

  // [4]: NameStartChar — valid first character of an XML Name.
  internal var isXMLNameStartChar: Bool {
    return switch value {
    case 0x0003a:             true  // :
    case 0x00041 ... 0x0005a: true  // A-Z
    case 0x0005f:             true  // _
    case 0x00061 ... 0x0007a: true  // a-z
    case 0x000c0 ... 0x000d6: true
    case 0x000d8 ... 0x000f6: true
    case 0x000f8 ... 0x002ff: true
    case 0x00370 ... 0x0037d: true
    case 0x0037f ... 0x01fff: true
    case 0x0200c ... 0x0200d: true
    case 0x02070 ... 0x0218f: true
    case 0x02c00 ... 0x02fef: true
    case 0x03001 ... 0x0d7ff: true
    case 0x0f900 ... 0x0fdcf: true
    case 0x0fdf0 ... 0x0fffd: true
    case 0x10000 ... 0xeffff: true
    default: false
    }
  }

  // [4a]: NameChar — valid subsequent character of an XML Name.
  internal var isXMLNameChar: Bool {
    return switch value {
    case 0x002d, 0x002e:    true    // -, .
    case 0x0030 ... 0x0039: true    // 0-9
    case 0x00b7:            true
    case 0x0300 ... 0x036f: true
    case 0x203f ... 0x2040: true
    default: self.isXMLNameStartChar
    }
  }
}
