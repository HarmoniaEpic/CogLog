# CogLog v0.9.1 Haskell 実装計画

## 変更の性質

**分析層の追加**（実用層の実装への変更なし）

---

## 位置づけ

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）    Common Lisp    ▶ Haskell ◀
             データ=コード    純粋/不純の分離
             _schemaの必然性   advance/writeの分離
                      │
         ┌────┬───────┼───────┬────┐
         ▼    ▼       ▼       ▼    ▼
実用（どう） Python  Node.js   C++  Rust
```

Haskell 版が照射するもの: **`advance` が純粋で `write` が不純であるという分離は、設計者の意図ではなく数学的な必然である**。型シグネチャがそれを証明する。

---

## 設計判断

### Literate Haskell (.lhs)

Core を `.lhs`（Literate Haskell）で記述する。

```
通常の .hs:  コードの中にコメントがある
.lhs:        散文の中にコードが埋まっている
```

GHC は `.lhs` ファイルを直接コンパイルできる。`>` で始まる行がコードとして扱われ、それ以外は散文（LaTeX または平文）として無視される。

```lhs
CogLog の核は漸化式 a_{n+1} = f(a_n, x_n) である。
advance は f に対応する純粋関数で、副作用を一切持たない。

> advance :: Entry -> WriteArgs -> UTCTime -> Entry
> advance prev args now = Entry { ... }
```

これにより DESIGN 文書の一部として読める Haskell コードが実現する。散文が主、コードが従。

### 2ファイル構成

```
CogLog.lhs      Literate Haskell — 散文 + 純粋核
Adapter.hs       current.json との接続（JSON手書き + ファイルI/O + CLI）
```

依存の方向は一方向: `Adapter → CogLog`。CogLog.lhs は Adapter の存在を知らない。

**CogLog.lhs は Adapter.hs なしでコンパイルが通る。** 純粋核が外部世界に依存しないことが、ファイルシステム上で保証される。

### 外部依存

**一切使用しない。** GHC 同梱ライブラリのみ。

| ライブラリ | 用途 | GHC 同梱 |
|---|---|---|
| `Data.Map.Strict` | JSON Object の表現 | ✓ (containers) |
| `Data.Time` | UTCTime, formatTime | ✓ (time) |
| `System.IO` | ファイル I/O | ✓ (base) |
| `Data.Char`, `Data.List` | JSON パーサー補助 | ✓ (base) |

aeson を使わない。分析層の目的は「aeson の derive マクロが何を自動生成しているか」を型で明示的に見せることにある。

### JSON の扱い

Adapter.hs に最小限の JSON シリアライザー/パーサーを手書きする。

- **シリアライズ**: `Entry -> String` の手書き実装。pretty-print（インデント2）
- **パース**: `String -> Either String Entry` の手書き実装。再帰下降
- **スコープ**: CogLog の current.json に出現する構造のみ対応すればよい

パーサーは汎用である必要がない。CogLog の JSON 構造は固定されているため、フィールド名を直接マッチングする特化パーサーで十分。推定60〜80行。

### MCP 層

**作らない。** 分析層の目的は「CogLog とは何か」の照射であり、JSON-RPC プロトコルハンドリングはその目的に寄与しない。

---

## CogLog.lhs の構成

散文の流れに沿ってコードが現れる。以下は章立て。

### 第1章: 漸化式

CogLog の数学的構造の説明。ここにはコードは少ない。

```
漸化式 a_{n+1} = f(a_n, x_n) の構造を説明する散文。

> module CogLog where
```

### 第2章: 型の世界

Entry, Layers, Schema, WriteArgs の型定義。型がバリデーション規則を表現する。

```
事実層は非空を型で表現する。

> newtype NonEmptyText = NonEmptyText String

解釈層は空を許容する。通常の String で十分。

> type Interpretation = String
```

ここで「NonEmptyText と String の型の違いが、事実層と解釈層のバリデーション規則の違いをコンパイル時に表現する」ことを散文で説明する。

### 第3章: advance — 純粋な核

```
advance は f に対応する。同じ入力に対して常に同じ出力を返す。
時刻すら外から注入される。

> advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry
```

### 第4章: validate — 制約の宣言

```
バリデーションは Entry の構築前に行われる。
NonEmptyText の構築関数がゲートキーパーとして機能する。

> mkNonEmptyText :: String -> Either ValidationError NonEmptyText
```

### 第5章: _schema — データの自己記述

```
_schema は make_schema 関数が生成する定数。
型が Schema であること自体が、これがメタデータであることを宣言する。

> schema :: Schema
```

---

## Adapter.hs の構成

```haskell
module Main where

import CogLog

-- JSON シリアライズ（手書き）
entryToJson :: Entry -> String

-- JSON パース（手書き、再帰下降）
parseEntry :: String -> Either String Entry

-- ファイル I/O
readMetalog :: FilePath -> IO (Maybe Entry)
writeMetalog :: FilePath -> Entry -> IO ()
clearMetalog :: FilePath -> IO ClearResult

-- CLI
main :: IO ()
-- read / write / clear の3コマンド
```

`main` の中で初めて IO モナドが現れる。CogLog.lhs のどこにも IO は存在しない。

---

## テスト計画

### CogLog.lhs の検証（純粋）

GHCi で対話的に検証する。

```
$ ghci CogLog.lhs
> let args = WriteArgs (mkNonEmptyText "hello") ...
> let entry = advance Nothing args someTime
> turnId entry
1
```

| # | テスト | 検証内容 |
|---|---|---|
| 1 | advance (Nothing) | 初回 write で turn_id = 1 |
| 2 | advance (Just prev) | turn_id がインクリメントされる |
| 3 | mkNonEmptyText "" | Left（バリデーションエラー） |
| 4 | mkNonEmptyText "x" | Right (NonEmptyText "x") |
| 5 | schema | version が "0.9.1" |
| 6 | advance + 日本語 | UTF-8 文字列が保持される |

### Adapter.hs の検証（統合）

```
$ runghc Adapter.hs read
$ echo '{...}' | runghc Adapter.hs write
$ runghc Adapter.hs clear
```

| # | テスト | 期待結果 |
|---|---|---|
| 7 | read (空) | (no metalog found) |
| 8 | write → read | エントリが一致 |
| 9 | clear → read | (no metalog found) |
| 10 | Python 互換 | Haskell write → Python read |
| 11 | JSON round-trip | write → ファイル読み出し → parse → 元と一致 |

---

## 規模見積もり

| セクション | 行数 |
|---|---|
| CogLog.lhs: 散文 | ~80行 |
| CogLog.lhs: コード（型定義, advance, validate, schema） | ~80行 |
| Adapter.hs: JSON シリアライズ | ~40行 |
| Adapter.hs: JSON パース | ~70行 |
| Adapter.hs: ファイル I/O + CLI | ~50行 |
| **合計** | **~320行** |

CogLog.lhs は散文とコードが約1:1。散文がコードを解説するのではなく、散文の論旨をコードが例証する。

---

## 変更なし

実用層の全ファイルに変更はない。

Haskell 版は DESIGN 文書の **実行可能な注釈** である。

---

## バージョニング

CogLog のバージョンは **v0.9.1 のまま**。
