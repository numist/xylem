// Copyright © 2026 Saleem Abdulrasool <compnerd@compnerd.org>
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
#if os(Windows)
import FoundationNetworking
#endif
import PackagePlugin

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import CryptoKit
#elseif os(Windows)
import WinSDK
#endif

// MARK: - SHA-256

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)

private func sha256(_ bytes: [UInt8]) throws -> String {
  CryptoKit.SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
}

#elseif os(Windows)

private func sha256(_ bytes: [UInt8]) throws -> String {
  var status: NTSTATUS

  var hAlgorithm: BCRYPT_ALG_HANDLE?
  status = "SHA256".withCString(encodedAs: UTF16.self) {
    BCryptOpenAlgorithmProvider(&hAlgorithm, $0, nil, 0)
  }
  guard status >= 0, let hAlgorithm else {
    throw PluginError.downloadFailed("BCryptOpenAlgorithmProvider failed: \(status)")
  }
  defer { _ = BCryptCloseAlgorithmProvider(hAlgorithm, 0) }

  var hHash: BCRYPT_HASH_HANDLE?
  status = BCryptCreateHash(hAlgorithm, &hHash, nil, 0, nil, 0, 0)
  guard status >= 0, let hHash else {
    throw PluginError.downloadFailed("BCryptCreateHash failed: \(status)")
  }
  defer { _ = BCryptDestroyHash(hHash) }

  var input = bytes
  status = BCryptHashData(hHash, &input, ULONG(input.count), 0)
  guard status >= 0 else {
    throw PluginError.downloadFailed("BCryptHashData failed: \(status)")
  }

  var digest = Array<UInt8>(repeating: 0, count: 32)
  status = BCryptFinishHash(hHash, &digest, ULONG(digest.count), 0)
  guard status >= 0 else {
    throw PluginError.downloadFailed("BCryptFinishHash failed: \(status)")
  }

  return digest.map { String(format: "%02x", $0) }.joined()
}

#else

#error("unsupported host: SHA-256 requires CryptoKit (Apple) or BCrypt (Windows)")

#endif

// MARK: - Metadata

private struct Manifest {
  let name: String
  let version: String
  let url: String
  let sha256: String
  let contentLength: Int
  let etag: String
  let lastModified: String
  let catalog: String

  static let xmlts = Manifest(
    name: "W3C XML Conformance Test Suites",
    version: "20130923",
    url: "https://www.w3.org/XML/Test/xmlts20130923.zip",
    sha256: "f9510b3532926e1b4c2e54855b021e4b8a66ec98a5337dcf4ff07e8a41968deb",
    contentLength: 1574648,
    etag: "\"1806f8-4e70a4975f8c0\"",
    lastModified: "Mon, 23 Sep 2013 10:14:35 GMT",
    catalog: "xmlconf/xmlconf.xml"
  )
}

// MARK: - Errors

private enum PluginError: Error, CustomStringConvertible {
  case downloadFailed(String)
  case sha256Mismatch(expected: String, actual: String)
  case sizeMismatch(expected: Int, actual: Int)
  case etagMismatch(expected: String, actual: String)
  case extractionFailed(Int32)
  case catalogMissing(String)
  case provenanceMismatch
  case artifactMissing(String)

  var description: String {
    switch self {
    case .downloadFailed(let message):
      "download failed: \(message)"
    case .sha256Mismatch(let expected, let actual):
      "archive SHA-256 mismatch:\n  expected: \(expected)\n  actual:   \(actual)"
    case .sizeMismatch(let expected, let actual):
      "archive size mismatch:\n  expected: \(expected)\n  actual:   \(actual)"
    case .etagMismatch(let expected, let actual):
      "ETag mismatch:\n  expected: \(expected)\n  actual:   \(actual)"
    case .extractionFailed(let status):
      "extraction failed with exit status \(status)"
    case .catalogMissing(let path):
      "expected catalog not found: \(path)"
    case .provenanceMismatch:
      "local provenance does not match current manifest"
    case .artifactMissing(let path):
      "XMLTS artifact missing: \(path)"
    }
  }
}

private struct ResponseHeaders {
  var contentLength: Int
  var etag: String?
  var lastModified: String?
  var contentType: String?
}

// MARK: - Plugin

@main
struct XMLTSPlugin: CommandPlugin {
  func performCommand(context: PluginContext, arguments: [String]) async throws {
    let root = context.package.directoryURL
    let destination = root
      .appendingPathComponent("Tests")
      .appendingPathComponent("xmlts20130923")
    let url = destination.appendingPathComponent(".artifact.json")

    let arguments = arguments.first == "--" ? Array(arguments.dropFirst()) : arguments
    let refresh = arguments.contains("--fetch")
    let verify = arguments.contains("--verify")

    let manifest = Manifest.xmlts

    if verify {
      return try self.verify(manifest: manifest, destination: destination, provenance: url)
    }

    let catalogURL = destination.appendingPathComponent(manifest.catalog)
    if FileManager.default.fileExists(atPath: catalogURL.path) && !refresh {
      print("XMLTS artifact already present at \(destination.path)")
      return
    }

    let temp = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }

