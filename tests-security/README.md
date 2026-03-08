# CogLog v0.9.1 セキュリティテスト / Security Tests

11 言語実装すべてに対するセキュリティ特化テストスイート。`tests/` の機能テストを補完する。

Security-focused test suite for all 11 language implementations. Complements the functional tests in `tests/`.

## 前提条件 / Prerequisites

`tests/` と同じ — [tests/README.md](../tests/README.md) を参照。

Same as `tests/` — see [tests/README.md](../tests/README.md).

## ハーネス / Harnesses

| ハーネス / Harness | 優先度 / Priority | スコープ / Scope | 対象言語 / Languages |
|---|---|---|---|
| `harness-path.sh` | P0 | パストラバーサル、ファイルシステムエッジケース / Path traversal, filesystem edge cases | 11（全言語 / all） |
| `harness-tampering.sh` | P0 | データファイルの破損・改ざん耐性 / Data file corruption & tampering resistance | 11（全言語 / all） |
| `harness-input.sh` | P1 | 入力境界（大きなペイロード、特殊文字） / Input boundary (large payloads, special chars) | 11（全言語 / all） |
| `harness-mcp-security.sh` | P1 | MCP プロトコル違反・濫用 / MCP protocol violations & abuse | 10（bash 除外 / no bash） |
| `harness-concurrency.sh` | P2 | 並行 read/write/clear の競合状態 / Concurrent read/write/clear race conditions | 11（全言語 / all） |

## 使い方 / Usage

```bash
# 単一ハーネスを全言語で実行 / Run a single harness for all languages
./tests-security/harness-path.sh all

# 特定言語を実行 / Run specific languages
./tests-security/harness-input.sh rust python node

# 全セキュリティテストを実行 / Run all security tests
for h in tests-security/harness-*.sh; do "$h" all; done
```

## ディレクトリ構成 / Directory Structure

```
tests-security/
├── common.sh                  # 共有ユーティリティ（ハーネスから source される） / Shared utilities (sourced by harnesses)
├── fixtures-security/         # セキュリティテスト用フィクスチャ / Security test fixtures
│   ├── control-chars.json
│   ├── extra-fields.json
│   ├── tampered-negative-tid.json
│   ├── tampered-no-schema.json
│   └── unicode-edge.json
├── harness-concurrency.sh     # P2: 競合状態 / Race conditions
├── harness-input.sh           # P1: 入力境界 / Input boundary
├── harness-mcp-security.sh    # P1: MCP プロトコル濫用 / MCP protocol abuse
├── harness-path.sh            # P0: パストラバーサル・ファイルシステム / Path traversal & filesystem
├── harness-tampering.sh       # P0: データファイル改ざん / Data file tampering
└── README.md                  # 本ファイル / This file
```

## 設計方針 / Design

- `common.sh` は `tests/harness.sh` および `tests/harness-mcp.sh` から抽出した共有関数（CLI ランナー、MCP セッション管理、ビルドヘルパー）を提供する

  `common.sh` sources shared functions (CLI runners, MCP session management, build helpers) extracted from `tests/harness.sh` and `tests/harness-mcp.sh`

- 全ハーネスは `tests/` と同一の `pass()`/`fail()`/`skip()` パターンに従う

  All harnesses follow the same `pass()`/`fail()`/`skip()` pattern as `tests/`

- テストは「成功」と「正常な拒否」の両方を有効な挙動として受け入れる。重要な性質は**クラッシュなし、データ破損なし、サイレントなデータ喪失なし**であること

  Tests accept both "success" and "graceful rejection" as valid behaviors — the key property is **no crash, no corruption, no silent data loss**
