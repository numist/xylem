// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML {
  /// Errors thrown by the XML lexer and parser.
  public enum Error: Swift.Error {
    /// An attribute is malformed or duplicated.
    case invalidAttribute
    /// A character is not permitted at its position by the XML 1.0 grammar.
    case invalidCharacter
    /// The document structure violates XML 1.0 well-formedness constraints.
    case invalidDocument
    /// The byte stream uses an encoding that cannot be decoded.
    case invalidEncoding
    /// A name does not conform to the XML 1.0 `Name` production.
    case invalidName
    /// The input ended before the document was complete.
    case unexpectedEOF
  }
}
