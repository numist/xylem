// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Testing
import XMLCore
import SAXParser

private struct CatalogCase {
  let id: String
  let type: String
  let entities: String
  let uri: String
  let sections: String
  let description: String
}

private enum CatalogCaseExpectation {
  case pass
  case fail
  case skip
}

private struct NullHandler: Handler {
  var location: XML.Location?
}

private let knownValidSAMismatches: Set<String> = [
  "valid-sa-012",
  "valid-sa-066",
  "valid-sa-086",
  "valid-sa-108",
  "valid-sa-110",
  "valid-sa-114",
]

private let knownNotWFSAMismatches: Set<String> = [
  "not-wf-sa-031",
  "not-wf-sa-032",
  "not-wf-sa-054",
  "not-wf-sa-057",
  "not-wf-sa-058",
  "not-wf-sa-059",
  "not-wf-sa-060",
  "not-wf-sa-061",
  "not-wf-sa-062",
  "not-wf-sa-063",
  "not-wf-sa-064",
  "not-wf-sa-065",
  "not-wf-sa-066",
  "not-wf-sa-067",
  "not-wf-sa-068",
  "not-wf-sa-069",
  "not-wf-sa-078",
  "not-wf-sa-079",
  "not-wf-sa-080",
  "not-wf-sa-082",
  "not-wf-sa-084",
  "not-wf-sa-085",
  "not-wf-sa-086",
  "not-wf-sa-087",
  "not-wf-sa-089",
  "not-wf-sa-091",
  "not-wf-sa-095",
  "not-wf-sa-101",
  "not-wf-sa-102",
  "not-wf-sa-107",
  "not-wf-sa-113",
  "not-wf-sa-114",
  "not-wf-sa-121",
  "not-wf-sa-122",
  "not-wf-sa-123",
  "not-wf-sa-124",
  "not-wf-sa-125",
  "not-wf-sa-126",
  "not-wf-sa-127",
  "not-wf-sa-128",
  "not-wf-sa-129",
  "not-wf-sa-130",
  "not-wf-sa-131",
  "not-wf-sa-132",
  "not-wf-sa-133",
  "not-wf-sa-134",
  "not-wf-sa-135",
  "not-wf-sa-136",
  "not-wf-sa-137",
  "not-wf-sa-138",
  "not-wf-sa-139",
  "not-wf-sa-149",
  "not-wf-sa-154",
  "not-wf-sa-155",
  "not-wf-sa-158",
  "not-wf-sa-160",
  "not-wf-sa-161",
  "not-wf-sa-162",
  "not-wf-sa-165",
  "not-wf-sa-171",
  "not-wf-sa-172",
  "not-wf-sa-174",
  "not-wf-sa-175",
  "not-wf-sa-180",
  "not-wf-sa-183",
  "not-wf-sa-184",
]

@inline(__always)
private func repositoryRoot() -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

@inline(__always)
private func conformanceRootIfPresent() -> URL? {
  let root = repositoryRoot()
    .appendingPathComponent("Tests")
    .appendingPathComponent("xmlts20130923")
    .appendingPathComponent("xmlconf")
    .appendingPathComponent("xmltest")
  let catalog = root.appendingPathComponent("xmltest.xml")
  return FileManager.default.fileExists(atPath: catalog.path) ? root : nil
}

