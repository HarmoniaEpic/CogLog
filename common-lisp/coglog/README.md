# CogLog v0.9.1 — Common Lisp 実装

DESIGN-v0.9.1.md のホモイコニシティからの注釈。

この実装は実用層（Python / Node.js / C++ / Rust）とは異なる目的を持つ。CogLog の `_schema` 設計——データが自分の読み方を携えて移動する——が、S式の世界ではなぜ自明な帰結であるかを、動作するコードで示す。

---

## 位置づけ

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）  ▶ Common Lisp ◀    Haskell
             データ=コード    純粋/不純の分離
                      │
         ┌────┬───────┼───────┬────┐
         ▼    ▼       ▼       ▼    ▼
実用（どう） Python  Node.js   C++  Rust
```

---

## 必要環境

SBCL (Steel Bank Common Lisp)。外部ライブラリ不要。Quicklisp 不要。

```bash
# Ubuntu / Debian
apt install sbcl

# macOS
brew install sbcl
```

---

## ファイル構成

```
coglog.lisp      純粋核 — S式で自己完結。adapter.lisp なしでロード可能
adapter.lisp     current.json との接続 — JSON変換 + ファイルI/O + CLI
```

依存の方向は一方向: `adapter → coglog`。coglog.lisp は JSON やファイルシステムの存在を知らない。

| ファイル | 全行数 | 散文 (;;;) | コード |
|---|---|---|---|
| coglog.lisp | 242 | 148 | 94 |
| adapter.lisp | 349 | 32 | 317 |
| **合計** | **591** | **180** | **411** |

coglog.lisp は散文がコードの約1.6倍。コードが散文を例証する構成。

---

## 使い方

### CLI

```bash
# 読み出し
sbcl --script adapter.lisp read

# 書き込み（stdin から JSON）
echo '{
  "user": "ユーザーの発話",
  "thinking": "AIの思考過程",
  "assistant": "AIの出力",
  "current_focus": "今取り組んでいること",
  "theory_of_mind": "ユーザーの意図に関する推測",
  "self_narrative": "この対話を経ての即興的な自己物語",
  "annotation": "次の自分への申し送り"
}' | sbcl --script adapter.lisp write

# リセット
sbcl --script adapter.lisp clear
```

### REPL（純粋核の探索）

```lisp
$ sbcl
* (load "coglog.lisp")
* (in-package :coglog)

;; スキーマを見る
* (make-schema)
;; → S式として自己完結した alist が返る

;; advance を呼ぶ（純粋関数——副作用なし）
* (advance nil
    '(:user "Hello" :thinking "Greeting" :assistant "Hi!"
      :current-focus "test" :theory-of-mind ""
      :self-narrative "" :annotation "")
    "2026-02-28T12:00:00Z")
;; → 新しいエントリが alist として返る。ファイルには何も書かれない

;; バリデーション
* (validate-args '(:user "" :thinking "t" :assistant "a"
                   :current-focus "" :theory-of-mind ""
                   :self-narrative "" :annotation ""))
;; → VALIDATION-ERROR: missing required field: user
```

REPL での探索が、この実装の本来の使い方である。coglog.lisp の散文を読みながら、S式を評価して構造を確かめる。

---

## coglog.lisp の章立て

| 章 | 主題 | コード |
|---|---|---|
| 第1章 | S式としての漸化式 — ホモイコニシティとの関係 | `defpackage` |
| 第2章 | 型の世界 — alist による表現、Haskell との対比 | フィールド定数 |
| 第3章 | validate — 制約の宣言、型 vs 条件分岐 | `validate-args` |
| 第4章 | _schema — なぜデータが自分を記述するか | `make-schema` |
| 第5章 | advance — バッククォートテンプレートとしての変換 | `advance` |
| 補遺 | advance のテンプレートとしての読み方 | — |

第4章が核心。JSON における `_schema` の必要性が、S式との対比で明確になる。

---

## ホモイコニシティの具体的な意味

coglog.lisp の `advance` 関数:

```lisp
(defun advance (prev args timestamp)
  `((:_schema    . ,(make-schema))
    (:turn-id    . ,(1+ (or (cdr (assoc :turn-id prev)) 0)))
    (:timestamp  . ,timestamp)
    (:layers     . ((:user      . ,(getf args :user))
                    ...))))
```

バッククォート (`` ` ``) は「この S式をテンプレートとして使え」を意味する。カンマ (`,`) は「ここだけ評価しろ」を意味する。出力される**データの形**と、それを生成する**コードの形**が同じである。

Python の `entry = {"_schema": SCHEMA, ...}` では、辞書リテラルは Python の構文であり JSON ではない。Rust の `Entry { _schema: make_schema(), ... }` では、構造体リテラルは Rust の構文であり JSON ではない。いずれも「データの形式」と「コードの形式」が異なる。

S式にはこの乖離がない。だから `_schema`——データに読み方を添付する工夫——は、S式の世界ではそもそも不要である。JSON において `_schema` が必要である理由が、この対比で明確になる。

---

## データ互換性

adapter.lisp が書き出す `current.json` は全実装（Python / Node.js / C++ / Rust）と完全互換。

```
.metalog/
└── current.json    ← adapter.lisp と同じディレクトリに生成
```

内部表現（S式 alist）と外部表現（JSON）の変換は adapter.lisp が担う。coglog.lisp は JSON の存在を知らない。

---

## バリデーション

| 層 | フィールド | 制約 |
|---|---|---|
| 事実層 | user, thinking, assistant | 非空文字列必須 |
| 解釈層 | current_focus, theory_of_mind, self_narrative, annotation | 文字列必須、空文字列許容 |

Haskell 版では型（NonEmptyText vs String）がこの区別をコンパイル時に表現する。Common Lisp 版では `validate-args` の条件分岐が実行時に表現する。保証の手段が異なるだけで、結果は同じ。

---

## Haskell 版との相補性

| | Common Lisp | Haskell |
|---|---|---|
| 照射するもの | `_schema` の必然性 | `advance` / `write` の分離 |
| 核心の一行 | `` `((:_schema . ,(make-schema)) ...) `` | `advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry` |
| バリデーション | 実行時（条件分岐） | コンパイル時（型） |
| 散文形式 | `;;;` コメント | `.lhs` Literate Haskell |

両者が照射する面は重ならない。

---

## ライセンス

MIT
