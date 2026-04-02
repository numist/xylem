// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Benchmark
import XMLCore
import DOMParser
import XPath

// MARK: - Fixtures

private let body = "<entry key=\"alpha\" flag='1'>value&amp;more<![CDATA[some cdata]]><?pi data?></entry>"
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

// MARK: - XPath parse + evaluate

@inline(never)
private func evaluate(_ bytes: Span<XML.Byte>,
                       expression: XPath.Expression) throws -> Int {
  let document = try DOMParser.parse(bytes: bytes)
  return try expression.count(in: document)
}

@inline(never)
private func evaluate(_ bytes: [XML.Byte], expression: XPath.Expression) throws -> Int {
  try bytes.withUnsafeBufferPointer { buffer throws in
    guard !buffer.isEmpty else { return 0 }
    return try evaluate(buffer.span, expression: expression)
  }
}

// MARK: - Benchmarks

private let fixtures: [(name: String, bytes: [XML.Byte])] = [
  (
    "mixed-small",
    document(body: body, note: "<!-- note -->", interval: 16, size: 64 * 1024)
  ),
  (
    "mixed-medium",
    document(body: body, note: "<!-- note -->", interval: 16, size: 1024 * 1024)
  ),
]

private let queries: [(name: String, expression: String)] = [
  ("child-axis", "/root/entry"),
  ("descendant", "//entry"),
  ("with-predicate", "//entry[@key]"),
]

nonisolated(unsafe) let benchmarks = {
  for (queryName, queryStr) in queries {
    let compiled = try! XPath.Expression.parse(queryStr)
    for (fixtureName, bytes) in fixtures {
      Benchmark("XPath/\(queryName)/\(fixtureName)",
                configuration: .init(metrics: .all,
                                     scalingFactor: .kilo,
                                     maxDuration: .seconds(3),
                                     maxIterations: 10_000)) { benchmark in
        for _ in benchmark.scaledIterations {
          blackHole(try evaluate(bytes, expression: compiled))
        }
      }
    }
  }
}