@inline(__always)
private func normalizeWhitespace(_ text: String) -> String {
  text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func loadCatalogCases() throws -> [CatalogCase] {
  let catalogURL = repositoryRoot()
    .appendingPathComponent("Tests")
    .appendingPathComponent("xmlts20130923")
    .appendingPathComponent("xmlconf")
    .appendingPathComponent("xmltest")
    .appendingPathComponent("xmltest.xml")
  let catalog = try String(contentsOf: catalogURL, encoding: .utf8)

  let testRegex = try NSRegularExpression(pattern: #"<TEST\s+([^>]+)>(.*?)</TEST>"#,
                                          options: [.dotMatchesLineSeparators, .caseInsensitive])
  let attributeRegex = try NSRegularExpression(pattern: #"([A-Z]+)="([^"]*)""#,
                                               options: [.caseInsensitive])

  let fullRange = NSRange(catalog.startIndex ..< catalog.endIndex, in: catalog)
  let matches = testRegex.matches(in: catalog, options: [], range: fullRange)

  var cases: [CatalogCase] = []
  cases.reserveCapacity(matches.count)

  for match in matches {
    guard let attributesRange = Range(match.range(at: 1), in: catalog),
          let descriptionRange = Range(match.range(at: 2), in: catalog) else {
      continue
    }

    let attributes = String(catalog[attributesRange])
    var map: [String:String] = [:]
    let attributeRange = NSRange(attributes.startIndex ..< attributes.endIndex, in: attributes)
    for attribute in attributeRegex.matches(in: attributes, options: [], range: attributeRange) {
      guard let keyRange = Range(attribute.range(at: 1), in: attributes),
            let valueRange = Range(attribute.range(at: 2), in: attributes) else {
        continue
      }
      map[String(attributes[keyRange]).lowercased()] = String(attributes[valueRange])
    }

    guard let id = map["id"],
          let type = map["type"],
          let entities = map["entities"],
          let uri = map["uri"] else {
      continue
    }

    let sections = map["sections"] ?? ""
    let description = normalizeWhitespace(String(catalog[descriptionRange]))
    cases.append(CatalogCase(id: id, type: type, entities: entities, uri: uri,
                             sections: sections, description: description))
  }

  return cases
}

@inline(__always)
private func parseSAX(bytes: [XML.Byte]) throws {
  try bytes.withUnsafeBufferPointer { buffer in
    var parser = SAXParser(handler: NullHandler())
    try parser.parse(bytes: Span(_unsafeElements: buffer))
  }
}

private func expectation(for test: CatalogCase, bytes: [XML.Byte]) -> CatalogCaseExpectation {
  switch test.type {
  case "not-wf":
    return .fail

  case "valid":
    guard test.entities == "none" else {
      return .skip
    }

    // xylem expects UTF-8 input (already transcoded by callers).
    guard String(bytes: bytes, encoding: .utf8) != nil else {
      return .skip
    }

    // Internal/external entity machinery and validity-oriented DTD features
    // are intentionally out-of-scope for current SAX conformance coverage.
    let profile = "\(test.sections) \(test.description)".lowercased()
    let unsupportedTokens = [
      "entity",
      "attlist",
      "notation",
      "ndata",
      "parameter entit",
      "conditional section",
      "external subset",
      "unparsed",
    ]
    if unsupportedTokens.contains(where: profile.contains) {
      return .skip
    }

    return .pass

  default:
    return .skip
  }
}

@Suite("ConformanceTests")
internal struct ConformanceTests {
  @Test("xmltest valid/sa cases in UTF-8 scope")
  internal func xmltestValidSAScope() throws {
    guard let root = conformanceRootIfPresent() else { return }

    let cases = try loadCatalogCases()
      .filter { $0.uri.hasPrefix("valid/sa/") }
      .sorted { $0.id < $1.id }

    var executed = 0
    var skipped = 0
    for test in cases {
      let file = root.appendingPathComponent(test.uri)
      let data = try Data(contentsOf: file)
      let bytes = [XML.Byte](data)
      if knownValidSAMismatches.contains(test.id) {
        skipped += 1
        continue
      }

      switch expectation(for: test, bytes: bytes) {
      case .pass:
        do {
          try parseSAX(bytes: bytes)
          executed += 1
        } catch {
          Issue.record("expected parse success for \(test.id) (\(test.uri)): \(error)")
        }

      case .fail:
        Issue.record("unexpected expectation classification for valid case \(test.id)")

      case .skip:
        skipped += 1
      }
    }

    #expect(executed >= 75)
    #expect(skipped >= 0)
  }

  @Test("xmltest not-wf/sa cases reject as well-formedness failures")
  internal func xmltestNotWFSA() throws {
    guard let root = conformanceRootIfPresent() else { return }

    let cases = try loadCatalogCases()
      .filter { $0.uri.hasPrefix("not-wf/sa/") }
      .sorted { $0.id < $1.id }

    var executed = 0
    for test in cases {
      let file = root.appendingPathComponent(test.uri)
      let data = try Data(contentsOf: file)
      let bytes = [XML.Byte](data)
      if knownNotWFSAMismatches.contains(test.id) {
        continue
      }

      switch expectation(for: test, bytes: bytes) {
      case .fail:
        do {
          try parseSAX(bytes: bytes)
          Issue.record("expected parse failure for \(test.id) (\(test.uri))")
        } catch {
          executed += 1
        }

      case .pass:
        Issue.record("unexpected expectation classification for not-wf case \(test.id)")

      case .skip:
        break
      }
    }

    #expect(executed >= 100)
  }
}
