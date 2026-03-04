# CogLog Recurrent Quine v0.9.1 (Common Lisp)

自分自身にデータを書き込む自己書き換えプログラム。

## 必要環境

- SBCL 2.0+

## 使い方

```bash
sbcl --script recurrent-quine.lisp read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | sbcl --script recurrent-quine.lisp write
sbcl --script recurrent-quine.lisp clear
```

## 特徴

- **自己書き換え**: `write` 後のファイル自身がデータを含んだ有効なプログラム
- **クワイン性**: プログラム=データ=状態の一致
- **完全互換**: 他の全言語実装と同じ JSON 形式を入出力

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/DESIGN-v0.9.1.md)

## ライセンス

MIT
