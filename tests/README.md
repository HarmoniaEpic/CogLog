# CogLog v0.9.1 テスト / Tests

11 言語実装すべてに対する 2 層テストアーキテクチャ。

Two-layer test architecture for all 11 language implementations.

## 前提条件 / Prerequisites

- `bash`（v4 以上推奨。テストハーネスは Bash スクリプト）
- `jq`（JSON 処理、必須）

- `bash` (v4+ recommended; test harnesses are Bash scripts)
- `jq` (JSON processing, required)

### 言語ツールチェーン / Language Toolchains

各言語のツールチェーンがインストールされている必要がある。ハーネスは実行前に必要なコマンドの存在を確認し、**ツールチェーンが見つからない言語は自動的にスキップ**される（サマリーに SKIP と表示）。

Each language requires its toolchain to be installed. The harness checks for the required command before running tests; **languages whose toolchain is not found are automatically skipped** (reported as SKIP in the summary).

| 言語 / Language | 必要なコマンド / Required command(s) | 備考 / Notes |
|----------|-------------------|-------|
| Rust | `cargo` | `cargo run` でビルド・実行 / Builds and runs via `cargo run` |
| Python | `python3` | |
| Node | `node` | |
| Go | `go` | `go run` でビルド・実行 / Builds and runs via `go run` |
| Ruby | `ruby` | |
| Java | `java`, `javac` | JAR 自動ビルド。`mvn` があれば使用、なければ `javac`/`jar` にフォールバック / JAR auto-built; uses `mvn` if available, falls back to `javac`/`jar` |
| C# | `dotnet` | `dotnet run` でビルド・実行 / Builds and runs via `dotnet run` |
| Haskell | `cabal` | `cabal run` でビルド・実行 / Builds and runs via `cabal run` |
| Common Lisp | `sbcl` | Recurrent Quine テストにも必要 / Also required for Recurrent Quine tests |
| C++ | `c++` | ソースからバイナリを自動ビルド / Binary auto-built from source |
| Bash | *（常に利用可能 / always available）* | Layer 1 のみ（MCP なし） / Layer 1 only (no MCP) |

## Layer 1: CLI ブラックボックステスト / CLI Black-Box Tests

単一のシェルスクリプトで 11 言語すべてを同一の CLI インターフェースで駆動する。

A single shell script drives all 11 language implementations through the same CLI interface.

```bash
# 全言語を実行 / Run all languages
./tests/harness.sh all

# 特定言語を実行 / Run specific languages
./tests/harness.sh rust python go

# 単一言語を実行 / Run a single language
./tests/harness.sh node
```

### harness.sh のテストグループ / Test Groups Covered by harness.sh

| グループ / Group | 内容 / Description |
|-------|-------------|
| 1 | 初期状態 / Initial state |
| 2 | 書き込み・読み込みラウンドトリップ / Write/read round-trip |
| 3 | Fact レイヤー検証 / Fact layer validation |
| 4 | Interpretation レイヤー検証 / Interpretation layer validation |
| 5 | 型チェック / Type checking |
| 6 | ウィンドウサイズ 1（上書き） / Window size 1 (overwrite) |
| 7 | turn_id 単調増加 / turn_id monotonic increase |
| 8 | クリア / Clear |
| 9 | _schema 自動生成 / _schema auto-generation |
| 10 | タイムスタンプ（ISO 8601） / Timestamp (ISO 8601) |
| 11a-f | パス解決 / Path resolution |
| 12 | 言語間互換性 / Cross-language compatibility |
| 14 | CLI インターフェース / CLI interface |

## Layer 2: MCP プロトコルテスト / MCP Protocol Tests

```bash
# 全言語を実行（Bash は MCP 非対応のため除外）
# Run all languages (Bash excluded — no MCP)
./tests/harness-mcp.sh all

# 特定言語を実行 / Run specific languages
./tests/harness-mcp.sh rust python node
```

## Recurrent Quine テスト / Recurrent Quine Tests

```bash
./tests/harness-quine.sh
```

**注意:** Quine テストは `write` を実行し、`recurrent-quine.lisp` を不可逆的に書き換える。ハーネスは `recurrent-quine-baseline.lisp` を使って自動的にバックアップ・復元を行う。

**Warning:** Quine tests execute `write` which irreversibly rewrites `recurrent-quine.lisp`. The harness automatically backs up and restores the file using `recurrent-quine-baseline.lisp`.

## クリーンアップ / Cleanup

全言語のビルド成果物とキャッシュを削除する。

Remove all build artifacts and caches across every language:

```bash
./tests/clean.sh          # 成果物を削除 / Remove artifacts
./tests/clean.sh --dry    # 削除対象のプレビュー / Preview what would be removed
```

テスト前に `clean.sh` を実行すればソースからのクリーンビルドが保証され、テスト後に実行すればディスク容量を回収できる。推奨ワークフロー:

Running `clean.sh` before tests ensures a fresh build from source; running it after tests reclaims disk space. Recommended workflow:

```bash
./tests/clean.sh            # テスト前: クリーン状態から開始 / Pre-test: start from clean state
./tests/harness.sh all      # Layer 1 実行 / Run Layer 1
./tests/harness-mcp.sh all  # Layer 2 実行 / Run Layer 2
./tests/clean.sh            # テスト後: 約 170 MB を回収 / Post-test: reclaim ~170 MB
```

## ディレクトリ構成 / Directory Structure

```
tests/
├── clean.sh               # リポジトリクリーンアップスクリプト / Repository cleanup script
├── fixtures/              # 共有 JSON テストフィクスチャ（14 ファイル） / Shared JSON test fixtures (14 files)
├── fixtures-quine/        # Recurrent Quine plist フィクスチャ（7 ファイル） / Recurrent Quine plist fixtures (7 files)
├── harness.sh             # Layer 1 CLI ブラックボックステストハーネス / Layer 1 CLI black-box test harness
├── harness-mcp.sh         # MCP プロトコルテストハーネス / MCP protocol test harness
├── harness-quine.sh       # Recurrent Quine テストハーネス / Recurrent Quine test harness
└── README.md              # 本ファイル / This file
```

## 仕様書リファレンス / Specification References

- `docs/designs/SPEC-TEST-v0.9.1.md` — テスト仕様 / Test specification
- `docs/designs/SPEC-path-resolution-v0.9.1.md` — パス解決仕様 / Path resolution specification
- `docs/plans/PLAN-TEST-IMPL-v0.9.1.md` — テスト実装計画 / Test implementation plan
