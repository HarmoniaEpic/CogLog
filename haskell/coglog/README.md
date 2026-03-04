# CogLog v0.9.1 — Haskell 実装

## これは何か

CogLog の **分析層** 実装。
Python 版や Node.js 版の代替ではなく、DESIGN-v0.9.1.md の **実行可能な注釈** である。

Haskell 版が照射する命題:

> **`advance` が純粋で `write` が不純であるという分離は、設計者の意図ではなく数学的な必然である。**

この命題を型シグネチャが証明する。

## ファイル構成

```
CogLog.lhs      Literate Haskell — 散文 + 純粋核
Adapter.hs       current.json との接続（JSON手書き + ファイルI/O + CLI）
```

依存の方向は一方向: `Adapter → CogLog`。CogLog.lhs は Adapter.hs の存在を知らない。

**CogLog.lhs は単体でコンパイルが通る。** 純粋核が外部世界に依存しないことが、ファイルシステム上で保証される。

## 必要なもの

GHC のみ。外部パッケージは一切不要。

```
# Ubuntu/Debian
apt install ghc

# macOS
brew install ghc
```

## 使い方

### コンパイル

```bash
ghc -o coglog-hs Adapter.hs CogLog.lhs
```

### CLI

```bash
# 読み出し
./coglog-hs read

# 書き込み（stdin から JSON）
echo '{
  "user": "Hello",
  "thinking": "Greeting detected",
  "assistant": "Hi there!",
  "current_focus": "testing",
  "theory_of_mind": "",
  "self_narrative": "",
  "annotation": ""
}' | ./coglog-hs write

# クリア
./coglog-hs clear
```

### runghc（コンパイルなし）

```bash
runghc Adapter.hs read
echo '{"user":"...","thinking":"...","assistant":"..."}' | runghc Adapter.hs write
```

## CogLog.lhs の読み方

CogLog.lhs は Literate Haskell である。

```
通常の .hs:  コードの中にコメントがある
.lhs:        散文の中にコードが埋まっている
```

`>` で始まる行がコード。それ以外は散文。GHC は散文を無視し、コード行のみをコンパイルする。

### 章立て

| 章 | 内容 | コードの役割 |
|---|---|---|
| 第1章 | 漸化式 | module 宣言 |
| 第2章 | 型の世界 | NonEmptyText, Layers, Entry, WriteArgs, RawArgs |
| 第3章 | validate | mkNonEmptyText, validateArgs |
| 第4章 | _schema | coglogSchema |
| 第5章 | advance | advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry |
| 補遺 | IO の不在 | （コードなし——不在そのものが論証） |

## 型が証明すること

### 1. advance の純粋性

```haskell
advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry
```

シグネチャに IO がない。advance は副作用を持たない。これは宣言ではなく、コンパイラによる保証である。もし advance がファイルを読み書きしようとすれば、型が `IO Entry` に変わり、コンパイルが通らなくなる。

### 2. バリデーションの型表現

```haskell
newtype NonEmptyText = NonEmptyText String  -- コンストラクタ非公開

mkNonEmptyText :: String -> Either ValidationError NonEmptyText
mkNonEmptyText "" = Left (ValidationError "non-empty string required")
mkNonEmptyText s  = Right (NonEmptyText s)
```

NonEmptyText を構築する唯一の方法は mkNonEmptyText を経由すること。空文字列は型レベルで排除される。

Python 版では `validate()` の呼び忘れが実行時バグになる。Haskell 版では NonEmptyText を持っている時点でバリデーション済みが保証される。

### 3. 純粋/不純の分離

```
CogLog.lhs:   IO という文字が一度も現れない
Adapter.hs:   IO が main, readMetalog, writeMetalog に現れる
```

この分離は CogLog のアーキテクチャ全体に通底する。Python 版の `write()` が `advance` + ファイル書き込みを兼ねているのに対し、Haskell 版ではその兼任がコンパイラによって禁止されている。

## 他の実装との関係

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）    Common Lisp      Haskell
             データ=コード    純粋/不純の分離
             _schemaの必然性   advanceの純粋性
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
実用（どう）    Python    Node.js    ...
```

各分析層は DESIGN の異なる面を照射する:

| 実装 | 照射する面 |
|---|---|
| Common Lisp (coglog.lisp) | ホモイコニシティ。_schema が必然であること |
| Common Lisp (recurrent-quine) | 自己書き換え。コード=データ=状態の一致 |
| **Haskell** | **純粋/不純の分離。advance が純粋であることの型による証明** |

## Python 互換

Haskell 版は `.metalog/current.json` を Python 版・Node.js 版と同じ形式で読み書きする。

```bash
# Haskell で書いて Python で読む
echo '{"user":"...","thinking":"...","assistant":"..."}' | ./coglog-hs write
python3 metalog-v0_9_1.py read

# Python で書いて Haskell で読む
echo '{"user":"...","thinking":"...","assistant":"..."}' | python3 metalog-v0_9_1.py write
./coglog-hs read
```

## 規模

| ファイル | 行数 | 内訳 |
|---|---|---|
| CogLog.lhs | 260 | 散文 ~99, コード ~109, 空行 ~52 |
| Adapter.hs | 377 | JSON手書き, ファイルI/O, CLI |
| **合計** | **637** | |

PLAN 見積もり (~320行) との差分の大部分は、手書き JSON パーサー/シリアライザーの現実的コスト。aeson を使えば ~200行削減できるが、aeson の derive マクロが何を自動生成しているかを型で明示的に見せることが分析層の目的であるため、手書きが正しい選択である。

## バージョン

CogLog v0.9.1。Haskell 版の追加はバージョン番号を変更しない。
