# CogLog QuickJS版 v0.9.1 リネーム計画

## 概要

QuickJS 版 CLI（`metalog-v0_9_1_qjs.js`）および MCP サーバー版（`metalog-mcp-server-v0_9_1_qjs.js`）を MetaLog → CogLog にリネームする。データディレクトリを `~/.coglog/` に汎用化する。README を新規作成する。

---

## 変更の性質

**PATCH VERSION 相当**（リネーム + DATA_DIR 汎用化。データ構造・バリデーション・_schema に変更なし）

バージョンナンバリングは v0.9.1 のまま維持する。

---

## QuickJS 版の位置づけ

QuickJS 版は Node.js 版の **ランタイム非依存バリアント** である。

| 観点 | Node.js 版 | QuickJS 版 |
|------|-----------|-----------|
| ランタイム | Node.js 18+ | QuickJS（`qjs --std`） |
| ネイティブ化 | 不可 | `qjsc` + `cosmocc` でバイナリ生成可 |
| モジュール | ES Modules（`node:fs`, `node:os`） | QuickJS 組み込み（`std`, `os`） |
| I/O | `fs/promises`（async） | `std.loadFile`, `std.open`（sync） |
| 外部依存 | なし | なし |
| データ形式 | 同一（current.json） | 同一（current.json） |

C++ 版がコンパイル言語によるゼロ依存実装であるのに対し、QuickJS 版は **JavaScript のまま** ネイティブバイナリを生成できる点に独自の価値がある。

---

## 対象ファイル

### ソース

| # | 現行ファイル名 | 変更後ファイル名 | 変更種別 |
|---|---------------|----------------|---------|
| 1 | `metalog-v0_9_1_qjs.js` | `coglog-v0_9_1_qjs.js` | リネーム + 改修 |
| 2 | `metalog-mcp-server-v0_9_1_qjs.js` | `coglog-mcp-server-v0_9_1_qjs.js` | リネーム + 改修 |

### ドキュメント

| # | ファイル名 | 変更種別 |
|---|-----------|---------|
| 3 | `README-qjs-v0.9.1.md` | **新規作成** |

---

## ファイル別変更詳細

### 1. `coglog-v0_9_1_qjs.js`（リネーム + 改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| JSDoc コメント | `MetaLog v0.9.1` | `CogLog v0.9.1` |
| CLI 使用例 | `qjs --std metalog-v0_9_1_qjs.js` | `qjs --std coglog-v0_9_1_qjs.js` |
| コンパイル例 | `qjsc -e -o metalog.c metalog-v0_9_1_qjs.js` | `qjsc -e -o coglog.c coglog-v0_9_1_qjs.js` |
| コンパイル例 | `cosmocc ... -o metalog metalog.c` | `cosmocc ... -o coglog coglog.c` |
| DATA_DIR | `"./.metalog"` | `homedir() + "/.coglog"` |
| クラス名 | `class MetaLog` | `class CogLog` |
| CLI 出力 | `metalog: turn N written` | `coglog: turn N written` |
| CLI 出力 | `(no metalog found)` | `(no coglog found)` |
| CLI 出力 | `metalog: cleared` | `coglog: cleared` |
| CLI エラー | `metalog error:` | `coglog error:` |
| CLI ヘルプ | `usage: metalog-v0_9_1_qjs.js` | `usage: coglog-v0_9_1_qjs.js` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

#### DATA_DIR 変更の詳細

```javascript
// 現行
const DATA_DIR = "./.metalog";

// 変更後
function homedir() {
  return std.getenv("HOME") || std.getenv("USERPROFILE") || ".";
}
const DATA_DIR = homedir() + "/.coglog";
```

QuickJS には Node.js の `os.homedir()` に相当する API がない。`std.getenv()` で環境変数を参照する。

| 環境 | `std.getenv("HOME")` | フォールバック | 最終パス |
|------|---------------------|--------------|---------|
| Linux/macOS | `/home/<user>` or `/Users/<user>` | — | `~/.coglog` |
| Windows（WSL経由） | `/home/<user>` | — | `~/.coglog` |
| Windows（ネイティブ QuickJS） | `null` | `std.getenv("USERPROFILE")` → `C:\Users\<user>` | `%USERPROFILE%/.coglog` |
| 環境変数未設定 | `null` | `null` | `./.coglog`（CWD フォールバック） |

CWD フォールバックは現行動作と同一のため、最悪ケースでも後方互換性がある。

### 2. `coglog-mcp-server-v0_9_1_qjs.js`（リネーム + 改修）

