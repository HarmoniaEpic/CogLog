# coglog v0.9.1 (Rust CLI)

CogLog の CLI。直前ターンのコグログを read / write / clear する。

The CogLog CLI. Reads, writes, and clears the previous turn's coglog.

## インストール / Installation

```bash
cargo install coglog
```

## 使い方 / Usage

```bash
coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-cli write
coglog-cli clear
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
├── coglog-core/        コアライブラリ（型 + バリデーション） / Core library (types + validation)
├── coglog/             ← このクレート（CLI） / This crate (CLI)
└── coglog-mcp/         MCP サーバー / MCP server
```

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス / License

MIT
