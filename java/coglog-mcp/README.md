# CogLog MCP Server v0.9.1 (Java)

CogLog の MCP サーバー。AI エージェントが MCP 経由でメタログを読み書きできる。

## インストール

```bash
mvn dependency:get -Dartifact=io.github.harmoniaepic:coglog-mcp:0.9.1
```

## 必要環境

- JDK 11+

## 設定例

```json
{
  "mcpServers": {
    "coglog": {
      "command": "java",
      "args": ["-jar", "/path/to/coglog-mcp-0.9.1.jar"]
    }
  }
}
```

## MCP プロトコル

JSON-RPC 2.0 over stdio (MCP 2024-11-05)。

| ツール | 説明 |
|--------|------|
| `coglog_read` | 直前ターンのメタログを読み出す |
| `coglog_write` | 現ターンのメタログを書き込む |
| `coglog_clear` | メタログをリセットする |

## データ形式

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


## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献

## ライセンス

MIT

