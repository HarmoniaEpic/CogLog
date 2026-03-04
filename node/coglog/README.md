# MetaLog v0.9.1（Node.js）

AIの直前の会話ターンにおける三層構造（ユーザー発話・思考過程・AI発話）を保持し、次ターン開始時に参照可能にする仕組み。

v0.9.1では `_schema` フィールドを導入し、current.jsonを自己記述的なデータとした。データ自身が自分の読み方を携えて移動する。

## ファイル構成

```
metalog/
├── DESIGN-v0.9.1.md     # 設計書
├── README-mjs-v0.9.1.md # 本ファイル
├── metalog-v0.9.1.mjs   # コアモジュール＋CLI
└── .metalog/
    └── current.json     # 現在の窓（1ターン分、自動生成）
```

## 必要環境

- Node.js 18以上

## 使い方

### CLI

```bash
# 直前ターンのメタログを読み出す（_schemaを含む）
node metalog-v0.9.1.mjs read

# 現ターンを書き込む（JSONをstdinから受け取る・全フィールド必須）
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | node metalog-v0.9.1.mjs write

# メタログをリセットする
node metalog-v0.9.1.mjs clear
```

### モジュール

```javascript
import { MetaLog } from './metalog-v0.9.1.mjs';

const ml = new MetaLog();

// 読み出し（データなしの場合はnullを返す。データありの場合は_schemaを含む）
const prev = await ml.read();

// 書き込み（全フィールド必須。_schemaは自動付与される）
await ml.write({
  user: "ユーザーの発話",
  thinking: "AIの思考過程",
  assistant: "AIの出力",
  current_focus: "今取り組んでいること",
  theory_of_mind: "ユーザーの意図に関する推測",
  self_narrative: "この対話を経ての即興的な自己物語",
  annotation: "次の自分への申し送り"
});

// 解釈層は空文字列を許容する
await ml.write({
  user: "ユーザーの発話",
  thinking: "AIの思考過程",
  assistant: "AIの出力",
  current_focus: "",          // 「現在地の確認を省略する」判断
  theory_of_mind: "",         // 「今は推測しない」という判断
  self_narrative: "",         // 「今は語らない」という判断
  annotation: ""              // 「申し送りなし」という判断
});

// リセット
await ml.clear();
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
  "timestamp": "2026-02-24T12:00:00.000Z",
  "layers": {
    "user": "ユーザーの発話（原文）",
    "thinking": "AIの思考過程（全文）",
    "assistant": "AIの出力（原文）"
  },
  "current_focus": "今何に取り組んでいるか",
  "theory_of_mind": "ユーザーの意図・状態に関する推測",
  "self_narrative": "この対話を経て「私」はどういう存在か",
  "annotation": "次の自分への自由記述の申し送り"
}
```

| フィールド | 型 | 必須 | 空許容 | 自動生成 | 説明 |
|-----------|-----|------|-------|---------|------|
| `_schema` | object | — | — | ✓ | 自己記述的スキーマ。write時に自動付与 |
| `turn_id` | number | ✓ | — | ✓ | 単調増加。セッション内で一意 |
| `timestamp` | string | ✓ | — | ✓ | ISO8601形式 |
| `layers.user` | string | ✓ | 非空 | — | ユーザーの発話原文 |
| `layers.thinking` | string | ✓ | 非空 | — | AIの思考過程全文 |
| `layers.assistant` | string | ✓ | 非空 | — | AIの出力原文 |
| `current_focus` | string | ✓ | 空許容 | — | 自由記述。今何に取り組んでいるかの確認 |
| `theory_of_mind` | string | ✓ | 空許容 | — | 自由記述。ユーザーの意図・状態に関する推測 |
| `self_narrative` | string | ✓ | 空許容 | — | 自由記述。この瞬間の即興的な自己物語 |
| `annotation` | string | ✓ | 空許容 | — | 自由記述。次の自分への申し送り |

## バリデーション

全フィールド必須。ただし事実層と解釈層で空文字列の扱いが異なる。`_schema` はバリデーション対象外（自動生成）。

