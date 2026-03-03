# CogLog Python版 v0.9.1 リネーム計画

## 概要

スタンドアロン Python 版（`metalog-v0.9.1.py`）および MCP サーバー版（`metalog-mcp-server-v0.9.1.py`）を MetaLog → CogLog にリネームする。データディレクトリを `~/.coglog/` に汎用化する。

---

## 変更の性質

**PATCH VERSION 相当**（リネーム + DATA_DIR 汎用化。データ構造・バリデーション・_schema に変更なし）

バージョンナンバリングは v0.9.1 のまま維持する。

---

## 対象ファイル

### ソース

| # | 現行ファイル名 | 変更後ファイル名 | 変更種別 |
|---|---------------|----------------|---------|
| 1 | `metalog-v0.9.1.py` | `coglog-v0.9.1.py` | リネーム + 改修 |
| 2 | `metalog-mcp-server-v0.9.1.py` | `coglog-mcp-server-v0.9.1.py` | リネーム + 改修 |

### ドキュメント

| # | 現行ファイル名 | 変更後ファイル名 | 変更種別 |
|---|---------------|----------------|---------|
| 3 | `README-py-v0.9.1.md` | `README-py-v0.9.1.md` | 改修（ファイル名は維持） |

DESIGN-v0.9.1.md はスキル版作業で CogLog 化済み。README-mcp-v0.9.1.md は mjs 版計画で対応する（py/mjs 共用ドキュメントのため）。

---

## スキル版との関係

スキル版 `coglog-skill-v0.9.1.zip` の `coglog.py` は **スキル環境に適合させた版** であり、スタンドアロン版との差異は DATA_DIR のデフォルト解決のみ。

| | スキル版 (`coglog.py`) | スタンドアロン版 (`coglog-v0.9.1.py`) |
|---|---|---|
| DATA_DIR | `Path.home() / ".coglog"` | `Path.home() / ".coglog"` |
| 解決結果（同一） | `~/.coglog/` | `~/.coglog/` |

今回の汎用化により、**スキル版とスタンドアロン版の DATA_DIR が同一**になる。従来はスキル版が `/home/claude/.metalog` にハードコードされていたのに対し、スタンドアロン版は `__file__` 起点だった。この差異が解消される。

---

## ファイル別変更詳細

### 1. `coglog-v0.9.1.py`（リネーム + 改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| docstring | `MetaLog v0.9.1` | `CogLog v0.9.1` |
| CLI 使用例 | `python3 metalog-v0.9.1.py` | `python3 coglog-v0.9.1.py` |
| モジュール使用例 | `from metalog import MetaLog` | `from coglog import CogLog` |
| DATA_DIR | `Path(__file__).resolve().parent / ".metalog"` | `Path.home() / ".coglog"` |
| クラス名 | `class MetaLog` | `class CogLog` |
| クラス docstring | `Single-window metalog:` | `Single-window coglog:` |
| メソッド docstrings | `metalog` → `coglog` | — |
| CLI 出力 | `metalog: turn N written` | `coglog: turn N written` |
| CLI 出力 | `(no metalog found)` | `(no coglog found)` |
| CLI 出力 | `metalog: cleared` | `coglog: cleared` |
| CLI エラー | `metalog error:` | `coglog error:` |
| CLI ヘルプ | `usage: metalog-v0.9.1.py` | `usage: coglog-v0.9.1.py` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

#### DATA_DIR 変更の詳細

```python
# 現行
DATA_DIR = Path(__file__).resolve().parent / ".metalog"

# 変更後
DATA_DIR = Path.home() / ".coglog"
```

`Path.home()` は Python 3.5+ で利用可能。環境変数 `HOME`（Unix）/ `USERPROFILE`（Windows）を参照し、未設定時は `pwd.getpwuid(os.getuid()).pw_dir` にフォールバックする。

`data_dir` 引数によるオーバーライドは維持する。

#### 不要になるもの

`__file__` は DATA_DIR 算出に不要となる。ただし削除対象ではない（Python は `__file__` を暗黙に持つため、コードの変更は不要）。

### 2. `coglog-mcp-server-v0.9.1.py`（リネーム + 改修）

MCP サーバーは CLI 版のクラスを複製（コピー）して内蔵する設計。変更箇所は CLI 版と対称的。

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| docstring | `MetaLog MCP Server v0.9.1` | `CogLog MCP Server v0.9.1` |
| コメント | `MetaLog class (copied from metalog-v0.9.1.py)` | `CogLog class (copied from coglog-v0.9.1.py)` |
| DATA_DIR | `Path(__file__).resolve().parent / ".metalog"` | `Path.home() / ".coglog"` |
| クラス名 | `class MetaLog` | `class CogLog` |
| インスタンス生成 | `ml = MetaLog()` | `cl = CogLog()` |
| 変数名 | `ml` → `cl`（全箇所） | — |
| SERVER_INFO | `"metalog"` | `"coglog"` |
| ツール名 | `metalog_read`, `metalog_write`, `metalog_clear` | `coglog_read`, `coglog_write`, `coglog_clear` |
| ツール description | `metalog` → `coglog` | — |
| ログプレフィックス | `metalog-mcp:` | `coglog-mcp:` |
| ツール結果テキスト | `(no metalog found)` | `(no coglog found)` |
| clear 戻り値 | `"no existing metalog"` | `"no existing coglog"` |

