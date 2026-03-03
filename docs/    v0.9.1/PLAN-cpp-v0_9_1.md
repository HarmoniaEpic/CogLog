# CogLog v0.9.1 C++ 実装計画

## 変更の性質

**新規インターフェースの追加**（既存の Python / Node.js 実装への変更なし）

---

## 動機

MetaLog（CogLog）のコア操作は JSON の read / write / clear の三つだけである。この極度のミニマリズムは、C++ でもシングルファイル・ゼロ依存で実装可能な規模に収まることを意味する。

Cosmopolitan Libc（cosmocc）でビルドすることで、Linux・macOS・Windows・FreeBSD・OpenBSD・NetBSD 上で動作するユニバーサルバイナリを単一ファイルとして生成できる。ランタイム不要、インストール不要、`curl` で取得して即実行。

Python 34MB（cosmofy）/ JavaScript ~1MB（QuickJS+cosmocc）に対し、C++ 版は数十KB〜の極小バイナリとなる。設計のミニマリズムが物理的な軽さとして目に見える形になる。

---

## 設計判断

### シングルファイル完結

Python 版・Node.js 版と同じ方針。CLI版とMCPサーバー版はそれぞれ独立したシングルファイルとする。

```
coglog-v0.9.1.cpp              CLI版（JSON ライブラリ + MetaLog コア + CLI）
coglog-mcp-server-v0.9.1.cpp   MCP版（JSON ライブラリ + MetaLog コア + MCP層）
README-cpp-v0.9.1.md           使用説明書
```

JSON ライブラリと MetaLog コアは両ファイルに複製する。ヘッダー分離や `#include` での共有は行わない。理由：

- **単体ビルド性**: `cosmocc -o coglog coglog-v0.9.1.cpp` の一行で完結する
- **重複のコスト**: JSON ライブラリ約300行 + MetaLog コア約150行。管理コストは低い
- **他言語版との一貫性**: Python 版の MCP サーバーも MetaLog クラスを丸ごと複製している

### JSON処理: 自作ミニライブラリ

C++ 標準ライブラリに JSON パーサー/シリアライザーはない。選択肢の検討：

| 方針 | サイズ | 依存 | 評価 |
|---|---|---|---|
| A. MetaLog 専用パーサー | 最小 | ゼロ | `_schema` のネストで専用特化が却って複雑化。却下 |
| B. nlohmann/json | +数百KB | ヘッダー同梱 | 業界標準だが「極小バイナリ」の趣旨と不整合。却下 |
| **C. 汎用ミニパーサー自作** | **小** | **ゼロ** | **ネスト対応の再帰下降パーサー。約300行。採用** |

ミニ JSON ライブラリの要件：

- **パース**: 再帰下降。JSON 全型（null, bool, number, string, array, object）対応
- **シリアライズ**: インデント付き（`dump(2)` で pretty-print）とコンパクト（`dump()` で1行）
- **文字列エスケープ**: JSON仕様準拠（`\"`, `\\`, `\n` 等 + `\uXXXX`）
- **UTF-8**: パススルー。マルチバイト文字はバイト列のまま保存・復元
- **`\uXXXX` デコード**: BMP範囲の Unicode エスケープを UTF-8 にデコード

### 外部ライブラリ

**一切使用しない。** C++17 標準ライブラリ + POSIX API のみ。

使用するヘッダー:
```
<cstdio>  <cstdlib>  <cstring>  <ctime>  <cmath>
<string>  <vector>  <utility>  <stdexcept>
<sys/stat.h>  <unistd.h>
```

### パス解決

実行ファイルと同じディレクトリに `.metalog/` を作成する。Python 版の `Path(__file__).resolve().parent` に相当する処理：

1. `/proc/self/exe` の readlink（Linux）
2. `realpath(argv[0])` にフォールバック（macOS, BSD, Windows/Cosmopolitan）
3. いずれも失敗した場合 `.`（カレントディレクトリ）

### タイムスタンプ

`gmtime_r` (POSIX) / `gmtime_s` (Windows) で UTC 時刻を取得し、ISO 8601 形式で出力する。Python 版の `datetime.now(timezone.utc).isoformat()` に対応。

---

## 内部構成

### json::Value クラス

