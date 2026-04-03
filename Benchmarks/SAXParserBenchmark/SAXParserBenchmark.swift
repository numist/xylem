// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Benchmark
import XMLCore
import SAXParser

// MARK: - Fixtures

private let mixedBody = "<entry key=\"alpha\" flag='1'>value&amp;more<![CDATA[some cdata]]><?pi data?></entry>"
private let head: [XML.Byte] = Array("<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>".utf8)
private let tail: [XML.Byte] = Array("</root>".utf8)

private func document(body: String, note: String? = nil,
                      interval: Int = 1, size: Int) -> [XML.Byte] {
  var buffer: [XML.Byte] = []
  buffer.reserveCapacity(size + tail.count)
  buffer.append(contentsOf: head)
  var index = 0
  let body = Array(body.utf8)
  let note = note.map { Array($0.utf8) }
  while buffer.count + body.count + tail.count <= size {
    buffer.append(contentsOf: body)
    if let note, (index % interval) == 0,
       buffer.count + note.count + tail.count <= size {
      buffer.append(contentsOf: note)
    }
    index += 1
  }
  buffer.append(contentsOf: tail)
  return buffer
}

// MARK: - Handler

private struct CountingHandler: Handler {
  typealias Failure = Never
  var total: Int = 0

  mutating func declaration(version: Span<XML.Byte>, encoding: Span<XML.Byte>?,
                            standalone: Span<XML.Byte>?) throws(Never) {
    total &+= version.count
    if let encoding { total &+= encoding.count }
    if let standalone { total &+= standalone.count }
  }

  mutating func processing(target: Span<XML.Byte>, data: Span<XML.Byte>?) throws(Never) {
    total &+= target.count &+ (data?.count ?? 0)
  }

  mutating func comment(_ content: Span<XML.Byte>) throws(Never) {
    total &+= content.count
  }

  mutating func start(element name: XML.QualifiedNameView,
                      namespace uri: Span<XML.Byte>?,
                      attributes: XML.ResolvedAttributes) throws(Never) {
    total &+= name.bytes.count
    for index in attributes.indices {
      total &+= attributes.name(at: index).bytes.count
      total &+= attributes.value(at: index).count
    }
  }

  mutating func end(element name: XML.QualifiedNameView,
                    namespace uri: Span<XML.Byte>?) throws(Never) {
    total &+= name.bytes.count
  }

  mutating func characters(_ data: Span<XML.Byte>) throws(Never) {
    total &+= data.count
  }

  mutating func character(data: Span<XML.Byte>) throws(Never) {
    total &+= data.count
  }
}

@inline(never)
private func parseSAX(_ bytes: [XML.Byte]) throws -> Int {
  guard !bytes.isEmpty else { return 0 }
  var parser = SAXParser(handler: CountingHandler())
  try parser.parse(bytes: bytes.span)
  return parser.handler.total
}

// MARK: - Benchmarks

private let fixtures: [(name: String, bytes: [XML.Byte])] = [
  (
    "mixed-small",
    document(body: mixedBody, note: "<!-- note -->", interval: 16, size: 64 * 1024)
  ),
  (
    "mixed-medium",
    document(body: mixedBody, note: "<!-- note -->", interval: 16, size: 1024 * 1024)
  ),
  (
    "text-heavy",
    document(body: "<p>abcdefghijklmnopqrstuvwxyz0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ_+=!?:;/,.</p>",
             size: 1024 * 1024)
  ),
  (
    "attributes-heavy",
    document(body: "<entry a='1' b='two' c='three' d='four' e='five' f='six' g='seven' h='eight' i='nine' j='ten'/>",
             size: 1024 * 1024)
  ),
  (
    "namespace-heavy",
    document(body: "<p:entry xmlns:p='urn:p' xmlns:q='urn:q' xmlns:r='urn:r' q:key='alpha' r:flag='1'><q:item r:value='beta'/></p:entry>",
             size: 1024 * 1024)
  ),
  (
    "pi-heavy",
    document(body: "<?target alpha beta gamma?><entry/>", size: 1024 * 1024)
  ),
  (
    "comment-heavy",
    document(body: "<!-- this is a benchmark comment payload with punctuation: .,:;!? -->",
             size: 1024 * 1024)
  ),
  (
    "cdata-heavy",
    document(body: "<![CDATA[abcdefghijklmnopqrstuvwxyz0123456789<>/&'\"-_=+;:.]]><entry/>",
             size: 1024 * 1024)
  ),
]

nonisolated(unsafe) let benchmarks = {
  for (name, bytes) in fixtures {
    Benchmark("SAX/\(name)",
              configuration: .init(metrics: .all,
                                   scalingFactor: .kilo,
                                   maxDuration: .seconds(3),
                                   maxIterations: 10_000)) { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try parseSAX(bytes))
      }
    }
  }
}
