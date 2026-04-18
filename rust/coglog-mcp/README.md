# coglog-mcp v0.9.1 (Rust MCP Server)

CogLog の MCP サーバー。read / write / clear を JSON-RPC 2.0 over stdio で公開する。

The CogLog MCP server. Exposes read / write / clear via JSON-RPC 2.0 over stdio.

## インストール / Installation

```bash
cargo install coglog-mcp
```

## 使い方 / Usage

```bash
coglog-mcp
```

### MCP クライアント設定 / MCP Client Configuration

```json
{
  "mcpServers": {
    "coglog": {
      "command": "coglog-mcp"
    }
  }
}
```

### 提供ツール / Provided Tools

| ツール名 / Tool name | 説明 / Description |
|---|---|
| `coglog_read` | 直前ターンのコグログを読み出す / Read the previous turn's coglog |
| `coglog_write` | 現ターンのコグログを書き込む（前回分を上書き） / Write the current turn's coglog (overwrites previous) |
| `coglog_clear` | コグログをリセットする / Reset the coglog |

### プロトコル / Protocol

- MCP 2024-11-05
- JSON-RPC 2.0 over stdio
- 改行区切り JSON / Newline-delimited JSON

## 環境変数 / Environment Variables

| 変数 / Variable | 説明 / Description | デフォルト / Default |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ / Data directory | `~/.coglog` |

## 特徴 / Features

- **型安全 / Type-safe**: [coglog-core](https://crates.io/crates/coglog-core) の型定義を CLI と共有 / Shares type definitions from coglog-core with the CLI
- **小さいバイナリ / Small binary**: `opt-level="z"`, LTO, `panic="abort"`, strip
- **完全互換 / Fully compatible**: 他の全言語実装と同じデータ形式 / Same data format as all other language implementations

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス / License

MIT
