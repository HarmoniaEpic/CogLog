# CogLog v0.9.1 (Common Lisp CLI)

AIの直前ターンの三層構造を保持し次ターンで参照可能にする仕組み。

A mechanism that retains the three-layer structure of the AI's previous turn and makes it available for reference in the next turn.

## インストール / Installation

```bash
(ql:quickload :coglog)
```

## 必要環境 / Requirements

- SBCL 2.0+

## 使い方 / Usage

```bash
sbcl --script adapter.lisp read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | sbcl --script adapter.lisp write
sbcl --script adapter.lisp clear
```

## 設計上の特徴 / Design Features

ホモイコニシティにより `_schema` がデータの自己記述として自然に成立する。

Through homoiconicity, `_schema` naturally functions as data's self-description.

## データ形式 / Data Format

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

## 構造 / Structure

```
事実層（layers）   何があったか / What happened
  ├── user         他者の入力 / Other's input
  ├── thinking     自己の内部 / Self's internal
  └── assistant    自己の外部出力 / Self's external output

解釈層             それをどう読んだか / How it was interpreted
  ├── current_focus    現在 / Present
  ├── theory_of_mind   他者 / Other
  ├── self_narrative   自己 / Self
  └── annotation       未来 / Future
```

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献 / Design philosophy and references

## ライセンス / License

MIT