    let download = temp.appendingPathComponent("xmlts20130923.zip")

    print("Downloading \(manifest.url) ...")
    let headers = try await self.download(from: manifest.url, to: download)

    print("Verifying archive integrity ...")
    try verifyArchive(at: download, manifest: manifest, headers: headers)

    print("Extracting to \(destination.path) ...")
    let extracted = temp.appendingPathComponent("extracted")
    try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
    try unzip(archive: download, to: extracted)

    if refresh && FileManager.default.fileExists(atPath: destination.path) {
      try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    for entry in try FileManager.default.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil) {
      try FileManager.default.moveItem(at: entry, to: destination.appendingPathComponent(entry.lastPathComponent))
    }

    guard FileManager.default.fileExists(atPath: catalogURL.path) else {
      throw PluginError.catalogMissing(catalogURL.path)
    }

    try writeProvenance(manifest: manifest, headers: headers, to: url)
    print("Done: \(destination.path)")
    print("Catalog: \(catalogURL.path)")
  }

  // MARK: - Download

  private func download(from urlString: String, to destination: URL) async throws -> ResponseHeaders {
    guard let url = URL(string: urlString) else {
      throw PluginError.downloadFailed("invalid URL: \(urlString)")
    }
    var request = URLRequest(url: url)
    request.setValue("xylem-xmlts-fetch/1", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 120

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse,
          (200...299).contains(http.statusCode) else {
      let code = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw PluginError.downloadFailed("HTTP \(code)")
    }

    try data.write(to: destination)

    return ResponseHeaders(
      contentLength: Int(http.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0,
      etag: http.value(forHTTPHeaderField: "ETag"),
      lastModified: http.value(forHTTPHeaderField: "Last-Modified"),
      contentType: http.value(forHTTPHeaderField: "Content-Type")
    )
  }

  // MARK: - Verification

  private func sha256Of(_ url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return try sha256(Array(data))
  }

  private func verifyArchive(at archive: URL, manifest: Manifest, headers: ResponseHeaders) throws {
    let actualSHA = try sha256Of(archive)
    guard actualSHA.lowercased() == manifest.sha256.lowercased() else {
      throw PluginError.sha256Mismatch(expected: manifest.sha256, actual: actualSHA)
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: archive.path)
    let actualSize = (attributes[.size] as? Int) ?? 0
    guard actualSize == manifest.contentLength else {
      throw PluginError.sizeMismatch(expected: manifest.contentLength, actual: actualSize)
    }

    if let etag = headers.etag, etag != manifest.etag {
      throw PluginError.etagMismatch(expected: manifest.etag, actual: etag)
    }
  }

  // MARK: - Extraction

  private func unzip(archive: URL, to destination: URL) throws {
    let process = Process()
    #if os(Windows)
    process.executableURL = URL(fileURLWithPath: "C:/Windows/System32/tar.exe")
    process.arguments = ["-xf", archive.path, "-C", destination.path]
    #else
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", "-o", archive.path, "-d", destination.path]
    #endif
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw PluginError.extractionFailed(process.terminationStatus)
    }
  }

  // MARK: - Provenance

  private func writeProvenance(manifest: Manifest, headers: ResponseHeaders, to url: URL) throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let record: [String: Any] = [
      "catalog": manifest.catalog,
      "fetched_at_utc": formatter.string(from: Date()),
      "headers": [
        "content_length": headers.contentLength,
        "content_type": headers.contentType as Any,
        "etag": headers.etag as Any,
        "last_modified": headers.lastModified as Any,
      ] as [String: Any],
      "name": manifest.name,
      "sha256": manifest.sha256,
      "url": manifest.url,
      "version": manifest.version,
    ]

    var data = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
    data.append(contentsOf: [0x0a])  // trailing newline
    try data.write(to: url)
  }

  // MARK: - Local verification

  private func verify(manifest: Manifest, destination: URL, provenance: URL) throws {
    let catalogURL = destination.appendingPathComponent(manifest.catalog)
    guard FileManager.default.fileExists(atPath: catalogURL.path) else {
      print("XMLTS artifact missing: \(catalogURL.path)")
      print("Run: swift package plugin --allow-writing-to-package-directory xmlts")
      throw PluginError.artifactMissing(catalogURL.path)
    }

    if FileManager.default.fileExists(atPath: provenance.path) {
      let data = try Data(contentsOf: provenance)
      guard let record = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            record["sha256"] as? String == manifest.sha256,
            record["url"] as? String == manifest.url else {
        print("warning: local provenance does not match current manifest")
        throw PluginError.provenanceMismatch
      }
      print("XMLTS artifact verified at \(destination.path)")
    } else {
      print("XMLTS artifact present at \(destination.path) (no provenance file found)")
      print("Run with --fetch to re-fetch and write provenance.")
    }
  }
}