### 3. `README-py-v0.9.1.md`（改修）

| 箇所 | 現行 | 変更後 |
|------|------|--------|
| タイトル | `MetaLog v0.9.1 (Python)` | `CogLog v0.9.1 (Python)` |
| 冒頭説明 | `MetaLog` | `CogLog` |
| ファイル構成 | 単一ツリー（ソース + データ同居） | **ソースとデータを分離した二段構成** |
| ファイル構成 | `metalog/`, `.metalog/`, `metalog-v0.9.1.py` | `coglog/`, `~/.coglog/`, `coglog-v0.9.1.py` |
| CLI 例 | `python3 metalog-v0.9.1.py` | `python3 coglog-v0.9.1.py` |
| モジュール例 | `from metalog import MetaLog` | `from coglog import CogLog` |
| モジュール例 | `ml = MetaLog()` | `cl = CogLog()` |
| モジュール例 | `metalog-v0.9.1.py を metalog.py にリネーム` | `coglog-v0.9.1.py を coglog.py にリネーム` |
| カスタムディレクトリ例 | `MetaLog(data_dir="/path/to/custom/.metalog")` | `CogLog(data_dir="/path/to/custom/.coglog")` |
| データ位置 | `.metalog/current.json` | `~/.coglog/current.json` |
| セッションまたぎ例 | `metalog-v0.9.1.py` | `coglog-v0.9.1.py` |
| セッションまたぎ例 | `metalog_export.json` | `coglog_export.json` |
| Node.js版との対応テーブル | `metalog-v0.9.1.py` / `metalog-v0.9.1.mjs` | `coglog-v0.9.1.py` / `coglog-v0.9.1.mjs` |
| 変更履歴 | v0.9.1 行の末尾に「MetaLog → CogLog 改称」追記 | — |

#### ファイル構成の変更

```
# 現行
metalog/
├── DESIGN-v0.9.1.md
├── README-py-v0.9.1.md
├── metalog-v0.9.1.py
└── .metalog/
    └── current.json

# 変更後
ソースコード（配置場所は環境による）
~/coglog/
├── DESIGN-v0.9.1.md
├── README-py-v0.9.1.md
└── coglog-v0.9.1.py

データ（自動生成。環境を問わず ~/.coglog/）
~/.coglog/
└── current.json
```

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

1. `coglog-v0.9.1.py` — コア変更。テスト基盤
2. `coglog-mcp-server-v0.9.1.py` — クラス複製部分を 1 から反映 + MCP 固有部分のリネーム
3. `README-py-v0.9.1.md`

---

## テスト計画

### CLI 版

| # | テスト | 期待結果 |
|---|--------|---------|
| 1 | `python3 coglog-v0.9.1.py read`（空） | `(no coglog found)` |
| 2 | write（四軸全指定） | `coglog: turn 1 written` |
| 3 | read（データあり） | _schema 先頭、四軸正順 |
| 4 | write（current_focus 欠落） | `coglog error: missing required field: current_focus` |
| 5 | write（事実層空） | `coglog error: missing required field: user` |
| 6 | write（解釈層全空文字列） | `coglog: turn 2 written` |
| 7 | clear → read | `coglog: cleared` → `(no coglog found)` |
| 8 | `_schema.version` | `"0.9.1"` |
| 9 | データパス確認 | `~/.coglog/current.json` に書き込まれる |
| 10 | py版 write → mjs版 read | 正常に読める（互換性） |

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

### クロス言語互換

| # | テスト | 期待結果 |
|---|--------|---------|
| 18 | py CLI write → mjs CLI read | 正常に読める |
| 19 | mjs MCP write → py CLI read | 正常に読める |
| 20 | py CLI write → mjs MCP read | 正常に読める |

三者とも `~/.coglog/current.json` を共有するため、データ互換性は自明だが、リネーム作業のリグレッション検出のために明示的に検証する。

---

## 備考

### スキル版との差異の解消

| 項目 | 旧（v0.9.1 リネーム前） | 新（リネーム後） |
|------|----------------------|----------------|
| スタンドアロン版 DATA_DIR | `__file__` 起点（相対） | `Path.home() / ".coglog"`（絶対） |
| スキル版 DATA_DIR | `/home/claude/.metalog`（ハードコード） | `Path.home() / ".coglog"`（汎用） |
| 差異 | あり | **なし** |

DATA_DIR 解決方式が統一されたことで、スキル版のスクリプトをスタンドアロンとして使う場合（あるいはその逆）に動作の違いが生じなくなる。

### `__file__` 起点からの脱却の理由

従来の `Path(__file__).resolve().parent / ".metalog"` には以下の問題があった：

1. **読み取り専用環境**: スキルデプロイ先（`/mnt/skills/`）が読み取り専用のため書き込み失敗
2. **環境依存**: ソースの配置場所がデータの所在を決定するため、ソースを移動するとデータパスが変わる
3. **複数インスタンス**: 同じソースを複数箇所にコピーすると、それぞれ別の `.coglog/` ディレクトリにデータが分散する

`Path.home()` 起点にすることで、ソースの配置場所に関係なくデータが `~/.coglog/` に集約される。`data_dir` 引数によるオーバーライドは維持するため、明示的に分離が必要な用途にも対応可能。
