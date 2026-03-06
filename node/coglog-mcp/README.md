# CogLog MCP Server v0.9.1 (Node.js)

CogLog の MCP サーバー。AI エージェントが MCP 経由でコグログを読み書きできる。

The CogLog MCP server. Allows AI agents to read and write coglogs via MCP.

## インストール / Installation

```bash
npm install -g coglog-mcp
```

## 必要環境 / Requirements

- Node.js 18+

## 設定例 / Configuration Example

```json
{
  "mcpServers": {
    "coglog": {
      "command": "coglog-mcp"
    }
  }
}
```

## MCP プロトコル / MCP Protocol

JSON-RPC 2.0 over stdio (MCP 2024-11-05)。

| ツール / Tool | 説明 / Description |
|--------|------|
| `coglog_read` | 直前ターンのコグログを読み出す / Read the previous turn's coglog |
| `coglog_write` | 現ターンのコグログを書き込む / Write the current turn's coglog |
| `coglog_clear` | コグログをリセットする / Reset the coglog |

## データ形式 / Data Format

```json
{
  "_schema": {
    "version": "0.9.1",
    "fact_layer": {
      "user": "non-empty string required",
      "thinking": "non-empty string required",
      "assistant": "non-empty string required"
    },
    "interpretation_layer": {
      "current_focus": "string required, empty OK",
      "theory_of_mind": "string required, empty OK",
      "self_narrative": "string required, empty OK",
      "annotation": "string required, empty OK"
    },
    "constraints": {
      "window_size": "1 turn (overwritten each write)",
      "interpretation_empty": "choosing not to write is itself a metacognitive act"
    }
  },
  "turn_id": 1,
  "timestamp": "2026-02-26T00:00:00+00:00",
  "layers": { "user": "...", "thinking": "...", "assistant": "..." },
  "current_focus": "...",
  "theory_of_mind": "...",
  "self_narrative": "...",
  "annotation": "..."
}
```

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献 / Design philosophy and references

## ライセンス / License

MIT