```
json::Value
├── 型: Null, Bool, Number, String, Array, Object
├── 生成: コンストラクタ / Value::object() / Value::array()
├── アクセス: get(key), get_str(key), has(key), to_int(), to_bool()
├── 変更: set(key, val), push(val)
├── シリアライズ: dump(indent), escape(str)
└── パース: Value::parse(str) → 再帰下降パーサー
    └── Parser 構造体: skip_ws, peek, next, expect
        ├── parse_value → parse_object / parse_array / parse_number
        ├── parse_string_value（エスケープ処理 + \uXXXX デコード）
        └── match（リテラル: true / false / null）
```

Object は `vector<pair<string, Value>>` で順序保持。`_schema` が先頭に来ることを保証する。

### metalog:: 名前空間

```
metalog::
├── SCHEMA            _schema の定数（make_schema() で構築）
├── init_paths()      実行ファイルパスから data_dir, current_file を設定
├── read()            current.json → Json | null
├── write(WriteArgs)  バリデーション → turn_id 採番 → _schema 付与 → 書き込み
└── clear()           ファイル削除 → { cleared: true/false }
```

### CLI (coglog-v0.9.1.cpp)

```
main(argc, argv)
├── init_paths(argv[0])
├── "read"  → metalog::read() → dump(2) → stdout
├── "write" → stdin → json::Value::parse → metalog::write → stdout
├── "clear" → metalog::clear() → stdout
└── else    → usage → stdout
```

### MCP サーバー (coglog-mcp-server-v0.9.1.cpp)

```
main(argc, argv)
├── init_paths(argv[0])
└── mcp::run()
    ├── TOOLS 定数（3ツール定義、inputSchema 付き）
    ├── stdin 行ループ
    │   ├── JSON パース → method / id 抽出
    │   ├── notification（id なし）→ 無視（initialized のみログ）
    │   └── request（id あり）→ method ルーティング
    │       ├── "initialize"  → protocolVersion + capabilities + serverInfo
    │       ├── "tools/list"  → TOOLS
    │       ├── "tools/call"  → name でディスパッチ
    │       │   ├── metalog_read  → metalog::read()
    │       │   ├── metalog_write → metalog::write()
    │       │   └── metalog_clear → metalog::clear()
    │       ├── "ping"        → {}
    │       └── 未知          → -32601 Method not found
    └── JSON-RPC ヘルパー
        ├── send(Json)            stdout に1行 JSON 出力 + flush
        ├── send_result(id, r)    成功応答
        ├── send_error(id, c, m)  エラー応答
        ├── send_tool_result()    ツール結果（isError 対応）
        └── log(msg)              stderr にログ出力
```

---

## バリデーション

Python 版・Node.js 版と同一のルール。

| 層 | フィールド | 型チェック | 非空チェック |
|---|---|---|---|
| 事実層 | user, thinking, assistant | C++ の WriteArgs 構造体で保証 | `empty()` で検査 |
| 解釈層 | current_focus, theory_of_mind, self_narrative, annotation | C++ の WriteArgs 構造体で保証 | 不要（空許容） |

`get_str(key)` はキーが存在しないか string でない場合に空文字列を返す。事実層の空チェックで検出される。

---

## データ互換性

C++ 版が書き出す `current.json` は Python 版・Node.js 版と完全互換。

検証項目：
- C++ 版 write → Python 版 read: `json.load()` で正常に読める
- C++ 版 write → Node.js 版 read: `JSON.parse()` で正常に読める
- Python 版 write → C++ 版 read: `json::Value::parse()` で正常に読める
- `_schema` のフィールド順序が全実装で一致する

---

## テスト計画

### CLI テストケース

| # | テスト | コマンド | 期待結果 |
|---|---|---|---|
| 1 | 空読み出し | `./coglog read` | `(no metalog found)` |
| 2 | 書き込み | `echo '{...}' \| ./coglog write` | `metalog: turn 1 written` |
| 3 | 読み出し | `./coglog read` | 書き込んだエントリ（_schema 付き） |
| 4 | turn_id 採番 | 2回目 write → read | `turn_id: 2` |
| 5 | UTF-8 日本語 | 日本語フィールドで write → read | 正常に読み書き |
| 6 | クリア | `./coglog clear` | `metalog: cleared` |
| 7 | クリア後読み出し | `./coglog read` | `(no metalog found)` |
| 8 | 二重クリア | `./coglog clear` (データなし) | `metalog: no existing metalog` |
| 9 | バリデーション | user 空で write | exit 1, `missing required field: user` |
| 10 | 不正 JSON | 壊れた JSON で write | exit 1, エラーメッセージ |
| 11 | Python 互換 | C++ write → Python read | `json.load()` 成功 |

