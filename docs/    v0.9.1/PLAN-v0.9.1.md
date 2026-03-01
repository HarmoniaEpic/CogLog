# MetaLog v0.9.1 実装計画

## 変更の性質

**PATCH VERSION**（`_schema` フィールドの自動付与。既存フィールドの意味・バリデーションに変更なし）

---

## 動機

MetaLogのスキーマ情報——フィールド定義、バリデーションルール、解釈層の設計意図——はREADMEとDESIGNにのみ存在する。しかし実運用では、ツール単体（.mjs / .py）だけがセッション内にあり、ドキュメントがコンテキストにない場面が多い。

current.jsonに `_schema` フィールドを内在させることで、データ自身が自分の読み方を携えて移動する。これはアフォーダンス——環境が行為者に行為の可能性を提供する構造——のデータ設計への適用である。

---

## _schemaの定義

```json
{
  "_schema": {
    "version": "0.9.1",
    "fact_layer": {
      "user": "non-empty string required — user's original utterance",
      "thinking": "non-empty string required — AI's full thinking process",
      "assistant": "non-empty string required — AI's original output"
    },
    "interpretation_layer": {
      "current_focus": "string required, empty OK — present: what am I working on?",
      "theory_of_mind": "string required, empty OK — other: what is the user's state?",
      "self_narrative": "string required, empty OK — self: who am I in this moment?",
      "annotation": "string required, empty OK — future: what should I do next?"
    },
    "constraints": {
      "window_size": "1 turn (overwritten each write)",
      "interpretation_empty": "choosing not to write is itself a metacognitive act"
    }
  },
  "turn_id": 1,
  "...": "..."
}
```

### 設計判断

- **構造化オブジェクト**: フィールド名と説明が1対1対応。AIが各フィールドの意味を確実にマッピングできる
- **fact_layer / interpretation_layer の分離**: バリデーションルールが異なる二層の存在を構造で表現
- **各フィールド説明の書式**: `"型制約 — 方向ラベル: 問いかけ"` で統一。問いかけ形式がwrite時のプロンプトとして機能
- **constraints**: 窓サイズ1と空許容の設計意図。最小限に留める
- **先頭配置**: entryオブジェクトの最初のフィールドとして `_schema` を置く。JSON出力で最初に目に入る

### バリデーション

`_schema` はバリデーション対象外。write()が自動生成し、ユーザーが渡す必要はない。read()はcurrent.jsonをそのまま返すため、`_schema` も含まれる。

---

## 成果物一覧

| # | ファイル | 元ファイル | 変更種別 |
|---|---------|-----------|---------|
| 1 | `metalog-v0.9.1.mjs` | `metalog-v0.9.0.mjs` | 改修 |
| 2 | `metalog-v0.9.1.py` | `metalog-v0.9.0.py` | 改修 |
| 3 | `DESIGN-v0.9.1.md` | `DESIGN-v0.9.0.md` | 改修 |
| 4 | `README-mjs-v0.9.1.md` | `README-mjs-v0.9.0.md` | 改修 |
| 5 | `README-py-v0.9.1.md` | `README-py-v0.9.0.md` | 改修 |

---

## ファイル別変更詳細

### 1. `metalog-v0.9.1.mjs`（改修）

| 箇所 | 変更内容 |
|------|---------|
| モジュールdocstring | v0.9.1に更新 |
| **定数 `SCHEMA`** | **新設**。_schemaオブジェクトをモジュール定数として定義 |
| `write()` | entryオブジェクトの先頭に `_schema: SCHEMA` を追加 |
| `read()` | 変更なし |
| `clear()` | 変更なし |
| バリデーション | 変更なし |
| CLIヘルプテキスト | v0.9.1に更新 |

### 2. `metalog-v0.9.1.py`（改修）

| 箇所 | 変更内容 |
|------|---------|
| モジュールdocstring | v0.9.1に更新 |
| **定数 `SCHEMA`** | **新設**。_schemaオブジェクトをモジュール定数として定義 |
| `write()` | entry辞書の先頭に `"_schema": SCHEMA` を追加 |
| `read()` | 変更なし |
| `clear()` | 変更なし |
| バリデーション | 変更なし |
| CLIヘルプテキスト | v0.9.1に更新 |

### 3. `DESIGN-v0.9.1.md`（改修）

| 箇所 | 変更内容 |
|------|---------|
| 概要 | v0.9.1記述。_schemaに言及 |
| スキーマJSON | _schemaフィールドを先頭に追加 |
| 構造の設計意図 | _schemaの位置づけ（メタデータ層）を追記 |
| バリデーションテーブル | _schemaの扱いを注記（自動生成・バリデーション対象外） |
| フィールド定義テーブル | _schemaの行を追加 |
| **新節: _schemaのアフォーダンス性** | データのself-documenting性、アフォーダンスの視座を記述 |
| バージョン履歴 | v0.9.1エントリを追加 |

### 4. `README-mjs-v0.9.1.md`（改修）

| 箇所 | 変更内容 |
|------|---------|
| 冒頭説明 | v0.9.1。_schemaに言及 |
| データ形式JSON | _schemaフィールドを先頭に追加 |
| フィールド定義テーブル | _schemaの行を追加 |
| CLIコマンド名 | v0.9.1に更新 |
| モジュール使用例のimport | v0.9.1に更新 |
| セッションまたぎ | v0.9.1に更新 |
| ファイル構成 | v0.9.1に更新 |
| 変更履歴 | v0.9.1エントリを追加 |

### 5. `README-py-v0.9.1.md`（改修）

| 箇所 | 変更内容 |
|------|---------|
| 冒頭説明 | v0.9.1。_schemaに言及 |
| データ形式JSON | _schemaフィールドを先頭に追加 |
| フィールド定義テーブル | _schemaの行を追加 |
| CLIコマンド名 | v0.9.1に更新 |
| Node.js版との対応テーブル | v0.9.1に更新 |
| セッションまたぎ | v0.9.1に更新 |
| ファイル構成 | v0.9.1に更新 |
| 変更履歴 | v0.9.1エントリを追加 |

---

## 変更しないもの

- `read()` / `clear()` のロジック
- バリデーションのルール体系（事実層＝非空必須、解釈層＝必須・空許容）
- 窓サイズ・上書きロジック
- 解釈層の四軸（current_focus, theory_of_mind, self_narrative, annotation）
- CLI read/write/clear の動作
- ディレクトリ構造（`.metalog/current.json`）

---

## 作業順序

1. `metalog-v0.9.1.mjs`（コア変更。テスト基盤）
2. `metalog-v0.9.1.py`（対称確認）
3. `DESIGN-v0.9.1.md`（アフォーダンス節を含む設計書）
4. `README-mjs-v0.9.1.md`
5. `README-py-v0.9.1.md`
