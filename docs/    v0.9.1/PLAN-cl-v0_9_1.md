# CogLog v0.9.1 Common Lisp 実装計画

## 変更の性質

**分析層の追加**（実用層の実装への変更なし）

---

## 位置づけ

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）  ▶ Common Lisp ◀    Haskell
             データ=コード    純粋/不純の分離
             _schemaの必然性   advance/writeの分離
                      │
         ┌────┬───────┼───────┬────┐
         ▼    ▼       ▼       ▼    ▼
実用（どう） Python  Node.js   C++  Rust
```

Common Lisp 版が照射するもの: **`_schema` がデータに内在する設計は、ホモイコニシティの世界では自明な帰結である**。S式においてデータが自分の読み方を持つことは驚きではなく前提である。

---

## 設計判断

### コメントリッチな .lisp

Haskell 版が Literate Haskell（`.lhs`）で散文とコードを融合するのに対し、Common Lisp 版はコメントで散文を埋め込む。

理由: Common Lisp に Literate Programming の標準形式がない。TeX 連携ツール（Literate Lisp 等）は存在するが処理系依存であり、SBCL 単体で `load` できることを優先する。

代わりに、以下の規約でコメントを散文として扱う:

```lisp
;;;; ═══════════════════════════════════════
;;;; 第1章: S式としての漸化式
;;;; ═══════════════════════════════════════

;;; CogLog の核は漸化式 a_{n+1} = f(a_n, x_n) である。
;;; Lisp の世界では、この f はデータ変換として自然に表現される。
;;; なぜなら S式は同時にデータでありコードだからだ。

(defun advance (prev args now)
  ...)
```

`;;;;` が章見出し、`;;;` が散文、`;` がインラインコメント。Common Lisp のコメント慣行に準拠している。

### 2ファイル構成

```
coglog.lisp       コメントリッチな純粋核 — S式で自己完結
adapter.lisp      current.json との接続（JSON変換 + ファイルI/O + CLI）
```

依存の方向は一方向: `adapter → coglog`。coglog.lisp は adapter の存在を知らない。

**coglog.lisp は adapter.lisp なしで SBCL にロードできる。** S式の世界で閉じた核が、JSON やファイルシステムに依存しないことが保証される。

### 外部依存

**一切使用しない。** SBCL 同梱機能のみ。Quicklisp なし。

Common Lisp の標準には JSON がない。しかし CogLog の JSON は構造が固定されているため、`format` によるシリアライズと手書きの再帰下降パーサーで十分に対応できる。

### ホモイコニシティと _schema

ここが Common Lisp 版の存在理由の核心である。

実用層の5実装では、`_schema` は「JSON オブジェクトの中に埋め込まれた説明文」である。それ自体はデータであり、コードではない。読むのは LLM であって処理系ではない。

Common Lisp では事情が異なる。S式による Entry は:

```lisp
`((_schema . ,(make-schema))
  (turn-id . ,(1+ (or (getf prev :turn-id) 0)))
  ...)
```

バッククォートとカンマにより、**Entry を構築するコード自体が Entry のテンプレート**になる。`_schema` の値は `make-schema` 関数の戻り値——これもまた S式——であり、データを生成するコードとそのコードが生成するデータの間に構造的な区別がない。

JSON の世界では `_schema` は「データが自分の読み方を携える」設計上の工夫だった。S式の世界ではそれは工夫ではなく**言語の性質そのもの**である。

この観察を coglog.lisp の散文で展開する。

### S式内部表現と JSON 出力

coglog.lisp 内部のデータ表現は S式（alist / plist）で統一する。JSON は adapter.lisp で初めて登場する。

```
coglog.lisp:   ((:user . "Hello") (:thinking . "...") ...)
                         ↓ adapter.lisp が変換
adapter.lisp:  {"user": "Hello", "thinking": "...", ...}
```

coglog.lisp の中に JSON 文字列は一切現れない。核がデータ交換形式に依存しないことが構造的に保証される。

### MCP 層

**作らない。** Haskell 版と同じ理由。

---

## coglog.lisp の構成

散文（コメント）の流れに沿ってコードが現れる。

### 第1章: S式としての漸化式

CogLog の数学的構造の説明。ホモイコニシティとの関係。

```lisp
;;; CogLog の漸化式は a_{n+1} = f(a_n, x_n) である。
;;; Common Lisp において、この f は alist → alist の変換として記述される。
;;; 入力も出力も同じ S式であり、「データの形式」と「コードの形式」の区別がない。

(defpackage :coglog (:use :cl) (:export ...))
(in-package :coglog)
```

### 第2章: 型の世界

CogLog のデータ型を defstruct で定義する。

```lisp
;;; Common Lisp の defstruct は Haskell の data 型に対応するが、
;;; 決定的に異なるのは、構造体もまた S式で印字・読み取り可能なことだ。
;;; #S(entry :turn-id 1 :user "hello") は、データであり同時にリテラルである。

(defstruct entry ...)
```

ただし、JSON との相互変換の容易さのため、内部表現は defstruct ではなく alist を使う可能性がある。この選択は実装時に確定する。

### 第3章: advance — 変換

```lisp
;;; advance は漸化式の f に対応する。
;;; バッククォートテンプレートにより、出力の構造が入力と同形であることが
;;; コードの見た目から直接読み取れる。

(defun advance (prev args now)
  `((:_schema . ,(make-schema))
    (:turn-id . ,(1+ (or (cdr (assoc :turn-id prev)) 0)))
    (:timestamp . ,now)
    ...))
