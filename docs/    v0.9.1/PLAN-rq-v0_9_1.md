# CogLog v0.9.1 Recurrent Quine 実装計画

## 変更の性質

**分析層の実験的追加**（実用層・分析層（CL/HS）への変更なし）

---

## 位置づけ

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）    Common Lisp      Haskell
             データ=コード    純粋/不純の分離
                  │
                  ▼
実験      ▶ Recurrent Quine ◀
          自己書き換えコード
          advance のデータ内在
          進化機構
```

Recurrent Quine が照射するもの: **`_schema` がデータに読み方を内在させるなら、`advance` もデータに内在させられる。プログラムが自分の次世代を書き出す。**

---

## 数学的構造

### Quine との比較

```
quine:            Q → Q               自己複製（恒等関数）
recurrent quine:  Q_n → Q_{n+1}       自己遷移（advance 適用）
```

### 4つ組

```
Q_n = (*state*, *advance-source*, *affordance*, *self-source*)

       表現型      構造遺伝子        調節配列        複製機構
```

| 成分 | 役割 | 変異頻度 | 生物学的対応 |
|---|---|---|---|
| `*state*` | 現在のエントリ（alist） | 毎世代 | 表現型 |
| `*advance-source*` | 変換規則（quoted defun） | 稀 | 構造遺伝子 |
| `*affordance*` | LLM へのアフォーダンス | 稀 | 調節配列 |
| `*self-source*` | 自己複製機構（quoted progn） | 事実上不変 | DNA ポリメラーゼ |

### 遷移規則

```
write-self(args, new-advance?, new-affordance?):

  *state*_{n+1}          = advance(*state*_n, args, timestamp)
  *advance-source*_{n+1} = new-advance ∨ *advance-source*_n
  *affordance*_{n+1}     = new-affordance ∨ *affordance*_n
  *self-source*_{n+1}    = *self-source*_n
```

---

## 設計判断

### 単一ファイル自己書き換え

```
recurrent-quine.lisp
  ├── *state*            （世代ごとに変わる）
  ├── *advance-source*   （変わりうるが慎重に）
  ├── *affordance*       （変わりうる）
  ├── *self-source*      （事実上不変）
  ├── (eval *advance-source*)
  └── (eval *self-source*)
```

coglog.lisp / adapter.lisp の2ファイル構成とは異なり、単一ファイルに全てを内在させる。write-self がこのファイル自身を書き換える。

### S式 I/O（JSON なし）

入力も出力も状態も変換規則も全て S式。JSON は一切経由しない。

```
入力:  (:user "Hello" :thinking "..." :assistant "Hi!" ...)
状態:  ((:_schema . (...)) (:turn-id . 1) ...)
出力:  S式 pretty-print
```

LLM は S式を生成できる。CLI ツールとして LLM のツール実行環境から呼び出す。

### バッククォート回避

*advance-source* と *self-source* は quoted form として保持され、print/read で世代をまたいで複製される。バッククォート（`` ` ``）は処理系固有の内部表現に展開されるため、round-trip を保証できない。

```lisp
;; ✗ バッククォート — print 後の形式が処理系依存
`((:_schema . ,*affordance*) (:turn-id . ,turn-id) ...)

;; ✓ list/cons — 標準関数のみ。round-trip 保証
(list (cons :_schema *affordance*) (cons :turn-id turn-id) ...)
```

これは quine 機構の制約であり、coglog.lisp のバッククォートテンプレート（ホモイコニシティの例示）とは設計上の要請が異なる。

### *affordance* = _schema

*affordance* は `_schema` の S式版。advance が生成するエントリの `:_schema` に *affordance* がそのまま入る。

```lisp
(cons :_schema *affordance*)
```

JSON 版で「データが自分の読み方を携える」ために必要だった _schema が、S式の世界でも LLM へのアフォーダンスとして機能する。

### read 出力

read コマンドは *state* と *affordance* の両方を出力する。

```
;;; state
((:_schema . (...)) (:turn-id . 1) ...)

;;; affordance
((:version . "0.9.1") ...)
```

*state* が nil の場合でも *affordance* は出力する。LLM が「何をどう書くか」を常に参照できるようにする。

### 進化機構

write-self はオプション引数で変換規則とアフォーダンスの更新を受け付ける。

```lisp
(write-self args)                          ; 状態のみ遷移
(write-self args new-advance-source)       ; 変換規則も更新
(write-self args nil new-affordance)       ; アフォーダンスも更新
```

更新は許容されるが要求されない。

---

## テスト計画

### 基本操作

| # | テスト | 検証内容 |
|---|---|---|
| 1 | read (初期) | (no metalog found) + affordance |
| 2 | write | turn 1 written |
| 3 | read (after write) | state + affordance |
| 4 | write (2回目) | turn 2, turn_id increment |
| 5 | clear | cleared, state = nil |
| 6 | validation (empty user) | error |
| 7 | UTF-8 日本語 | 保持される |

### 世代遷移（quine 検証）

| # | テスト | 検証内容 |
|---|---|---|
| 8 | Q₀ write → Q₁ | ファイルが書き換わっている |
| 9 | Q₁ load → read | state が Q₀ の write 結果と一致 |
| 10 | Q₁ write → Q₂ | turn_id = 2 |
| 11 | Q₂ load → read | state が Q₁ の write 結果と一致 |
| 12 | Q₂ ファイルが valid Lisp | sbcl --script で構文エラーなし |

### 互換性

recurrent quine は独自の S式形式を使い、current.json を生成しない。JSON 互換性テストは対象外。

---

## 規模見積もり

| セクション | 行数 |
|---|---|
| 散文（コメント） | ~40行 |
| *state* | 1行 |
| *advance-source* | ~40行 |
| *affordance* | ~20行 |
| *self-source* | ~100行 |
| eval + 構造 | ~10行 |
| **合計** | **~210行** |

Q₁ 以降は散文コメント（~40行）がヘッダー数行に圧縮されるため、約170行になる。これは世代を経た簡略化であり、設計通り。

---

## 変更なし

以下のファイルに変更はない:

- coglog.lisp（CL 純粋核）
- adapter.lisp（CL アダプター）
- 実用層全ファイル（Python / Node.js / C++ / Rust）

---

## バージョニング

CogLog のバージョンは **v0.9.1 のまま**。
