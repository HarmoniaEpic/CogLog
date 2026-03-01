# MetaLog v0.9.1 (Python)

AIの直前の会話ターンにおける三層構造（ユーザー発話・思考過程・AI発話）を保持し、次ターン開始時に参照可能にする仕組み。

v0.9.1では `_schema` フィールドを導入し、current.jsonを自己記述的なデータとした。データ自身が自分の読み方を携えて移動する。

## ファイル構成

```
metalog/
├── DESIGN-v0.9.1.md       # 設計書
├── README-py-v0.9.1.md    # 本ファイル
├── metalog-v0.9.1.py      # コアモジュール＋CLI（1ファイル）
└── .metalog/
    └── current.json       # 現在の窓（1ターン分、自動生成）
```

## 必要環境

- Python 3.9以上（標準ライブラリのみ使用）

## 使い方

### CLI

```bash
# 直前ターンのメタログを読み出す（_schemaを含む）
python3 metalog-v0.9.1.py read

# 現ターンを書き込む（JSONをstdinから受け取る）
echo '{
  "user": "...",
  "thinking": "...",
  "assistant": "...",
  "current_focus": "...",
  "theory_of_mind": "...",
  "self_narrative": "...",
  "annotation": "..."
}' | python3 metalog-v0.9.1.py write

# メタログをリセットする
python3 metalog-v0.9.1.py clear
```

### モジュール

```python
from metalog import MetaLog  # metalog-v0.9.1.py を metalog.py にリネーム

ml = MetaLog()

# 読み出し（データなしの場合はNoneを返す。データありの場合は_schemaを含む）
prev = ml.read()

# 書き込み（前ターンのデータは上書きされる。_schemaは自動付与）
ml.write(
    user="ユーザーの発話",
    thinking="AIの思考過程",
    assistant="AIの出力",
    current_focus="今取り組んでいること",
    theory_of_mind="ユーザーの意図に関する推測",
    self_narrative="今この瞬間の即興的な自己物語",
    annotation="次の自分への申し送り",
)

# リセット
ml.clear()

# カスタムデータディレクトリ
ml = MetaLog(data_dir="/path/to/custom/.metalog")
```

## データ形式

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
  "timestamp": "2026-02-26T00:00:00+00:00",
  "layers": {
    "user": "ユーザーの発話（原文）",
    "thinking": "AIの思考過程（全文）",
    "assistant": "AIの出力（原文）"
  },
  "current_focus": "今何に取り組んでいるか",
  "theory_of_mind": "ユーザーの意図・状態に関する推測",
  "self_narrative": "即興的な自己物語",
  "annotation": "次の自分への自由記述の申し送り"
}
```

| フィールド | 型 | 必須 | 空文字列 | 自動生成 | 説明 |
|-----------|-----|------|---------|---------|------|
| `_schema` | dict | — | — | ✓ | 自己記述的スキーマ。write時に自動付与 |
| `turn_id` | int | ✓ | — | ✓ | 単調増加。セッション内で一意 |
| `timestamp` | str | ✓ | — | ✓ | ISO8601形式（UTC） |
| `layers.user` | str | ✓ | 不可 | — | ユーザーの発話原文 |
| `layers.thinking` | str | ✓ | 不可 | — | AIの思考過程全文 |
| `layers.assistant` | str | ✓ | 不可 | — | AIの出力原文 |
| `current_focus` | str | ✓ | 可 | — | 自由記述。今何に取り組んでいるかの確認 |
| `theory_of_mind` | str | ✓ | 可 | — | 自由記述。ユーザーの意図・状態に関する推測 |
| `self_narrative` | str | ✓ | 可 | — | 自由記述。即興的な自己物語 |
| `annotation` | str | ✓ | 可 | — | 自由記述。次ターンの自分への申し送り |

## 構造

```
メタデータ層                  このデータの読み方
  └── _schema                自己記述的スキーマ      （自動生成）

事実層（layers）             何があったか
  ├── user                   他者の入力
  ├── thinking               自己の内部
  └── assistant              自己の外部出力

