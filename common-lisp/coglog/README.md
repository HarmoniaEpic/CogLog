# CogLog v0.9.1 (Common Lisp CLI)

AIの直前ターンの三層構造を保持し次ターンで参照可能にする仕組み。

## インストール

```bash
(ql:quickload :coglog)
```

## 必要環境

- SBCL 2.0+

## 使い方

```bash
sbcl --script adapter.lisp read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | sbcl --script adapter.lisp write
sbcl --script adapter.lisp clear
```

## 設計上の特徴

ホモイコニシティにより `_schema` がデータの自己記述として自然に成立する。

## データ形式

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

## 構造

```
事実層（layers）   何があったか
  ├── user         他者の入力
  ├── thinking     自己の内部
  └── assistant    自己の外部出力

解釈層             それをどう読んだか
  ├── current_focus    現在
  ├── theory_of_mind   他者
  ├── self_narrative   自己
  └── annotation       未来
```


## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/DESIGN-v0.9.1.md)

## ライセンス

MIT

