# MetaLog MCP Server v0.9.1 実装計画

## 概要

MetaLog v0.9.1 を MCP (Model Context Protocol) サーバーとして提供する。
Python版 (`metalog-mcp-server-v0.9.1.py`) と Node.js版 (`metalog-mcp-server-v0.9.1.mjs`) の2ファイルを構築する。

各ファイルは **MetaLogクラスの完全なコピーを内包する1ファイル完結構成** とする。

---

## 設計判断

### 1ファイル完結の理由

MetaLog本体 (`metalog-v0.9.1.py`, `metalog-v0.9.1.mjs`) とコードが重複するが、以下の理由で許容する：

- **単体運用性**: MCP設定ファイルにファイルパス1つを書くだけで動作する。依存ファイルの配置ミスがない
- **外部ライブラリ非依存の維持**: `import metalog` のためのパッケージングすら不要
- **重複のコスト**: MetaLogクラスは約80行。MCPサーバー層は約120–150行。合計250行前後の小さなファイルであり、重複の管理コストは低い

### プロトコル選択

| 項目 | 選択 | 理由 |
|------|------|------|
| トランスポート | **stdio** | ローカル実行。MCPクライアントがサブプロセスとして起動する標準形態 |
| プロトコルバージョン | **2024-11-05** | 現行の安定版。最も広くサポートされている |
| ケイパビリティ | **tools のみ** | resources, prompts, sampling は不要 |

### 外部ライブラリ

**一切使用しない。** 標準ライブラリのみ。

Python: `json`, `sys`, `os`, `datetime`, `pathlib`
Node.js: `node:readline`, `node:fs/promises`, `node:fs`, `node:path`, `node:url`

---

## ファイル構成

```
metalog-mcp-server-v0.9.1.py    # Python版 MCPサーバー（MetaLogクラス内包）
metalog-mcp-server-v0.9.1.mjs   # Node.js版 MCPサーバー（MetaLogクラス内包）
README-mcp-v0.9.1.md            # 使用説明書
```

既存ファイルへの変更はない。

---

## MCPプロトコル層の設計

### メッセージフロー

```
Client                          Server
  │                                │
  │─── initialize ────────────────→│  ハンドシェイク開始
  │←── initialize result ─────────│  capabilities: { tools: {} }
  │─── notifications/initialized ─→│  ハンドシェイク完了（通知、応答不要）
  │                                │
  │─── tools/list ────────────────→│  ツール一覧要求
  │←── tools/list result ─────────│  3ツールの定義を返す
  │                                │
  │─── tools/call ────────────────→│  ツール実行要求
  │←── tools/call result ─────────│  実行結果を返す
  │                                │
  │─── ping ──────────────────────→│  ヘルスチェック（任意）
  │←── pong ──────────────────────│
  │                                │
  │    (stdin閉鎖 or SIGTERM)      │  終了
```

### stdioの制約

MCPのstdioトランスポートでは、JSON-RPCメッセージは **改行区切りで1行1メッセージ** としてstdin/stdoutを流れる。

**絶対規則: stdoutにはJSON-RPCメッセージ以外を出力してはならない。**

MetaLogクラスのCLI部分（`print()`, `console.log()`）はMCPサーバーモードでは一切呼ばれないため問題ない。MCPサーバー層が `send_response()` / `sendResponse()` のみを通じてstdoutに書き込む。

ログ出力が必要な場合は **stderr** に書く。

### メソッドルーティング

| method | 種別 | 処理 |
|--------|------|------|
| `initialize` | request | ハンドシェイク。capabilities返却 |
| `notifications/initialized` | notification | 何もしない（応答不要） |
| `tools/list` | request | ツール定義3件を返却 |
| `tools/call` | request | name でルーティングし実行 |
| `ping` | request | 空の result を返却 |
| その他 | request | JSON-RPC error `-32601 Method not found` |
| その他 | notification | 無視（仕様準拠） |

### request と notification の判別

```
"id" フィールドが存在する → request（応答必須）
"id" フィールドが存在しない → notification（応答禁止）
```

---

## ツール定義

### metalog_read

```json
{
  "name": "metalog_read",
  "description": "Read the previous turn's metalog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no metalog exists.",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "additionalProperties": false
  }
}
```

**実行**: `ml.read()` → 結果をJSON文字列化して `text` コンテントとして返却。
`None`/`null` の場合は `"(no metalog found)"` を返す。

### metalog_write

```json
{
  "name": "metalog_write",
  "description": "Write the current turn's metalog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings — choosing not to write is itself a metacognitive act.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "user":            { "type": "string", "description": "User's original utterance (non-empty)" },
      "thinking":        { "type": "string", "description": "AI's full thinking process (non-empty)" },
      "assistant":       { "type": "string", "description": "AI's original output (non-empty)" },
      "current_focus":   { "type": "string", "description": "Present direction: what am I working on?" },
      "theory_of_mind":  { "type": "string", "description": "Other direction: what is the user's state?" },
      "self_narrative":   { "type": "string", "description": "Self direction: who am I in this moment?" },
      "annotation":      { "type": "string", "description": "Future direction: what should I do next?" }
    },
    "required": ["user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"],
    "additionalProperties": false
  }
}
```

