# CogLog v0.9.1 (Java CLI)

AIの直前ターンの三層構造を保持し次ターンで参照可能にする仕組み。

## インストール

```bash
# Maven Central
mvn dependency:get -Dartifact=io.github.harmoniaepic:coglog:0.9.1
```

## 必要環境

- JDK 11+（外部依存なし）

## 使い方

```bash
java -jar coglog-0.9.1.jar read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | java -jar coglog-0.9.1.jar write
java -jar coglog-0.9.1.jar clear
```

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

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献

## ライセンス

MIT

