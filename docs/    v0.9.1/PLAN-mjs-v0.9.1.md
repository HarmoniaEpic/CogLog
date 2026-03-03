# CogLog Node.js版 v0.9.1 リネーム計画

## 概要

スタンドアロン Node.js 版（`metalog-v0.9.1.mjs`）および MCP サーバー版（`metalog-mcp-server-v0.9.1.mjs`）を MetaLog → CogLog にリネームする。データディレクトリを `~/.coglog/` に汎用化する。

---

## 変更の性質

**PATCH VERSION 相当**（リネーム + DATA_DIR 汎用化。データ構造・バリデーション・_schema に変更なし）

バージョンナンバリングは v0.9.1 のまま維持する。

---

## 対象ファイル

### ソース

| # | 現行ファイル名 | 変更後ファイル名 | 変更種別 |
|---|---------------|----------------|---------|
| 1 | `metalog-v0.9.1.mjs` | `coglog-v0.9.1.mjs` | リネーム + 改修 |
| 2 | `metalog-mcp-server-v0.9.1.mjs` | `coglog-mcp-server-v0.9.1.mjs` | リネーム + 改修 |

### ドキュメント

| # | 現行ファイル名 | 変更後ファイル名 | 変更種別 |
|---|---------------|----------------|---------|
| 3 | `README-mjs-v0.9.1.md` | `README-mjs-v0.9.1.md` | 改修（ファイル名は維持） |
| 4 | `README-mcp-v0.9.1.md` | `README-mcp-v0.9.1.md` | 改修（ファイル名は維持） |

DESIGN-v0.9.1.md はスキル版作業で CogLog 化済み。スタンドアロン版はスキル版 DESIGN.md と同一内容を共有する。

---

## ファイル別変更詳細

### 1. `coglog-v0.9.1.mjs`（リネーム + 改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| JSDoc コメント | `MetaLog v0.9.1` | `CogLog v0.9.1` |
| CLI 使用例 | `node metalog-v0.9.1.mjs` | `node coglog-v0.9.1.mjs` |
| モジュール使用例 | `import { MetaLog } from './metalog-v0.9.1.mjs'` | `import { CogLog } from './coglog-v0.9.1.mjs'` |
| DATA_DIR | `join(__dirname, '.metalog')` | `join(homedir(), '.coglog')` |
| import | なし | `import { homedir } from 'node:os'` を追加 |
| クラス名 | `class MetaLog` | `class CogLog` |
| export | `export { MetaLog }` | `export { CogLog }` |
| CLI 出力 | `metalog: turn N written` | `coglog: turn N written` |
| CLI 出力 | `(no metalog found)` | `(no coglog found)` |
| CLI 出力 | `metalog: cleared` | `coglog: cleared` |
| CLI エラー | `metalog error:` | `coglog error:` |
| CLI ヘルプ | `usage: metalog-v0.9.1.mjs` | `usage: coglog-v0.9.1.mjs` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

#### DATA_DIR 変更の詳細

```javascript
// 現行
const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, '.metalog');

// 変更後
import { homedir } from 'node:os';
const DATA_DIR = join(homedir(), '.coglog');
```

`homedir()` は `os.homedir()` と同一。環境変数 `HOME`（Unix）/ `USERPROFILE`（Windows）を参照する。

`__dirname` は DATA_DIR 算出に不要となるが、MCP サーバー版でのクラス複製元としての整合性のために残すかどうかは実装時に判断する。CLI ヘルプの usage 行にファイル名を表示する用途があれば残す。

### 2. `coglog-mcp-server-v0.9.1.mjs`（リネーム + 改修）

MCP サーバーは CLI 版のクラスを複製（コピー）して内蔵する設計。変更箇所は CLI 版と対称的。

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| JSDoc コメント | `MetaLog MCP Server v0.9.1` | `CogLog MCP Server v0.9.1` |
| コメント | `MetaLog class (copied from metalog-v0.9.1.mjs)` | `CogLog class (copied from coglog-v0.9.1.mjs)` |
| DATA_DIR | `join(__dirname, '.metalog')` | `join(homedir(), '.coglog')` |
| import | なし | `import { homedir } from 'node:os'` を追加 |
| クラス名 | `class MetaLog` | `class CogLog` |
| インスタンス生成 | `const ml = new MetaLog()` | `const cl = new CogLog()` |
| 変数名 | `ml` → `cl`（全箇所） | — |
| SERVER_INFO | `{ name: "metalog", version: "0.9.1" }` | `{ name: "coglog", version: "0.9.1" }` |
| ツール名 | `metalog_read`, `metalog_write`, `metalog_clear` | `coglog_read`, `coglog_write`, `coglog_clear` |
| ツール description | `metalog` → `coglog` | — |
| ログプレフィックス | `metalog-mcp:` | `coglog-mcp:` |
| ツール結果テキスト | `(no metalog found)` | `(no coglog found)` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

