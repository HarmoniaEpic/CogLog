# coglog-mcp v0.9.1 (Rust MCP Server)

CogLog の MCP サーバー。read / write / clear を JSON-RPC 2.0 over stdio で公開する。

## インストール

```bash
cargo install coglog-mcp
```

## 使い方

```bash
coglog-mcp
```

### MCP クライアント設定

```json
{
  "mcpServers": {
    "metalog": {
      "command": "coglog-mcp"
    }
  }
}
```

### 提供ツール

| ツール名 | 説明 |
|---|---|
| `metalog_read` | 直前ターンのメタログを読み出す |
| `metalog_write` | 現ターンのメタログを書き込む（前回分を上書き） |
| `metalog_clear` | メタログをリセットする |

### プロトコル

- MCP 2024-11-05
- JSON-RPC 2.0 over stdio
- 改行区切り JSON

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ | `~/.coglog` |

## 特徴

- **型安全**: [coglog-core](https://crates.io/crates/coglog-core) の型定義を CLI と共有
- **小さいバイナリ**: `opt-level="z"`, LTO, `panic="abort"`, strip
- **完全互換**: 他の全言語実装と同じデータ形式

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス

MIT
