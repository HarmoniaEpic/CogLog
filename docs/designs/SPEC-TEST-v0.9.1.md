# CogLog v0.9.1 テスト仕様

DESIGN-v0.9.1.md および SPEC-path-resolution-v0.9.1.md から導出。実装コードは参照していない。

各テストケースの根拠として、DESIGNの該当仕様を引用する。

---

## 1. 初期状態

**根拠**: 「初期条件（$a_0$）— セッション開始時の空状態」

| # | テストケース | 期待結果 |
|---|---|---|
| 1.1 | 何も write していない状態で read | null / None / nil を返す |
| 1.2 | 何も write していない状態で clear | 「既に空」を示す結果を返す。エラーではない |

---

## 2. write → read ラウンドトリップ

**根拠**: 「事実層: 何があったか。自他混合の三層記録」「解釈層: それをどう読んだか」

| # | テストケース | 期待結果 |
|---|---|---|
| 2.1 | 全7フィールドに非空文字列を渡して write → read | 全フィールドが write 時の値と一致する |
| 2.2 | read した結果に `_schema` が含まれる | `_schema.version` = `"0.9.1"` |
| 2.3 | read した結果に `turn_id` が含まれる | 数値型。初回 write の場合は 1 |
| 2.4 | read した結果に `timestamp` が含まれる | ISO 8601 形式の文字列 |
| 2.5 | read した結果の `layers` が user, thinking, assistant を含む | 3フィールドとも write 時の値と一致 |
| 2.6 | read した結果が current_focus, theory_of_mind, self_narrative, annotation を含む | 4フィールドとも write 時の値と一致 |

---

## 3. バリデーション — 事実層

**根拠**: 「事実層は『何があったか』の記録であり、空であることは事実の欠落を意味するため、非空を要求する」

| # | テストケース | 期待結果 |
|---|---|---|
| 3.1 | user を空文字列にして write | バリデーションエラー |
| 3.2 | thinking を空文字列にして write | バリデーションエラー |
| 3.3 | assistant を空文字列にして write | バリデーションエラー |
| 3.4 | user を省略（フィールド自体がない）して write | バリデーションエラー |
| 3.5 | thinking を省略して write | バリデーションエラー |
| 3.6 | assistant を省略して write | バリデーションエラー |

---

## 4. バリデーション — 解釈層

**根拠**: 「意図的に空にする——『今回は書くべきことがない』——という判断も、一つの有効な判断である。空文字列を許容することで、書かないという選択を排除しない」

| # | テストケース | 期待結果 |
|---|---|---|
| 4.1 | current_focus を空文字列にして write | 成功。read で空文字列が返る |
| 4.2 | theory_of_mind を空文字列にして write | 成功 |
| 4.3 | self_narrative を空文字列にして write | 成功 |
| 4.4 | annotation を空文字列にして write | 成功 |
| 4.5 | 解釈層4フィールド全てを空文字列にして write | 成功 |
| 4.6 | 解釈層フィールドを省略して write | バリデーションエラー（「文字列必須」制約の違反） |

---

## 5. バリデーション — 型チェック

**根拠**: フィールド定義表の「型」列。全フィールドが string 型。

| # | テストケース | 期待結果 |
|---|---|---|
| 5.1 | user に数値を渡して write | バリデーションエラーまたはパースエラー |
| 5.2 | thinking に配列を渡して write | 同上 |
| 5.3 | current_focus に null を渡して write | 同上 |

注: 言語によって型チェックの表層が異なる（静的型付け言語ではコンパイル時に弾かれる場合がある）。CLI 経由の JSON 入力で検証する。

---

## 6. 窓サイズ1 — 上書き

**根拠**: 「窓サイズ1ターン固定」「履歴保持なし（上書き）」「前の状態は上書きされ、復元できない。この不可逆性が時間の矢を構成する」

| # | テストケース | 期待結果 |
|---|---|---|
| 6.1 | write A → write B → read | B のみが返る。A は消失している |
| 6.2 | write A → write B → read で A の内容が含まれない | layers, 解釈層ともに B の値のみ |

---

## 7. turn_id の単調増加

**根拠**: 「単調増加するターン番号。セッション内で一意」

| # | テストケース | 期待結果 |
|---|---|---|
| 7.1 | 初回 write → read | turn_id = 1 |
| 7.2 | write → write → read | turn_id = 2 |
| 7.3 | 3回 write → read | turn_id = 3 |

---

## 8. clear

**根拠**: 「窓サイズ1の設計意図を保全する」+ CLI の「clear — reset coglog」

| # | テストケース | 期待結果 |
|---|---|---|
| 8.1 | write → clear → read | null / None / nil（初期状態に戻る） |
| 8.2 | clear の戻り値 | 「削除した」ことを示す |
| 8.3 | clear → clear（二重 clear） | エラーではない。「既に空」を示す |
| 8.4 | clear → write → read | turn_id = 1（漸化式の初期条件 $a_0$ に戻る） |