- **事実層**（user, thinking, assistant）: 非空の文字列を要求。空文字列はエラー
- **解釈層**（current_focus, theory_of_mind, self_narrative, annotation）: 文字列型を要求。空文字列は許容

何を書くかの判断自体がメタ認知的行為であり、意図的に空にする判断も一つの判断である。

## 構造

```
メタデータ層                  このデータの読み方
  └── _schema                自己記述的スキーマ      （自動生成）

事実層（layers）             何があったか
  ├── user                   他者の入力              （必須・非空）
  ├── thinking               自己の内部              （必須・非空）
  └── assistant              自己の外部出力          （必須・非空）

解釈層                       それをどう読んだか
  ├── current_focus          現在（今何に取り組んでいるか）  （必須・空許容）
  ├── theory_of_mind         他者（相手は誰か）              （必須・空許容）
  ├── self_narrative         自己（私は誰か）                （必須・空許容）
  └── annotation             未来（次に何をするか）          （必須・空許容）
```

## _schemaについて

`_schema` はwrite時にツールが自動付与する。ユーザーが渡す必要はない。

read時に `_schema` が含まれることで、データ自身が「このフィールドにはこう書くべきだ」という情報を携える。これはアフォーダンス——環境が行為の可能性を提供する構造——のデータ設計への適用である。

前セッションのcurrent.jsonをそのまま次のセッションに渡す場合、`_schema` がスキーマ共有を担う。READMEやDESIGNが手元になくても、データ自身が読み方を説明する。

## current_focusガイド

current_focusには以下を記述する：

> 今何に取り組んでいるか。おつかいの子供が「たまご、ぎゅうにゅう」と唱えながら歩くように、短期目標の暗唱として機能する。

annotationが「次に何をするか」（コンパス）であるのに対し、current_focusは「今ここで何が起きているか」（地図）。

## self_narrativeガイド

self_narrativeには以下を記述する：

> この対話を経て「私」はどういう存在か。固定的な自己定義ではなく、この瞬間の即興的な自己物語として記述する。

能力の自己記述（「私は言語モデルで……」）や自己評価（「今回は適切に対応できた」）ではない。対話という環境との相互作用の中で、毎ターン再構成される「私」の物語。

## 最小構成

ツールやファイルシステムなしでも、以下のスキーマをシステムプロンプトで共有することでMetaLogの核心は機能する：

```json
{
  "current_focus": "",
  "theory_of_mind": "",
  "self_narrative": "",
  "annotation": ""
}
```

四フィールド全てが必須。「このテンプレートに合わせて出力してください」の一行で、漸化式は回り始める。

v0.9.1では、前のセッションのcurrent.jsonを渡すだけで `_schema` がスキーマ説明を含むため、テンプレートの共有も不要になる。

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

セッション終了時に `node metalog-v0.9.1.mjs read` の出力を保存し、次のセッションの冒頭でwriteに渡すことで、セッション間の引き継ぎが可能。`_schema` が含まれるため、新しいセッションのAIはスキーマを自動的に把握する。

```bash
# セッション終了時：メタログをエクスポート
node metalog-v0.9.1.mjs read > metalog_export.json

# 次のセッション開始時：メタログをインポート
cat metalog_export.json | node metalog-v0.9.1.mjs write
```

## 詳細

設計思想・背景文献については [DESIGN-v0.9.1.md](./DESIGN-v0.9.1.md) を参照。

## 変更履歴

| バージョン | 変更内容 |
|-----------|---------|
| v0.1 | 初版。三層構造＋annotation |
| v0.2 | theory_of_mindフィールド追加。解釈層の二軸化 |
| v0.8 | self_narrativeフィールド追加。解釈層の三軸化 |
| v0.8.1 | 全フィールド必須化。二段階バリデーション |
| v0.9.0 | current_focusフィールド追加。解釈層の四軸化（現在→他者→自己→未来）。CLI統合 |
| v0.9.1 | _schemaフィールド追加。データの自己記述化 |