**実行**: `ml.write(...)` → 書き込まれたエントリをJSON文字列化して `text` コンテントとして返却。
`ValueError` の場合は `isError: true` のツール結果として返却（JSON-RPCエラーではない）。

### metalog_clear

```json
{
  "name": "metalog_clear",
  "description": "Clear the metalog, removing the stored turn data. Returns whether the clear was successful.",
  "inputSchema": {
    "type": "object",
    "properties": {},
    "additionalProperties": false
  }
}
```

**実行**: `ml.clear()` → 結果をJSON文字列化して `text` コンテントとして返却。

---

## JSON-RPCエンベロープ

### レスポンス（成功）

```json
{"jsonrpc":"2.0","id":1,"result":{...}}
```

### レスポンス（エラー）

```json
{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}
```

### ツール実行エラー（ビジネスロジックエラー）

MCP仕様に従い、ツール実行時のバリデーションエラー等は **JSON-RPCエラーではなく、ツール結果の `isError: true`** として返す。これによりLLMがエラーを認識し自己修正できる。

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": {
    "content": [{ "type": "text", "text": "Error: missing required field: user" }],
    "isError": true
  }
}
```

### 標準JSON-RPCエラーコード

| コード | 意味 | 使用場面 |
|--------|------|---------|
| -32700 | Parse error | stdinから受信したJSONが不正 |
| -32600 | Invalid Request | JSON-RPC構造が不正（jsonrpc, method欠落等） |
| -32601 | Method not found | 未知のmethod（requestの場合のみ） |
| -32602 | Invalid params | パラメータ構造が不正 |
| -32603 | Internal error | 予期しないサーバー内部エラー |

---

## データディレクトリ

MCP環境ではサーバーの起動元ディレクトリが不定のため、DATA_DIRのデフォルトを明示的に設定する。

| 言語 | DATA_DIR デフォルト |
|------|-------------------|
| Python | `Path(__file__).resolve().parent / ".metalog"` |
| Node.js | `join(__dirname, '.metalog')` |

MCPサーバーファイルの置き場所に `.metalog/` ディレクトリが作られる。
これは既存のCLI版と同一の挙動である。

---

## Python版の構造

```python
#!/usr/bin/env python3
"""MetaLog MCP Server v0.9.1"""

import json, sys, os
from datetime import datetime, timezone
from pathlib import Path

# ── 定数 ──
DATA_DIR = ...
CURRENT_FILE = ...
SCHEMA = { ... }               # v0.9.1 _schema（既存と同一）
TOOLS = [ ... ]                 # 3ツールの定義

# ── MetaLogクラス ──           # metalog-v0.9.1.py から複製（約80行）
class MetaLog:
    ...

# ── JSON-RPC層 ──
def send_response(id, result):  # stdout に1行JSON出力
def send_error(id, code, msg):  # stdout にJSON-RPCエラー出力
def log(msg):                   # stderr にログ出力

# ── MCPハンドラ ──
def handle_initialize(id, params):
def handle_tools_list(id):
def handle_tools_call(id, params):
def handle_ping(id):

# ── メインループ ──
def main():
    ml = MetaLog()
    for line in sys.stdin:       # 1行1メッセージ
        msg = json.loads(line)
        # notification判別（id無し → 応答不要）
        # method でルーティング
```

**Pythonのstdin読み取り**: `sys.stdin` は行イテレータとして使用可能。`for line in sys.stdin:` で改行区切りの逐次処理ができる。asyncは不要。

### Python版の注意点

- `print()` は一切使わない。`sys.stdout.write()` + `sys.stdout.flush()` で制御する
- `sys.stderr.write()` でログ出力

---

## Node.js版の構造

```javascript
#!/usr/bin/env node
/**
 * MetaLog MCP Server v0.9.1
 */

import { createInterface } from 'node:readline';
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// ── 定数 ──
const __dirname = ...;
const DATA_DIR = ...;
const CURRENT_FILE = ...;
const SCHEMA = { ... };         // v0.9.1 _schema（既存と同一）
const TOOLS = [ ... ];          // 3ツールの定義

// ── MetaLogクラス ──           // metalog-v0.9.1.mjs から複製（約75行）
class MetaLog { ... }

// ── JSON-RPC層 ──
function sendResponse(id, result) { ... }  // stdout に1行JSON出力
function sendError(id, code, message) { ... }
function log(msg) { ... }                  // stderr にログ出力

// ── MCPハンドラ ──
async function handleInitialize(id, params) { ... }
async function handleToolsList(id) { ... }
async function handleToolsCall(id, params, ml) { ... }
async function handlePing(id) { ... }

