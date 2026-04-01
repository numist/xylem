# Benchmarking Guide

This document is a quick reference for xylem benchmark setup, fixtures, and baseline workflows.

## Prerequisites

- Swift 6.2+ toolchain
- macOS or Linux host
- `jemalloc` disabled unless explicitly installed

Set:

```sh
export BENCHMARK_DISABLE_JEMALLOC=1
```

## Benchmark Targets

| Target | Measures | Fixture sizes |
|--------|----------|---------------|
| `SAXParserBenchmark` | Streaming parse throughput via `SAXParser` + counting handler | 64 KB -- 1 MB |
| `DOMParserBenchmark` | `DOMParser.parse()` + text/CDATA byte walk | 64 KB -- 1 MB |
| `XPathBenchmark` | `DOMParser.parse()` + `XPath.Expression` evaluation | 64 KB -- 1 MB |

## Fixtures

Fixtures are synthetic XML documents generated to a target byte size.

### SAX and DOM

| Name | Body pattern | Focus |
|------|-------------|-------|
| `mixed-small` (64 KB) | Elements, attributes, text, entities, CDATA, PIs, comments | Balanced small-input workload |
| `mixed-medium` (1 MB) | Same | Balanced medium-input workload |
| `text-heavy` | `<p>long ASCII text...</p>` | Text scanning throughput |
| `attributes-heavy` | `<entry a='1' b='two' ... j='ten'/>` | Attribute scanning, normalization, dedup |
| `namespace-heavy` | `<p:entry xmlns:p='...' ...>` | Namespace declaration/lookup and expanded-name dedup |
| `pi-heavy` | `<?target alpha beta gamma?>` | Processing-instruction scanning |
| `comment-heavy` | `<!-- comment payload -->` | Comment scanning |
| `cdata-heavy` | `<![CDATA[content...]]>` | CDATA scanning |

### XPath

Uses `mixed-small` and `mixed-medium` with these expressions:

| Name | Expression | Focus |
|------|-----------|-------|
| `child-axis` | `/root/entry` | Direct child traversal |
| `descendant` | `//entry` | Descendant traversal |
| `with-predicate` | `//entry[@key]` | Predicate evaluation |

## Baselines and Comparison

Create/update a baseline:

```sh
swift package --allow-writing-to-package-directory benchmark baseline update macos-arm64
swift package --allow-writing-to-package-directory benchmark baseline update macos-arm64 --target SAXParserBenchmark
```

Compare against a saved baseline:

```sh
swift package benchmark baseline compare macos-arm64
swift package benchmark baseline compare macos-arm64 --target SAXParserBenchmark
swift package benchmark baseline compare macos-arm64 --metric wallClock
```

Check regression thresholds:

```sh
swift package benchmark baseline check macos-arm64
```

Manage baselines:

```sh
swift package benchmark baseline list
swift package --allow-writing-to-package-directory benchmark baseline delete old-baseline
```

Baseline storage path:

```text
.benchmarkBaselines/<BenchmarkTarget>/<BaselineName>/results.json
```
