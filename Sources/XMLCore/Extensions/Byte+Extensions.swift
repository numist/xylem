// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML.Byte {
  // ASCII NameStartChar per XML 1.0 §2.3
  // [4]: ':' | [A-Z] | '_' | [a-z]
  @inline(__always)
  package var isXMLASCIINameStartChar: Bool {
    switch self {
    case UInt8(ascii: ":"), UInt8(ascii: "_"),
         UInt8(ascii: "A") ... UInt8(ascii: "Z"),
         UInt8(ascii: "a") ... UInt8(ascii: "z"):
      true
    default:
      false
    }
  }

  // ASCII NameChar per XML 1.0 §2.3
  // [4a]: NameStartChar | '-' | '.' | [0-9]
  @inline(__always)
  package var isXMLASCIINameChar: Bool {
    switch self {
    case UInt8(ascii: "-"), UInt8(ascii: "."),
         UInt8(ascii: "0") ... UInt8(ascii: "9"):
      true
    default:
      self.isXMLASCIINameStartChar
    }
  }

  // [3]: S — XML whitespace.
  @inline(__always)
  package var isXMLASCIIWhitespace: Bool {
    self == UInt8(ascii: "\t") || self == UInt8(ascii: "\n") || self == UInt8(ascii: "\r") || self == UInt8(ascii: " ")
  }

  @inline(__always)
  package var isASCIIDigit: Bool {
    self >= UInt8(ascii: "0") && self <= UInt8(ascii: "9")
  }
}
