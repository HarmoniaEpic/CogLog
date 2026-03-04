# MetaLog MCP Server v0.9.1

MetaLog の read / write / clear を MCP ツールとして提供するサーバー。

## 必要環境

Python 3.8+ または Node.js 18+。外部ライブラリ不要。

## セットアップ

### Claude Desktop

`claude_desktop_config.json` に以下を追加する。

**Python版:**
```json
{
  "mcpServers": {
    "metalog": {
      "command": "python3",
      "args": ["/path/to/metalog-mcp-server-v0.9.1.py"]
    }
  }
}
```

**Node.js版:**
```json
{
  "mcpServers": {
    "metalog": {
      "command": "node",
      "args": ["/path/to/metalog-mcp-server-v0.9.1.mjs"]
    }
  }
}
```

### Claude Code

```bash
# Python版
claude mcp add metalog -- python3 /path/to/metalog-mcp-server-v0.9.1.py

# Node.js版
claude mcp add metalog -- node /path/to/metalog-mcp-server-v0.9.1.mjs
```

## ツール

### metalog_read

直前ターンのメタログを返す。データなしの場合は `"(no metalog found)"` を返す。引数なし。

### metalog_write

現ターンのメタログを書き込む（前ターンは上書き）。

| 引数 | 層 | バリデーション |
|------|-----|---------------|
| `user` | 事実層 | 非空文字列必須 |
| `thinking` | 事実層 | 非空文字列必須 |
| `assistant` | 事実層 | 非空文字列必須 |
| `current_focus` | 解釈層 | 文字列必須、空許容 |
| `theory_of_mind` | 解釈層 | 文字列必須、空許容 |
| `self_narrative` | 解釈層 | 文字列必須、空許容 |
| `annotation` | 解釈層 | 文字列必須、空許容 |

全7フィールド必須。解釈層の空文字列は「書かないという判断」として有効。

### metalog_clear

メタログを削除する。引数なし。

## データ互換性

CLI版 (`metalog-v0.9.1.py read`) ・モジュール版・MCP版は同一の `current.json` を読み書きする。MCP版で書いたデータをCLI版で読むことも、その逆も可能。

データは MCPサーバーファイルと同じディレクトリの `.metalog/current.json` に保存される。

## プロトコル

- トランスポート: stdio（改行区切りJSON）
- プロトコルバージョン: 2024-11-05
- ケイパビリティ: tools のみ

## 詳細

設計思想については [DESIGN-v0.9.1.md](./DESIGN-v0.9.1.md) を参照。
CLI版・モジュール版については [README-py-v0.9.1.md](./README-py-v0.9.1.md)、[README-mjs-v0.9.1.md](./README-mjs-v0.9.1.md) を参照。
