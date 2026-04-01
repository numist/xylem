// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML {
  package struct AttributeIterator: ~Copyable, ~Escapable {
    private let bytes: Span<Byte>
    private var cursor: Span<Byte>.Index = 0
    private var initial = true

    @_lifetime(borrow bytes)
    package init(bytes: borrowing Span<Byte>) {
      self.bytes = copy bytes
    }

    @inline(__always)
    @_lifetime(self: copy self)
    private mutating func advance(_ stride: Int = 1) {
      cursor += stride
    }

    @inline(__always)
    @_lifetime(self: copy self)
    @_lifetime(&self)
    private mutating func spaces() -> Bool {
      let start = cursor
      while cursor < bytes.count, bytes[cursor].isXMLASCIIWhitespace {
        advance()
      }
      return cursor > start
    }

    // Attribute ::= Name Eq AttValue
    // Eq         ::= S? '=' S?
    // AttValue   ::= '"' ([^<&"] | Reference)* '"'
    //              | "'" ([^<&'] | Reference)* "'"
    @_lifetime(self: copy self)
    @_lifetime(&self)
    package mutating func next() throws(XML.Error) -> (name: Range<Span<Byte>.Index>, value: Range<Span<Byte>.Index>, processed: Bool)? {
      guard cursor < bytes.count else { return nil }

      // S — inter-attribute whitespace is only required after the first attribute.
      if !initial {
        guard spaces() else { throw .invalidCharacter }
        guard cursor < bytes.count else { return nil }
      }
      initial = false

      // Name
      let length = try XML.Name.scan(bytes.extracting(cursor...)).bytes
      guard length > 0 else { throw .unexpectedEOF }
      let name = cursor ..< cursor + length
      advance(length)

      // Eq: S? '=' S?
      _ = spaces()
      guard cursor < bytes.count, bytes[cursor] == UInt8(ascii: "=") else {
        throw .invalidCharacter
      }
      advance()
      _ = spaces()

      // AttValue
      guard cursor < bytes.count else { throw .unexpectedEOF }
      let quote = bytes[cursor]
      guard quote == UInt8(ascii: "\"") || quote == UInt8(ascii: "'") else {
        throw .invalidCharacter
      }
      advance()

      let start = cursor
      var processed = true
      while cursor < bytes.count {
        let byte = bytes[cursor]
        switch byte {
        case quote:
          let value = start ..< cursor
          advance()
          return (name, value, processed)

        case UInt8(ascii: "<"):
          throw .invalidCharacter

        case _ where byte < 0x80:
          switch byte {
          case UInt8(ascii: "&"), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r"):
            processed = false
            fallthrough
          case 0x20...:
            advance()
          default:
            throw .invalidCharacter
          }

        default:
          guard let decoded = try bytes.decodeScalar(at: cursor),
                decoded.scalar.isXMLChar else {
            throw .invalidCharacter
          }
          advance(decoded.stride)
        }
      }

      throw .unexpectedEOF
    }
  }
}