---

## 9. _schema の自動付与

**根拠**: 「`_schema` はツールの内部定数から自動生成される。ユーザーが渡す入力には含まれず、バリデーションの対象にもならない」「write時に自動付与」

| # | テストケース | 期待結果 |
|---|---|---|
| 9.1 | write 入力に _schema を含めない → read | _schema が存在し、version = "0.9.1" |
| 9.2 | _schema.fact_layer が user, thinking, assistant の説明を含む | 各値が "non-empty string required" で始まる |
| 9.3 | _schema.interpretation_layer が 4フィールドの説明を含む | 各値が "string required, empty OK" で始まる |
| 9.4 | _schema.constraints.window_size | "1 turn (overwritten each write)" |
| 9.5 | _schema.constraints.interpretation_empty | "choosing not to write is itself a metacognitive act" |

---

## 10. timestamp

**根拠**: フィールド定義の「string (ISO8601)」

| # | テストケース | 期待結果 |
|---|---|---|
| 10.1 | write → read で timestamp を取得 | ISO 8601 形式に合致（YYYY-MM-DDThh:mm:ssZ 等） |
| 10.2 | write A → (時間経過) → write B → read | B の timestamp が A の timestamp 以降 |

---

## 11. パス解決

**根拠**: SPEC-path-resolution-v0.9.1.md

### 11a. 共通仕様（全言語）

| # | テストケース | 期待結果 |
|---|---|---|
| 11.1 | 明示的指定で write → read | 指定ディレクトリの current.json に書き込まれる |
| 11.2 | 存在しないディレクトリを明示的指定して write | ディレクトリが自動作成され、write が成功する |
| 11.3 | read / clear はディレクトリを作成しない | 存在しないディレクトリを指定して read → ディレクトリが作成されていない |
| 11.4 | COGLOG_DIR 環境変数を設定して write → read | COGLOG_DIR のパスに current.json が生成される |
| 11.5 | 明示的指定と COGLOG_DIR を同時に設定して write | 明示的指定が優先される |
| 11.6 | COGLOG_DIR も明示的指定も未設定で write | $HOME/.coglog/current.json に書き込まれる |
| 11.7 | データファイル名 | 常に `current.json`。パス解決の結果に関わらず固定 |

### 11b. CLI 引数（Bash 以外）

| # | テストケース | 期待結果 |
|---|---|---|
| 11.8 | `coglog-cli --coglog-dir /tmp/test read` | /tmp/test/current.json を参照する |
| 11.9 | `coglog-cli --coglog-dir /tmp/test write` → `coglog-cli --coglog-dir /tmp/test read` | write した内容が read で返る |

### 11c. MCP サーバー引数

| # | テストケース | 期待結果 |
|---|---|---|
| 11.10 | `coglog-mcp --coglog-dir /tmp/test` 起動 → coglog_write → coglog_read | /tmp/test/current.json に書き込まれる |

### 11d. Bash 固有

| # | テストケース | 期待結果 |
|---|---|---|
| 11.11 | `COGLOG_DIR=/tmp/test bash coglog-cli.sh write` | /tmp/test/current.json に書き込まれる |
| 11.12 | `--coglog-dir` 引数を渡す | 無視される（Bash は環境変数のみ） |

### 11e. COGLOG_DIR の空文字列

| # | テストケース | 期待結果 |
|---|---|---|
| 11.13 | `COGLOG_DIR=""` を設定して write | 空文字列は「未設定」と同等。$HOME/.coglog にフォールバックする |

### 11f. フォールバック

| # | テストケース | 期待結果 |
|---|---|---|
| 11.14 | COGLOG_DIR 未設定 + HOME 未設定（取得不能）で write | ./.coglog/current.json に書き込まれる |

注: 11.14 は Bash と Python (Skill版) では該当しない（フォールバックを持たない）。テスト対象外とする。

### 11g. 言語固有のホームディレクトリ解決

**根拠**: SPEC-path-resolution-v0.9.1.md「言語標準様式が優先される場合」

以下は段階3（ホームディレクトリ）の解決方法が言語標準に従う場合の検証。結果のパスが `$HOME/.coglog/current.json` 相当であることを確認する。

| # | 言語 | テストケース | 検証ポイント |
|---|---|---|---|
| 11.15 | Java | COGLOG_DIR 未設定で write | `System.getProperty("user.home")` + `/.coglog` に書き込まれる（`$HOME` 環境変数ではなく JVM プロパティ） |
| 11.16 | C# | COGLOG_DIR 未設定で write | `Environment.GetFolderPath(UserProfile)` + `/.coglog` に書き込まれる |
| 11.17 | Haskell | COGLOG_DIR 未設定 + HOME 未設定で write | `getHomeDirectory` が例外 → `getCurrentDirectory` + `/.coglog` にフォールバック |

