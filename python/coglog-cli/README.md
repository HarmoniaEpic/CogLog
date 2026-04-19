# CogLog v0.9.1 (Python CLI)

AIの直前ターンの三層構造を保持し次ターンで参照可能にする仕組み。

A mechanism that retains the three-layer structure of the AI's previous turn and makes it available for reference in the next turn.

## このパッケージについて / About This Package

`coglog-cli` は PyPI の [`coglog`](https://pypi.org/project/coglog/) と同一の機能を、npm / Go / 他レジストリと揃えた名前で提供するパッケージです。内容・動作は `coglog` と等価です。

`coglog-cli` provides the same functionality as [`coglog`](https://pypi.org/project/coglog/) on PyPI, under a name aligned with npm / Go / other registries. Content and behavior are equivalent to `coglog`.

> **注 / Note**: `coglog` と `coglog-cli` を同時にインストールすることはできません（同名ファイルの衝突はしませんが、両方を管理する理由もありません）。どちらか一方を選んでください。
>
> You cannot install both `coglog` and `coglog-cli` together in a meaningful way — pick one.

## インストール / Installation

```bash
pip install coglog-cli
```

## 必要環境 / Requirements

- Python 3.9+（標準ライブラリのみ / standard library only）

## 使い方 / Usage

### モジュール実行 / Module execution

```bash
python -m coglog_cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | python -m coglog_cli write
python -m coglog_cli clear
```

### スクリプトエントリポイント / Script entrypoint

```bash
coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-cli write
coglog-cli clear
```

## モジュールとして使用 / Use as a Module

```python
from coglog_cli import CogLog
ml = CogLog()
prev = ml.read()  # dict | None
ml.write(
    user="...",
    thinking="...",
    assistant="...",
    current_focus="...",
    theory_of_mind="...",
    self_narrative="...",
    annotation="...",
)
ml.clear()
```

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

## データディレクトリ / Data Directory

データは `coglog` と同じ場所（デフォルト `$HOME/.coglog/`）に保存され、両パッケージ間でデータが共有されます。環境変数 `COGLOG_DIR` で変更可能です。

Data is stored in the same location as `coglog` (default `$HOME/.coglog/`), and the two packages share data. Override with the `COGLOG_DIR` environment variable.

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献 / Design philosophy and references

## ライセンス / License

MIT