MCP サーバー版は関数ベース（`metalogRead()`, `metalogWrite()`, `metalogClear()`）で CLI 版のクラスベースとは設計が異なる。

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| JSDoc コメント | `MetaLog MCP Server v0.9.1 — QuickJS edition` | `CogLog MCP Server v0.9.1 — QuickJS edition` |
| DATA_DIR | `pathJoin(scriptDir(), ".metalog")` | `homedir() + "/.coglog"` |
| 関数名 | `metalogRead`, `metalogWrite`, `metalogClear` | `coglogRead`, `coglogWrite`, `coglogClear` |
| `scriptDir()` | CWD を返す | **削除**（`homedir()` に置換） |
| `pathJoin()` | 汎用パス結合 | 維持（DATA_DIR 算出には不要になるが、CURRENT_FILE 算出に使用） |
| ツール名 | `metalog_read`, `metalog_write`, `metalog_clear` | `coglog_read`, `coglog_write`, `coglog_clear` |
| ツール description | `metalog` → `coglog` | — |
| SERVER_INFO（相当） | `"metalog"` | `"coglog"` |
| ログプレフィックス | `metalog-mcp:` | `coglog-mcp:` |
| ツール結果テキスト | `(no metalog found)` | `(no coglog found)` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

#### SCHEMA 構造の不整合（発見事項）

ソースコードを精査した結果、CLI 版と MCP 版で SCHEMA 定数の構造が異なることを確認した。

```javascript
// CLI 版: SCHEMA は _schema の「中身」（フラット）
const SCHEMA = {
  version: "0.9.1",
  fact_layer: { ... },
  ...
};
// → entry に _schema: SCHEMA として埋め込む

// MCP 版: SCHEMA は _schema を「含む」（ネスト）
const SCHEMA = {
  _schema: {
    version: "0.9.1",
    fact_layer: { ... },
    ...
  },
};
// → Object.assign({}, SCHEMA, { turn_id, ... }) で展開
```

両者は最終的な JSON 出力としては等価（`_schema` キーの下に同一オブジェクトが入る）だが、コードの意味構造が異なる。

**対応方針**: リネーム作業では現行の挙動を維持する（動作に影響しないため）。構造の統一は別 issue として記録する。報告義務に該当：「当初の要求と異なるアプローチ」ではなく「発見した不整合の記録」。

### 3. `README-qjs-v0.9.1.md`（新規作成）

README-mjs-v0.9.1.md を基に、QuickJS 固有の差異を反映して新規作成する。

#### 構成

```
# CogLog v0.9.1（QuickJS）

## 概要
  Node.js 版と機能同等。QuickJS std/os モジュール使用。
  qjsc でネイティブバイナリ生成可能。

## ファイル構成
  ソースとデータの分離構成。

## 必要環境
  QuickJS。外部ライブラリ不要。

## 使い方
  ### CLI
    qjs --std 版の read/write/clear 例
  ### ネイティブバイナリ
    qjsc + cosmocc のビルド例

## データ形式
  _schema 含む JSON（他版と同一）

## フィールド定義
  事実層・解釈層のバリデーションルール

## 他の実装との対応
  py / mjs / qjs / cpp 対応テーブル

## 設計上の要点
  窓サイズ1、_schema 自動付与、四軸解釈層

## 変更履歴
  v0.9.1 に MetaLog → CogLog 改称を追記
```

#### Node.js 版 README との主な差分

| 項目 | Node.js 版 | QuickJS 版 |
|------|-----------|-----------|
| 必要環境 | Node.js 18+ | QuickJS |
| CLI コマンド | `node coglog-v0.9.1.mjs` | `qjs --std coglog-v0_9_1_qjs.js` |
| モジュール使用例 | ES Module import | なし（QuickJS は単体ファイル実行が主） |
| ネイティブバイナリ | なし | `qjsc` + `cosmocc` ビルド手順 |
| セッションまたぎ | あり | あり |
| 他版との対応テーブル | py ↔ mjs | py ↔ mjs ↔ qjs ↔ cpp |

---

## 変更しないもの

- データ構造（_schema, 事実層, 解釈層）
- バリデーションルール
- `read()` / `write()` / `clear()` のロジック
- 窓サイズ1・上書きロジック
- MCP プロトコル（JSON-RPC 2.0, 2024-11-05）
- MCP ケイパビリティ（tools のみ）
- QuickJS 固有の I/O（`std.loadFile`, `std.open`, `std.in.getline` 等）
- バージョンナンバリング（v0.9.1 維持）
- SCHEMA 構造の CLI/MCP 間差異（別 issue）

---

## 作業順序

1. `coglog-v0_9_1_qjs.js` — コア変更。テスト基盤
2. `coglog-mcp-server-v0_9_1_qjs.js` — 関数リネーム + MCP 固有部分のリネーム
3. `README-qjs-v0.9.1.md` — 新規作成

---

## テスト計画

### CLI 版

