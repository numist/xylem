// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

extension XML {
  /// A single lexical token produced by ``XML/Lexer``.
  ///
  /// Every associated `Span` borrows directly from the original input buffer;
  /// no copies are made during tokenisation.
  public enum Token: ~Escapable {
    /// A processing instruction: `<?target data?>`.
    case processing(target: Span<Byte>, data: Span<Byte>?)

    /// A comment: `<!-- … -->`.
    case comment(Span<Byte>)

    /// A CDATA section: `<![CDATA[ … ]]>`.
    case cdata(Span<Byte>)

    /// A document type declaration: `<!DOCTYPE name PUBLIC "…" "…">`.
    case doctype(name: Span<Byte>, `public`: Span<Byte>?, system: Span<Byte>?)

    /// A start tag — `<name attr="val">` — or an empty-element tag `<name/>`.
    ///
    /// `closed` is `true` for the self-closing `<name/>` form.
    case start(name: Span<Byte>, attributes: UnresolvedAttributes, closed: Bool)

    /// An end tag: `</name>`.
    case end(name: Span<Byte>)

    /// Character data between markup, including inter-element whitespace.
    case text(Span<Byte>)
  }
}