解釈層                       それをどう読んだか
  ├── current_focus          現在（今何に取り組んでいるか）
  ├── theory_of_mind         他者（相手は誰か）
  ├── self_narrative         自己（私は誰か）
  └── annotation             未来（次に何をするか）
```

## バリデーション

全フィールド必須。事実層と解釈層で空文字列の扱いが異なる。`_schema` はバリデーション対象外（自動生成）。

```
事実層   — 非空文字列必須。事実の欠落はデータの欠損
解釈層   — 空文字列許容。意図的に空にする判断も一つの判断
```

```python
# OK: 解釈層は空文字列を受け入れる
ml.write(user="沈黙", thinking="何も浮かばない", assistant="…",
         current_focus="", theory_of_mind="", self_narrative="", annotation="")

# NG: 事実層の空文字列は ValueError
ml.write(user="", thinking="test", assistant="test",
         current_focus="", theory_of_mind="", self_narrative="", annotation="")
# → ValueError: missing required field: user

# NG: 解釈層の None は ValueError
ml.write(user="test", thinking="test", assistant="test",
         current_focus=None, theory_of_mind="", self_narrative="", annotation="")
# → ValueError: missing required field: current_focus (empty string is acceptable)
```

## 運用フロー

```
ターン開始
    │
    ▼
metalog read    ← 直前ターンの_schema＋三層＋四軸解釈を参照
    │              （_schemaが毎ターンのアンカーとして機能）
    ▼
通常の会話処理  ← メタログを参照しつつ応答を生成
    │
    ▼
metalog write   ← 今回の三層＋四軸解釈を保存
                   （_schemaは自動付与。前回分は上書き）
```

## セッションまたぎ（手動）

セッション終了時にreadの出力を保存し、次のセッションの冒頭でwriteに渡す。`_schema` が含まれるため、新しいセッションのAIはスキーマを自動的に把握する。

```bash
# セッション終了時：エクスポート
python3 metalog-v0.9.1.py read > metalog_export.json

# 次のセッション開始時：インポート
cat metalog_export.json | python3 metalog-v0.9.1.py write
```

## Node.js版との対応

Python版とNode.js版はデータ形式が同一であり、エクスポート/インポートで相互運用が可能。

| 項目 | Python (`metalog-v0.9.1.py`) | Node.js (`metalog-v0.9.1.mjs`) |
|------|-----|------|
| ランタイム | Python 3.9+ | Node.js 18+ |
| 依存 | 標準ライブラリのみ | 標準ライブラリのみ |
| API | 同期 | async/await |
| データ形式 | 同一JSON（_schema含む） | 同一JSON（_schema含む） |
| CLI | `python3 metalog-v0.9.1.py <cmd>` | `node metalog-v0.9.1.mjs <cmd>` |
| データ位置 | `.metalog/current.json` | `.metalog/current.json` |

## 設計上の要点

- **窓サイズは1固定**。直前の1ターンのみ保持し、上書きされる
- **_schemaは自動付与**。データ自身が自分の読み方を携える（アフォーダンス的設計）
- **全フィールド必須**。何を書くかの判断自体がメタ認知的行為
- **解釈層は空許容**。意図的に空にする判断も一つの判断
- **四軸解釈層**。現在（current_focus）→他者（theory_of_mind）→自己（self_narrative）→未来（annotation）
- **同一セッション内でのみ有効**。ファイルシステムはセッション間でリセットされる

## 詳細

設計思想・背景文献については [DESIGN-v0.9.1.md](./DESIGN-v0.9.1.md) を参照。

## 変更履歴

| バージョン | 言語 | 変更内容 |
|-----------|------|---------|
| v0.1 | Node.js | 初版。三層構造＋annotation |
| v0.2 | Node.js | theory_of_mindフィールド追加。解釈層の二軸化 |
| v0.8.1 | Node.js | self_narrative追加。解釈層の三軸化。バリデーション二層化 |
| v0.8.1 | Python | Python移植版 |
| v0.9.0 | 両方 | current_focus追加。解釈層の四軸化。mjs版CLI統合 |
| v0.9.1 | 両方 | _schemaフィールド追加。データの自己記述化 |