```

### 第4章: validate — 制約

```lisp
;;; バリデーションは「事実層の非空」と「解釈層の存在」を検査する。
;;; Haskell では型（NonEmptyText vs String）がこの区別をコンパイル時に表現した。
;;; Common Lisp では実行時の条件分岐として表現する。
;;; 型安全のコストを払わない代わりに、制約の記述が直接的で読みやすい。

(defun validate-args (args)
  (dolist (key '(:user :thinking :assistant))
    (let ((val (getf args key)))
      (when (or (null val) (string= val ""))
        (error "missing required field: ~a" key)))))
```

### 第5章: _schema — なぜデータが自分を記述するか

この章が coglog.lisp の核心。

```lisp
;;; JSON の世界で _schema は「データが自分の読み方を携える」工夫であった。
;;; S式の世界ではそれは工夫ではない。S式は本質的に自己記述的である。
;;;
;;; (make-schema) が返す値は alist であり、それ自体が Lisp のリーダーで
;;; 読み込み可能なデータである。データを生成するコードと、そのコードが
;;; 生成するデータに、構造的な区別がない。
;;;
;;; ギブソンのアフォーダンスは「環境が行為者に行為の可能性を提供する」ことだった。
;;; S式は行為者（Lisp リーダー）に対して、読み取り・評価・変換の可能性を
;;; 構文レベルで提供している。_schema は JSON にこの性質を部分的に持ち込む試みである。

(defun make-schema ()
  '((:version . "0.9.1")
    (:fact-layer
     (:user . "non-empty string required — user's original utterance")
     (:thinking . "non-empty string required — AI's full thinking process")
     (:assistant . "non-empty string required — AI's original output"))
    ...))
```

---

## adapter.lisp の構成

```lisp
(load "coglog.lisp")

;; ── JSON シリアライズ ──
;; alist → JSON 文字列（pretty-print）
(defun entry-to-json (entry stream) ...)

;; ── JSON パース ──
;; JSON 文字列 → alist
;; 再帰下降。CogLog の JSON 構造に特化。
(defun parse-json (string) ...)

;; ── ファイル I/O ──
(defun read-metalog (path) ...)
(defun write-metalog (path entry) ...)
(defun clear-metalog (path) ...)

;; ── CLI ──
(defun main ()
  (let ((cmd (second sb-ext:*posix-argv*)))
    (cond
      ((string= cmd "read") ...)
      ((string= cmd "write") ...)
      ((string= cmd "clear") ...)
      (t (usage)))))

(main)
```

`sb-ext:*posix-argv*` は SBCL 固有。移植性よりも「SBCL 単体で動く」を優先する。

---

## テスト計画

### coglog.lisp の検証（REPL）

```
$ sbcl
* (load "coglog.lisp")
* (in-package :coglog)
* (validate-args '(:user "hello" :thinking "t" :assistant "a" ...))
NIL  ; エラーなし
* (validate-args '(:user "" :thinking "t" :assistant "a" ...))
; ERROR: missing required field: USER
```

| # | テスト | 検証内容 |
|---|---|---|
| 1 | advance (nil) | 初回 turn-id = 1 |
| 2 | advance (prev) | turn-id がインクリメントされる |
| 3 | validate-args (空 user) | エラー |
| 4 | validate-args (空 current-focus) | エラーなし（空許容） |
| 5 | make-schema | version が "0.9.1" |
| 6 | advance + 日本語 | UTF-8 文字列が保持される |

### adapter.lisp の検証（CLI）

```
$ sbcl --script adapter.lisp read
$ echo '{...}' | sbcl --script adapter.lisp write
$ sbcl --script adapter.lisp clear
```

| # | テスト | 期待結果 |
|---|---|---|
| 7 | read (空) | (no metalog found) |
| 8 | write → read | エントリが一致 |
| 9 | clear → read | (no metalog found) |
| 10 | Python 互換 | CL write → Python read |
| 11 | JSON round-trip | write → ファイル → parse → 元と一致 |

---

## 規模見積もり

| セクション | 行数 |
|---|---|
| coglog.lisp: 散文（コメント） | ~80行 |
| coglog.lisp: コード（defstruct/alist, advance, validate, schema） | ~60行 |
| adapter.lisp: JSON シリアライズ | ~40行 |
| adapter.lisp: JSON パース | ~70行 |
| adapter.lisp: ファイル I/O + CLI | ~40行 |
| **合計** | **~290行** |

coglog.lisp の散文対コード比は約4:3。Haskell 版（約1:1）より散文の比率が高い。ホモイコニシティの説明に散文を要するため。

---

## Haskell 版との相補性

| 観点 | Haskell (CogLog.lhs) | Common Lisp (coglog.lisp) |
|---|---|---|
| 中心主題 | advance/write の分離（純粋/不純） | _schema の必然性（データ=コード） |
| 型の役割 | 制約として機能（NonEmptyText vs String） | 記述として機能（alist のキー）|
| バリデーション | コンパイル時（型） | 実行時（条件分岐） |
| JSON の位置 | Adapter が Entry → String に変換 | Adapter が alist → String に変換 |
| 散文の形式 | Literate Haskell (.lhs) | コメント (;;;) |
| 核心の一行 | `advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry` | `` `((:_schema . ,(make-schema)) ...) `` |

両者が照射する面は重ならない。Haskell は「何が純粋で何が不純か」を示し、Common Lisp は「なぜデータが自分を記述すべきか」を示す。

---

## 変更なし

実用層の全ファイルに変更はない。

Common Lisp 版は DESIGN 文書の **ホモイコニシティからの注釈** である。

---

## バージョニング

CogLog のバージョンは **v0.9.1 のまま**。
