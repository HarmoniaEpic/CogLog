# CogLog v0.9.1 — Recurrent Quine

自己書き換えプログラムとしての CogLog。

このファイルはプログラムであり、同時に自分自身の状態である。write コマンドは状態を遷移させ、このファイル自身を次世代として書き換える。

---

## 4つ組

```
Q_n = (*state*, *advance-source*, *affordance*, *self-source*)
```

| 成分 | 役割 | 生物学的対応 |
|---|---|---|
| `*state*` | 現在のエントリ | 表現型 |
| `*advance-source*` | 変換規則 | 構造遺伝子 |
| `*affordance*` | LLM への案内 | 調節配列 |
| `*self-source*` | 自己複製機構 | DNA ポリメラーゼ |

---

## 必要環境

SBCL。外部ライブラリ不要。

---

## 使い方

### 読み出し

```bash
sbcl --script recurrent-quine.lisp read
```

状態とアフォーダンスを S式で出力する。

### 書き込み

```bash
echo '(:user "Hello" :thinking "Greeting" :assistant "Hi!" :current-focus "test" :theory-of-mind "" :self-narrative "" :annotation "")' \
  | sbcl --script recurrent-quine.lisp write
```

入力は S式（plist）。JSON は使用しない。

このコマンドは `recurrent-quine.lisp` 自身を書き換える。実行前と実行後でファイルの内容が異なる。

### リセット

```bash
sbcl --script recurrent-quine.lisp clear
```

状態を nil にリセットし、ファイルを書き換える。

### REPL

```lisp
$ sbcl
* (load "recurrent-quine.lisp")
* *state*                    ; read に相当
* (write-self '(:user "Hello" :thinking "..." :assistant "Hi!"
                :current-focus "" :theory-of-mind ""
                :self-narrative "" :annotation ""))
;; → 状態遷移 + ファイル書き換え + 新しいエントリを返す
* *state*                    ; 更新済み
```

---

## 世代

初期ファイル（Q₀）は散文コメントを含む。write-self を実行すると Q₁ が生成される。Q₁ は Q₀ と同じ構造だが、`*state*` が更新され、散文コメントは最小限のヘッダーに圧縮されている。

```
Q₀ (手書き、散文あり)
 │ write-self
 ▼
Q₁ (*state* 更新、ヘッダー最小)
 │ write-self
 ▼
Q₂ (*state* 更新)
 │
 ...
```

各世代は完全なプログラムであり、単体で動作する。

---

## 進化機構

write-self は状態遷移に加えて、変換規則とアフォーダンスの更新を受け付ける。

```lisp
(write-self args)                          ; 状態のみ遷移
(write-self args new-advance-source)       ; 変換規則も更新
(write-self args nil new-affordance)       ; アフォーダンスも更新
```

通常の運用では状態のみが遷移する。変換規則とアフォーダンスの更新は許容されるが要求されない。

---

## current.json との関係

recurrent quine は current.json を生成しない。状態はファイル自身の中に S式として保持される。実用層（Python / Node.js / C++ / Rust）との JSON 互換性はない。

共有されるのは設計思想（DESIGN-v0.9.1.md）と漸化式の構造のみ。

---

## ライセンス

MIT