注: 多くの環境で `user.home` = `$HOME`、`UserProfile` = `$HOME` であるため、通常は 11.6 と同じ結果になる。差異が生じるのは HOME 環境変数が JVM/CLR の認識するホームと異なる場合のみ。

---

## 12. クロス互換性

**根拠**: 「全11言語のデータ形式は同一。任意の言語で write したデータを任意の言語で read できる」

| # | テストケース | 期待結果 |
|---|---|---|
| 12.1 | 言語 X で write → 言語 Y で read | 全フィールドが一致する |
| 12.2 | 言語 Y で write → 言語 X で read | 全フィールドが一致する（対称性） |

PLAN の検証チェックリストに以下の代表的な組み合わせが定義済み:

```
Rust write    → Python read
Node.js write → Go read
Go write      → Ruby read
Ruby write    → Java read
Java write    → C# read
C# write      → Rust read
Python write  → Haskell read
Haskell write → CL read
CL write      → Node.js read
C++ write     → Go read
Bash write    → Python read
C++ write     → Bash read
```

---

## 13. MCP プロトコル

**根拠**: DESIGN「移植性」節の「MCPサーバー: read / write / clear の3ツール公開」+ PLAN「MCP プロトコル: JSON-RPC 2.0 over stdio, tools 3種」

| # | テストケース | 期待結果 |
|---|---|---|
| 13.1 | initialize ハンドシェイク | protocolVersion, capabilities.tools, serverInfo を含む応答 |
| 13.2 | tools/list | coglog_read, coglog_write, coglog_clear の3ツールが列挙される |
| 13.3 | tools/call coglog_read（初期状態） | "(no coglog found)" |
| 13.4 | tools/call coglog_write → coglog_read | write した内容が read で返る |
| 13.5 | tools/call coglog_clear → coglog_read | "(no coglog found)" |
| 13.6 | tools/call coglog_write に不正な引数 | isError: true を含む応答 |

---

## 14. CLI インターフェース

**根拠**: DESIGN「移植性」節 + PLAN「CLI インターフェース（read / write / clear）」

| # | テストケース | 期待結果 |
|---|---|---|
| 14.1 | `coglog-cli read`（初期状態） | "(no coglog found)" を stdout に出力 |
| 14.2 | JSON を stdin に渡して `coglog-cli write` | "coglog: turn N written" を stdout に出力 |
| 14.3 | write 後に `coglog-cli read` | JSON が stdout に出力される |
| 14.4 | `coglog-cli clear` | "coglog: cleared" を stdout に出力 |
| 14.5 | 不正な JSON を stdin に渡して `coglog-cli write` | エラーメッセージを stderr に出力。終了コード非 0 |
| 14.6 | 引数なしで `coglog-cli` | usage を出力 |

---

## 恒真命題チェックリスト

以下のテストは恒真命題（トートロジー）であり、含めてはならない:

- ❌ 「write した後に read すると何かが返る」（何が返るかを検証しなければ無意味）
- ❌ 「_schema が存在する」（中身の検証なしでは意味がない → 9.1-9.5 で中身を検証）
- ❌ 「バリデーションエラーが発生する」（どの入力でどのエラーかを特定しなければ無意味 → 3.1-5.3 で特定）
- ❌ 「JSON として valid である」（書き込み側が JSON ライブラリを使っている時点で自明）

---

## 導出元の仕様一覧

| テスト群 | DESIGN の該当箇所 |
|---|---|
| 1. 初期状態 | 「初期条件（$a_0$）— セッション開始時の空状態」 |
| 2. ラウンドトリップ | データ構造定義、フィールド定義表 |
| 3. 事実層バリデーション | 「非空を要求する」、バリデーション表の「非空チェック ✓」 |
| 4. 解釈層バリデーション | 「空文字列を許容する」「書かないという選択を排除しない」 |
| 5. 型チェック | フィールド定義表の「型」列 |
| 6. 窓サイズ1 | 「窓サイズ1ターン固定」「履歴保持なし（上書き）」「不可逆性」 |
| 7. turn_id | 「単調増加するターン番号」 |
| 8. clear | 漸化式の初期条件への復帰 |
| 9. _schema | 「ツールの内部定数から自動生成」「バリデーションの対象にもならない」 |
| 10. timestamp | フィールド定義の「ISO8601」 |
| 11. パス解決 | SPEC-path-resolution-v0.9.1.md（共通仕様の4段階 + 言語別指針 + ホームディレクトリ解決の言語差異） |
| 12. クロス互換性 | 「全11言語のデータ形式は同一」 |
| 13. MCP | 「read / write / clear の3ツール公開」「JSON-RPC 2.0 over stdio」 |
| 14. CLI | 「移植性」節の CLI 行 |