### MCP テストケース

| # | テスト | メソッド | 期待結果 |
|---|---|---|---|
| 1 | ハンドシェイク | `initialize` | protocolVersion, capabilities, serverInfo |
| 2 | initialized 通知 | `notifications/initialized` | 出力なし |
| 3 | ツール一覧 | `tools/list` | 3ツール定義 |
| 4 | 空読み出し | `tools/call` metalog_read | `(no metalog found)` |
| 5 | 書き込み | `tools/call` metalog_write | エントリ JSON |
| 6 | 読み出し | `tools/call` metalog_read | 書き込んだエントリ |
| 7 | バリデーションエラー | `tools/call` metalog_write (user空) | `isError: true` |
| 8 | クリア | `tools/call` metalog_clear | `{ "cleared": true }` |
| 9 | ping | `ping` | `{}` |
| 10 | 未知メソッド | `nonexistent` | `-32601 Method not found` |
| 11 | 不正 JSON | `not valid json` | `-32700 Parse error` |
| 12 | 未知ツール | `tools/call` unknown_tool | `isError: true` |
| 13 | UTF-8 日本語 | metalog_write (日本語) → metalog_read | 正常に往復 |

---

## 規模見積もり

| セクション | CLI | MCP |
|---|---|---|
| ミニ JSON ライブラリ | ~300行 | ~300行（複製） |
| MetaLog コア | ~150行 | ~150行（複製） |
| CLI フロントエンド | ~85行 | — |
| MCP ツール定義 | — | ~80行 |
| MCP JSON-RPC 層 | — | ~60行 |
| MCP ハンドラ | — | ~70行 |
| MCP メインループ | — | ~50行 |
| ドキュメントコメント | ~30行 | ~20行 |
| ヘッダー・名前空間 | ~20行 | ~20行 |
| **合計** | **~585行** | **~750行** |

実測値: CLI 635行, MCP 806行。見積もりの10%増で着地。

---

## ビルド

### 最小コマンド

```bash
# 通常のコンパイラ
g++ -std=c++17 -Os -o coglog coglog-v0.9.1.cpp
g++ -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp

# Cosmopolitan（ユニバーサルバイナリ）
cosmocc -std=c++17 -Os -o coglog coglog-v0.9.1.cpp
cosmocc -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp

# 極小バイナリ
cosmocc -std=c++17 -Os -mtiny -o coglog coglog-v0.9.1.cpp
```

### GitHub Actions

```yaml
on:
  push:
    tags: ["v*.*.*"]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: setup cosmocc
        run: |
          mkdir -p /tmp/cosmocc && cd /tmp/cosmocc
          wget https://cosmo.zip/pub/cosmocc/cosmocc.zip
          unzip cosmocc.zip

      - name: build
        run: |
          /tmp/cosmocc/bin/cosmocc -std=c++17 -Os -o coglog coglog-v0.9.1.cpp
          /tmp/cosmocc/bin/cosmocc -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp

      - uses: softprops/action-gh-release@v2
        with:
          files: |
            coglog
            coglog-mcp-server
```

---

## 変更なし

以下のファイルに変更はない：

- `metalog-v0.9.1.py` — Python CLI
- `metalog-v0.9.1.mjs` — Node.js CLI
- `metalog-mcp-server-v0.9.1.py` — Python MCP サーバー
- `metalog-mcp-server-v0.9.1.mjs` — Node.js MCP サーバー
- `DESIGN-v0.9.1.md` — 設計書
- `README-py-v0.9.1.md` — Python版 README
- `README-mjs-v0.9.1.md` — Node.js版 README
- `README-mcp-v0.9.1.md` — MCP版 README

C++ 版は既存実装と並立する追加のインターフェースである。

---

## バージョニング

MetaLog のバージョンは **v0.9.1 のまま**。

C++ 版は新しいビルドターゲットの追加であり、データ構造・バリデーション・`_schema` に変更はない。全実装が同一の `current.json` を共有可能。