### 3. `README-mjs-v0.9.1.md`（改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| タイトル | `MetaLog v0.9.1（Node.js）` | `CogLog v0.9.1（Node.js）` |
| 冒頭説明 | `MetaLog` | `CogLog` |
| ファイル構成 | 単一ツリー（ソース + データ同居） | **ソースとデータを分離した二段構成** |
| ファイル構成 | `metalog/`, `.metalog/`, `metalog-v0.9.1.mjs` | `coglog/`, `~/.coglog/`, `coglog-v0.9.1.mjs` |
| CLI 例 | `node metalog-v0.9.1.mjs` | `node coglog-v0.9.1.mjs` |
| モジュール例 | `import { MetaLog } from './metalog-v0.9.1.mjs'` | `import { CogLog } from './coglog-v0.9.1.mjs'` |
| モジュール例 | `const ml = new MetaLog()` | `const cl = new CogLog()` |
| データ位置 | `.metalog/current.json` | `~/.coglog/current.json` |
| セッションまたぎ例 | `metalog-v0.9.1.mjs` | `coglog-v0.9.1.mjs` |
| セッションまたぎ例 | `metalog_export.json` | `coglog_export.json` |
| Node.js版との対応テーブル | `metalog-v0.9.1.mjs` / `metalog-v0.9.1.py` | `coglog-v0.9.1.mjs` / `coglog-v0.9.1.py` |
| 変更履歴 | v0.9.1 行の末尾に「MetaLog → CogLog 改称」追記 | — |

#### ファイル構成の変更

```
# 現行
metalog/
├── DESIGN-v0.9.1.md
├── README-mjs-v0.9.1.md
├── metalog-v0.9.1.mjs
└── .metalog/
    └── current.json

# 変更後
ソースコード（配置場所は環境による）
~/coglog/
├── DESIGN-v0.9.1.md
├── README-mjs-v0.9.1.md
└── coglog-v0.9.1.mjs

データ（自動生成。環境を問わず ~/.coglog/）
~/.coglog/
└── current.json
```

### 4. `README-mcp-v0.9.1.md`（改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| タイトル | `MetaLog MCP Server v0.9.1` | `CogLog MCP Server v0.9.1` |
| 冒頭説明 | `MetaLog` | `CogLog` |
| セットアップ例 | `"metalog"`, `metalog-mcp-server-v0.9.1.mjs` | `"coglog"`, `coglog-mcp-server-v0.9.1.mjs` |
| Claude Code 例 | `claude mcp add metalog` | `claude mcp add coglog` |
| ツール名 | `metalog_read`, `metalog_write`, `metalog_clear` | `coglog_read`, `coglog_write`, `coglog_clear` |
| ツール説明 | `メタログ` | `コグログ` |
| データ互換性 | `metalog-v0.9.1.py` | `coglog-v0.9.1.py` |
| データ位置 | `.metalog/current.json` | `~/.coglog/current.json` |
| 参照リンク | `README-py-v0.9.1.md`, `README-mjs-v0.9.1.md` | 同（ファイル名は維持） |

---

## 変更しないもの

- データ構造（_schema, 事実層, 解釈層）
- バリデーションルール
- `read()` / `write()` / `clear()` のロジック
- 窓サイズ1・上書きロジック
- MCP プロトコル（JSON-RPC 2.0, 2024-11-05）
- MCP ケイパビリティ（tools のみ）
- バージョンナンバリング（v0.9.1 維持）

---

## 作業順序

1. `coglog-v0.9.1.mjs` — コア変更。テスト基盤
2. `coglog-mcp-server-v0.9.1.mjs` — クラス複製部分を 1 から反映 + MCP 固有部分のリネーム
3. `README-mjs-v0.9.1.md`
4. `README-mcp-v0.9.1.md`

---

## テスト計画

### CLI 版

| # | テスト | 期待結果 |
|---|--------|---------|
| 1 | `node coglog-v0.9.1.mjs read`（空） | `(no coglog found)` |
| 2 | write（四軸全指定） | `coglog: turn 1 written` |
| 3 | read（データあり） | _schema 先頭、四軸正順 |
| 4 | write（current_focus 欠落） | `coglog error: missing required field: current_focus` |
| 5 | write（事実層空） | `coglog error: missing required field: user` |
| 6 | write（解釈層全空文字列） | `coglog: turn 2 written` |
| 7 | clear → read | `coglog: cleared` → `(no coglog found)` |
| 8 | `_schema.version` | `"0.9.1"` |
| 9 | データパス確認 | `~/.coglog/current.json` に書き込まれる |
| 10 | mjs版 write → py版 read | 正常に読める（互換性） |

### MCP サーバー版

| # | テスト | 期待結果 |
|---|--------|---------|
| 11 | initialize | `serverInfo.name: "coglog"` |
| 12 | tools/list | 3ツール: `coglog_read`, `coglog_write`, `coglog_clear` |
| 13 | coglog_read（空） | `"(no coglog found)"` |
| 14 | coglog_write（正常） | エントリJSON（_schema 付き） |
| 15 | coglog_write（バリデーションエラー） | `isError: true` |
| 16 | coglog_clear | `{ "cleared": true }` |
| 17 | CLI 版とデータ共有 | MCP write → CLI read で同一データ |

---

## 備考

Node.js 版の `homedir()` は `os.homedir()` と等価。Unix では `$HOME`、Windows では `%USERPROFILE%` を返す。未設定時は OS ユーザーデータベースにフォールバックする。Python 版の `Path.home()` と同一のディレクトリに解決されるため、mjs 版と py 版のデータ互換性は維持される。
