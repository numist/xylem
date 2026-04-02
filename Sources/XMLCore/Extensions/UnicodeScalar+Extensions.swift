// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

// XML 1.0 character grammar productions (https://www.w3.org/TR/xml/#charsets)

extension Unicode.Scalar {
  // [2]: Char — any legal XML 1.0 character.
  internal var isXMLChar: Bool {
    return switch value {
    case 0x0000_0009, 0x0000_000a, 0x0000_000d: true
    case 0x0000_0020 ... 0x0000_d7ff:           true
    case 0x0000_e000 ... 0x0000_fffd:           true
    case 0x0001_0000 ... 0x0010_ffff:           true
    default: false
    }
  }

  // [3]: S — XML whitespace.
  package var isXMLSpace: Bool {
    switch value {
    case 0x0000_0009, 0x0000_000a, 0x0000_000d, 0x0000_0020:
      true
    default:
      false
    }
  }

  // [4]: NameStartChar — valid first character of an XML Name.
  internal var isXMLNameStartChar: Bool {
    return switch value {
    case 0x0000_003a:                   true  // :
    case 0x0000_0041 ... 0x0000_005a:   true  // A-Z
    case 0x0000_005f:                   true  // _
    case 0x0000_0061 ... 0x0000_007a:   true  // a-z
    case 0x0000_00c0 ... 0x0000_00d6:   true
    case 0x0000_00d8 ... 0x0000_00f6:   true
    case 0x0000_00f8 ... 0x0000_02ff:   true
    case 0x0000_0370 ... 0x0000_037d:   true
    case 0x0000_037f ... 0x0000_1fff:   true
    case 0x0000_200c ... 0x0000_200d:   true
    case 0x0000_2070 ... 0x0000_218f:   true
    case 0x0000_2c00 ... 0x0000_2fef:   true
    case 0x0000_3001 ... 0x0000_d7ff:   true
    case 0x0000_f900 ... 0x0000_fdcf:   true
    case 0x0000_fdf0 ... 0x0000_fffd:   true
    case 0x0001_0000 ... 0x000e_ffff:   true
    default: false
    }
  }

  // [4a]: NameChar — valid subsequent character of an XML Name.
  internal var isXMLNameChar: Bool {
    return switch value {
    case 0x0000_002d, 0x0000_002e:    true    // -, .
    case 0x0000_0030 ... 0x0000_0039: true    // 0-9
    case 0x0000_00b7:                 true
    case 0x0000_0300 ... 0x0000_036f: true
    case 0x0000_203f ... 0x0000_2040: true
    default: self.isXMLNameStartChar
    }
  }
}
