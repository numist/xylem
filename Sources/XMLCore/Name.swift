// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML {
  /// A view onto a single XML `Name` within a source span.
  ///
  /// `Name` borrows its storage from the enclosing ``XML/Lexer`` input; it
  /// does not own a copy of the bytes.
  public struct Name: ~Escapable {
    /// The raw UTF-8 bytes of the name, including any namespace prefix.
    public let bytes: Span<Byte>

    // [5]  Name ::= NameStartChar (NameChar)*
    @inline(__always)
    package static func scan(_ bytes: borrowing Span<Byte>) throws(XML.Error) -> (bytes: Int, characters: Int) {
      guard !bytes.isEmpty else { return (0, 0) }

      var cursor = 0
      var characters = 0

      @inline(__always)
      func advance(_ stride: Int = 1) {
        cursor += stride
        characters += 1
      }

      if bytes[0] < 0x80 {
        guard bytes[0].isXMLASCIINameStartChar else { throw .invalidName }
        advance()
      } else {
        guard let decoded = try bytes.decodeScalar(at: 0),
              decoded.scalar.isXMLNameStartChar else { throw .invalidName }
        advance(decoded.stride)
      }

      while cursor < bytes.count {
        if bytes[cursor] < 0x80 {
          guard bytes[cursor].isXMLASCIINameChar else { return (cursor, characters) }
          advance()
        } else {
          guard let decoded = try bytes.decodeScalar(at: cursor),
                decoded.scalar.isXMLNameChar else { return (cursor, characters) }
          advance(decoded.stride)
        }
      }

      return (cursor, characters)
    }

    /// Creates a `Name` without validating the byte content.
    ///
    /// The caller is responsible for ensuring `bytes` contains a valid XML
    /// `Name` sequence.
    @_lifetime(borrow bytes)
    public init(unvalidated bytes: borrowing Span<Byte>) {
      self.bytes = copy bytes
    }

    /// Creates a `Name` after verifying that `bytes` is a valid XML `Name`.
    ///
    /// - Throws: ``XML/Error/invalidName`` if the bytes are empty or contain
    ///   characters that are not permitted in an XML name.
    @_lifetime(borrow bytes)
    public init(validating bytes: borrowing Span<Byte>) throws(XML.Error) {
      guard !bytes.isEmpty, try Name.scan(bytes).bytes == bytes.count else {
        throw .invalidName
      }
      self.bytes = copy bytes
    }
  }
}

extension XML.Name {
  /// The local part of the name — the portion after the namespace prefix
  /// colon — or the full name when no prefix is present.
  public var local: Span<XML.Byte> {
    @_lifetime(borrow self) get {
      if let colon = bytes.first(UInt8(ascii: ":")) {
        return bytes.extracting((colon + 1)...)
      }
      return bytes
    }
  }
}
