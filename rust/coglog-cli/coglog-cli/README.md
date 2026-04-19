# coglog-cli v0.9.1 (Rust CLI)

CogLog の CLI。直前ターンのコグログを read / write / clear する。

The CogLog CLI. Reads, writes, and clears the previous turn's coglog.

## このクレートについて / About This Crate

`coglog-cli` は crates.io の [`coglog`](https://crates.io/crates/coglog) と同一の CLI 機能を、npm / Go / PyPI と揃えた名前で提供するクレートです。

`coglog-cli` provides the same CLI functionality as [`coglog`](https://crates.io/crates/coglog) on crates.io, under a name aligned with npm / Go / PyPI.

> **バイナリ名について / On the binary name**: v0.9.1 時点では、workspace 内の既存 `coglog` クレート（bin: `coglog-cli`）との衝突を避けるため、`coglog-cli` クレートのバイナリは `coglog-command` という暫定名を使用しています。v0.9.2 で既存 `coglog` クレートが viewer に転生する際、このクレートのバイナリ名は `coglog-cli` に統一される予定です。
>
> In v0.9.1, to avoid conflicts with the existing `coglog` crate (bin: `coglog-cli`) within the workspace, this `coglog-cli` crate uses `coglog-command` as its provisional binary name. This will be unified to `coglog-cli` in v0.9.2 when the existing `coglog` crate transitions to a viewer.

## インストール / Installation

```bash
cargo install coglog-cli
```

## 使い方 / Usage

```bash
coglog-command read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-command write
coglog-command clear
```

## 環境変数 / Environment Variables

| 変数 / Variable | 説明 / Description | デフォルト / Default |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ / Data directory | `~/.coglog` |

`--coglog-dir <path>` 引数でも指定可能（環境変数より優先）。

Can also be specified via the `--coglog-dir <path>` argument (takes precedence over the environment variable).

## 特徴 / Features

- **型安全 / Type-safe**: [coglog-core](https://crates.io/crates/coglog-core) の型定義を MCP サーバーと共有 / Shares type definitions from coglog-core with the MCP server
- **小さいバイナリ / Small binary**: `opt-level="z"`, LTO, `panic="abort"`, strip
- **完全互換 / Fully compatible**: 他の全言語実装と同じ JSON 形式を入出力 / Reads and writes the same JSON format as all other language implementations

## workspace 構成 / Workspace Structure

```
rust/
├── Cargo.toml          [workspace]
├── coglog-core/        コアライブラリ（型 + バリデーション + テスト） / Core library (types + validation + tests)
├── coglog/             既存 CLI クレート（v0.9.2 で viewer に転生予定） / Existing CLI crate (to become viewer in v0.9.2)
├── coglog-cli/         ← このクレート（v0.9.2 で bin 名を coglog-cli に統一予定） / This crate (bin will unify to coglog-cli in v0.9.2)
└── coglog-mcp/         MCP サーバー / MCP server
```

## データ互換性 / Data Compatibility

`coglog` と `coglog-cli` は同じ `$HOME/.coglog/` （または `$COGLOG_DIR`）を参照し、完全にデータ互換です。片方で書いて他方で読むことができます。

`coglog` and `coglog-cli` share the same `$HOME/.coglog/` (or `$COGLOG_DIR`) and are fully data-compatible. You can write with one and read with the other.

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス / License

MIT
