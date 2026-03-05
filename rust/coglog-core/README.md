# coglog v0.9.1 (Rust CLI)

CogLog の CLI。直前ターンのメタログを read / write / clear する。

## インストール

```bash
cargo install coglog
```

## 使い方

```bash
coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-cli write
coglog-cli clear
```

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ | `~/.coglog` |

`--coglog-dir <path>` 引数でも指定可能（環境変数より優先）。

## 特徴

- **型安全**: [coglog-core](https://crates.io/crates/coglog-core) の型定義を MCP サーバーと共有
- **小さいバイナリ**: `opt-level="z"`, LTO, `panic="abort"`, strip
- **完全互換**: 他の全言語実装と同じ JSON 形式を入出力

## workspace 構成

```
rust/
├── Cargo.toml          [workspace]
├── coglog-core/        コアライブラリ（型 + バリデーション）
├── coglog/             ← このクレート（CLI）
└── coglog-mcp/         MCP サーバー
```

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス

MIT