| # | テスト | 期待結果 |
|---|--------|---------|
| 1 | `qjs --std coglog-v0_9_1_qjs.js read`（空） | `(no coglog found)` |
| 2 | write（四軸全指定） | `coglog: turn 1 written` |
| 3 | read（データあり） | _schema 先頭、四軸正順 |
| 4 | write（current_focus 欠落） | エラー: `missing required field: current_focus` |
| 5 | write（事実層空） | エラー: `missing required field: user` |
| 6 | write（解釈層全空文字列） | `coglog: turn 2 written` |
| 7 | clear → read | `coglog: cleared` → `(no coglog found)` |
| 8 | `_schema.version` | `"0.9.1"` |
| 9 | データパス確認 | `~/.coglog/current.json` に書き込まれる |

### MCP サーバー版

| # | テスト | 期待結果 |
|---|--------|---------|
| 10 | initialize | `serverInfo.name: "coglog"` |
| 11 | tools/list | 3ツール: `coglog_read`, `coglog_write`, `coglog_clear` |
| 12 | coglog_read（空） | `"(no coglog found)"` |
| 13 | coglog_write（正常） | エントリJSON（_schema 付き） |
| 14 | coglog_write（バリデーションエラー） | `isError: true` |
| 15 | coglog_clear | `{ "cleared": true }` |

### クロス互換

| # | テスト | 期待結果 |
|---|--------|---------|
| 16 | qjs CLI write → py CLI read | 正常に読める |
| 17 | qjs CLI write → mjs CLI read | 正常に読める |
| 18 | py CLI write → qjs CLI read | 正常に読める |

三者とも `~/.coglog/current.json` を共有するため、リネーム後もデータ互換性が維持されることを検証する。

### ネイティブバイナリ

| # | テスト | 期待結果 |
|---|--------|---------|
| 19 | qjsc ビルド成功 | コンパイルエラーなし |
| 20 | ネイティブバイナリ read/write/clear | qjs 実行時と同一の動作 |

---

## QuickJS 固有の技術的考慮

### `std.getenv()` のプラットフォーム差異

| プラットフォーム | `HOME` | `USERPROFILE` | 備考 |
|----------------|--------|---------------|------|
| Linux | ✓ | — | 標準 |
| macOS | ✓ | — | 標準 |
| FreeBSD / NetBSD / OpenBSD | ✓ | — | 標準 |
| Windows (MSYS2/Cygwin) | ✓ | ✓ | `HOME` が優先される |
| Windows (ネイティブ) | — | ✓ | QuickJS のネイティブ Windows ビルドは限定的 |

QuickJS 自体のネイティブ Windows 対応は限定的であるため、Windows 環境では WSL 経由での使用が現実的。`USERPROFILE` フォールバックは防御的措置。

### `os.mkdir()` の制限

QuickJS の `os.mkdir()` は再帰的ディレクトリ作成に対応しない（Node.js の `{ recursive: true }` に相当するオプションがない）。ただし `~/.coglog/` は1階層のみの作成であるため、問題にならない。

### ネイティブバイナリ化時の `std.getenv()`

`qjsc` でコンパイルしたバイナリでも `std.getenv()` は正常に動作する。QuickJS の `std` モジュールは C の `getenv()` をラップしており、コンパイル後も libc 経由で環境変数にアクセスする。cosmocc ビルド時も同様。

---

## 備考

### Node.js 版との DATA_DIR 解決方式の比較

| | Python | Node.js | QuickJS | C++ |
|---|---|---|---|---|
| 現行 | `Path(__file__) / ".metalog"` | `join(__dirname, '.metalog')` | `"./.metalog"`（CWD） | `__file__` 起点 |
| 変更後 | `Path.home() / ".coglog"` | `join(homedir(), '.coglog')` | `std.getenv("HOME") + "/.coglog"` | `getenv("HOME") + "/.coglog"` |
| 原理 | stdlib | stdlib | libc ラップ | libc 直接 |

四者とも最終的に libc の `getenv("HOME")` に到達する。Python の `Path.home()` と Node.js の `os.homedir()` はこれのラッパーであり、QuickJS と C++ は直接呼び出す。解決結果は全環境で同一。

### README-mcp-v0.9.1.md への追記

現行の README-mcp-v0.9.1.md は Python 版と Node.js 版のみ記載している。QuickJS 版の MCP サーバーを追記する。

```json
{
  "mcpServers": {
    "coglog": {
      "command": "qjs",
      "args": ["--std", "/path/to/coglog-mcp-server-v0_9_1_qjs.js"]
    }
  }
}
```

あるいはネイティブバイナリ版：

```json
{
  "mcpServers": {
    "coglog": {
      "command": "/path/to/coglog-mcp-server"
    }
  }
}
```

ネイティブバイナリ版はコマンドパスだけで完結し、ランタイムの指定が不要。これは QuickJS → qjsc → cosmocc パスの最大の利点である。
