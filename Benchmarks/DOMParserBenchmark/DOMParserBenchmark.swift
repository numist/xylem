// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Benchmark
import XMLCore
import DOMParser

// MARK: - Fixtures

private let mixedBody = "<entry key=\"alpha\" flag='1'>value&amp;more<![CDATA[some cdata]]><?pi data?></entry>"
private let head: [XML.Byte] = Array("<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>".utf8)
private let tail: [XML.Byte] = Array("</root>".utf8)

private func document(body: String, note: String? = nil, interval: Int = 1, size: Int) -> [XML.Byte] {
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

// MARK: - DOM parse + walk

@inline(never)
@_lifetime(borrow bytes)
private func parse(_ bytes: Span<XML.Byte>) throws -> Int {
  let document = try DOMParser.parse(bytes: bytes)
  var total = 0
  var stack: [Document.Reference] = []
  if let child = document.firstChild(of: document.root) { stack.append(child) }
  while let reference = stack.popLast() {
    let kind = document.kind(of: reference)
    if kind == .text || kind == .cdata {
      let view = document.view(of: reference)
      if let bytes = view.value { total &+= bytes.count }
    }
    if let sibling = document.nextSibling(of: reference) { stack.append(sibling) }
    if let child = document.firstChild(of: reference) { stack.append(child) }
  }
  return total
}

@inline(never)
private func parse(_ bytes: [XML.Byte]) throws -> Int {
  guard !bytes.isEmpty else { return 0 }
  return try parse(bytes.span)
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
    document(body: "<?target alpha beta gamma?><entry/>",
             size: 1024 * 1024)
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
    Benchmark("DOM/\(name)",
              configuration: .init(metrics: .all,
                                   scalingFactor: .kilo,
                                   maxDuration: .seconds(3),
                                   maxIterations: 10_000)) { benchmark in
      for _ in benchmark.scaledIterations {
        blackHole(try parse(bytes))
      }
    }
  }
}
