# Xylem

A fast, memory-safe XML parser written in pure Swift. Xylem targets UTF-8 XML 1.0 well-formedness with namespace-aware SAX/DOM parsing and XPath 1.0. It does not implement DTD validation, external entity resolution, XSLT, or schema validation — by design.

## Why Xylem

- **Fast.** The repository includes reproducible SAX, DOM, and XPath benchmarks over representative fixtures. Use them for change-to-change regression tracking on your hardware.
- **Safe.** No external entity resolution and no user-defined entity expansion from DTD declarations. This keeps XXE-style resolution paths out of scope. Memory safety is enforced by the language, not by discipline.
- **Modular.** Use only what you need. SAX, DOM, and XPath are separate modules built on a shared `XMLCore`. An embedded target that only needs streaming parsing pulls in `SAXParser` alone — no DOM allocator, no XPath evaluator.
- **Zero dependencies.** Pure Swift. No Foundation, no C, no iconv, no system libraries.
- **Cross-platform.** Runs anywhere the Swift compiler targets — macOS, Linux, Windows, WASM, embedded.

## Modules

| Module | Purpose |
|---|---|
| `XMLCore` | Currency types shared across all modules. Not intended for direct use. |
| `SAXParser` | Zero-copy, event-driven streaming parser. |
| `DOMParser` | Flat-arena document tree with no per-node heap allocation. |
| `XPath` | XPath 1.0 expression evaluator over DOM documents. |

## What Xylem Supports

**XML 1.0 (UTF-8 well-formedness profile):** Elements, attributes, namespace declaration/resolution (default + prefixed bindings), strict QName checks (single `:`, valid prefix/local forms), processing instructions, CDATA sections, comments, DOCTYPE tokenization (name + public/system IDs), character references, and predefined entities (`&amp;`, `&lt;`, `&gt;`, `&apos;`, `&quot;`).

**XML declaration:** `version` is required and must be `1.0`; optional `encoding` and `standalone` pseudo-attributes are parsed (`standalone` must be `yes` or `no`).

**XPath 1.0:** 12 of 13 axes (namespace axis is parsed but returns no nodes), all node tests, predicates, union, arithmetic/comparison operators, all 27 core functions. Variables are parsed but evaluate to the empty set (relevant only in XSLT contexts).

**Parsing APIs:** Event-driven SAX-style streaming, document tree construction, XPath evaluation.

## What Xylem Does Not Support

These omissions are deliberate — they reduce attack surface, binary size, and complexity.

- DTD validation semantics (`<!ELEMENT>`, `<!ATTLIST>`, `<!ENTITY>`, `<!NOTATION>`, conditional sections)
- User-defined entity expansion from DTD declarations
- External entity resolution
- Full XML 1.1 semantics
- Encoding declarations / non-UTF-8 input
- Full XML Namespaces conformance-suite matrix coverage (current automated XMLTS profile is not namespace-specific groups)
- XInclude
- Canonical XML (C14N)
- Streaming / pull reader
- Push parser
- XSLT
- XML Schema (XSD) / RelaxNG
- XQuery
- XPath 2.0+

Xylem assumes well-formed, UTF-8-encoded XML input.

## Implementation Snapshot

Current architecture is split into four modules:

- `XMLCore`: UTF-8-first lexer/token model, scalar/name validation, entity expansion, and shared byte-span utilities.
- `SAXParser`: streaming parser with namespace resolution, strict well-formedness state tracking, and callback-based processing.
- `DOMParser`: flat-arena document builder on top of SAX events (single storage arena, stable references, no per-node heap allocation).
- `XPath`: XPath 1.0 parser/evaluator over DOM documents with strict type/error behavior.

Current conformance/testing posture:

- UTF-8 XML 1.0 well-formedness is the primary target.
- Namespace behavior (scope, QName validity, reserved bindings, duplicate expanded-name checks) is covered in focused SAX/DOM unit tests.
- DTD internal subset/entity-declaration semantics are tracked by disabled tests and explicit conformance allowlists.
- Conformance coverage includes focused DOM/SAX suites plus XMLTS-driven `ConformanceTests` (`valid/sa` + `not-wf/sa`, scoped for current feature set and not namespace-specific XMLTS groups).

## Requirements

- Swift 6.2+

## Running Tests

```bash
swift test
```

Run a specific suite:

```bash
swift test --filter SAXParser
swift test --filter DOMParser
swift test --filter XPath
swift test --filter ConformanceTests
```

## Conformance Tests (XMLTS)

`ConformanceTests` use the W3C XML Test Suite artifact (`xmlts20130923`) from the canonical source.

Fetch via SwiftPM command plugin:

```bash
swift package plugin --allow-writing-to-package-directory xmlts -- --fetch
```

Verify local artifact:

```bash
swift package plugin --allow-writing-to-package-directory xmlts -- --verify
```

The plugin verifies SHA-256 before extraction.

Run conformance-only:

```bash
swift test --filter ConformanceTests
```

## Benchmarks

For benchmark setup, fixtures, and baseline workflows, see [Benchmarks/BENCHMARKING.md](Benchmarks/BENCHMARKING.md).

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.