// ── メインループ ──
const ml = new MetaLog();
const rl = createInterface({ input: process.stdin });
rl.on('line', async (line) => {
    // JSON解析 → method でルーティング
});
```

**Node.jsのstdin読み取り**: `node:readline` の `createInterface` で行単位イベントを受け取る。外部ライブラリ不要。

### Node.js版の注意点

- `console.log()` は stdout に出力されるため一切使わない
- `process.stdout.write(json + '\n')` で制御する
- `console.error()` は stderr なのでログ用途に使用可能

---

## テスト計画

MCPサーバーのテストは、stdinにJSON-RPCメッセージを流し込み、stdoutの出力を検証する方式で行う。

### テストケース

| # | テスト | 入力 | 期待出力 |
|---|--------|------|---------|
| 1 | ハンドシェイク | `initialize` request | `protocolVersion: "2024-11-05"`, `capabilities: { tools: {} }` |
| 2 | initialized通知 | `notifications/initialized` | 出力なし（notification） |
| 3 | ツール一覧 | `tools/list` request | 3ツール定義（metalog_read, metalog_write, metalog_clear） |
| 4 | read（空） | `tools/call` metalog_read | `"(no metalog found)"` |
| 5 | write（正常） | `tools/call` metalog_write (全フィールド) | エントリJSON（_schema付き, turn_id: 1） |
| 6 | read（データあり） | `tools/call` metalog_read | 書き込んだエントリが返る |
| 7 | write（バリデーションエラー） | `tools/call` metalog_write (user欠落) | `isError: true`, エラーメッセージ |
| 8 | clear | `tools/call` metalog_clear | `{ "cleared": true }` |
| 9 | read（clear後） | `tools/call` metalog_read | `"(no metalog found)"` |
| 10 | ping | `ping` request | 空の result `{}` |
| 11 | 未知メソッド | `unknown/method` request | JSON-RPC error `-32601` |
| 12 | 不正JSON | `{broken json` | JSON-RPC error `-32700`（可能な場合） |
| 13 | Python⇔Node.js互換 | py版writeしたデータをmjs版readで読む | 正常に読める |

### テスト実行方法

```bash
# ハンドシェイク → tools/list → tools/call の一連をパイプで流す
printf '%s\n%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
| python3 metalog-mcp-server-v0.9.1.py
```

stdoutの各行をJSONパースし、idとresultの構造を検証する。

---

## MCPクライアント設定例

### Claude Desktop (`claude_desktop_config.json`)

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
claude mcp add metalog -- python3 /path/to/metalog-mcp-server-v0.9.1.py
```

---

## 規模見積もり

| セクション | Python | Node.js |
|-----------|--------|---------|
| MetaLogクラス（複製） | ~80行 | ~75行 |
| 定数（SCHEMA, TOOLS） | ~50行 | ~50行 |
| JSON-RPC層 | ~30行 | ~30行 |
| MCPハンドラ | ~50行 | ~50行 |
| メインループ | ~30行 | ~25行 |
| ドキュメントコメント | ~15行 | ~15行 |
| **合計** | **~255行** | **~245行** |

---

## README-mcp-v0.9.1.md

MCPサーバー版の使用説明書。簡潔に、必要十分な情報のみ記載する。

### 構成

```
# MetaLog MCP Server v0.9.1

## 概要
  1文。MCPサーバーとしてMetaLogのread/write/clearを提供する。

## 必要環境
  Python 3.8+ または Node.js 18+。外部ライブラリ不要。

## セットアップ
  ### Claude Desktop
    claude_desktop_config.json の記述例（Python版・Node.js版）
  ### Claude Code
    `claude mcp add` コマンド例

## ツール
  3ツールの名前・概要・引数を簡潔に記述。
  各フィールドのバリデーション規則（事実層: 非空必須、解釈層: 空許容）。

## データ互換性
  CLI版・モジュール版と同一の current.json を共有する旨。

## 詳細
  DESIGN-v0.9.1.md, README-py-v0.9.1.md, README-mjs-v0.9.1.md への参照。
```

### 方針

- MCPクライアント設定のコピペで動くことを最優先に書く
- MetaLogの設計思想・アフォーダンス論等はここでは繰り返さない（DESIGN参照）
- ツール定義の `inputSchema` の全文は載せない（冗長。サーバーが `tools/list` で返す）
- 日英併記はしない。日本語のみ

---

## 変更なし

- `metalog-v0.9.1.py` — 変更なし
- `metalog-v0.9.1.mjs` — 変更なし
- `DESIGN-v0.9.1.md` — 変更なし
- `README-mjs-v0.9.1.md` — 変更なし
- `README-py-v0.9.1.md` — 変更なし
- スキルパッケージ (`metalog.zip`) — 変更なし

MCP版は既存のCLI版・モジュール版と**並立する追加のインターフェース**である。

---

## バージョニング

MetaLogのバージョンは **v0.9.1 のまま**。

MCPサーバーは新しいインターフェースの追加であり、データ構造・バリデーション・_schemaに変更はない。同一の `current.json` を CLI版・モジュール版・MCP版で共有可能。
