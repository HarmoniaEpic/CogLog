# CogLog v0.9.1 問題報告

DESIGN-v0.9.1.md、SPEC-path-resolution-v0.9.1.md、SPEC-TEST-v0.9.1.md、PLAN-TEST-IMPL-v0.9.1.md、PLAN-release-v0.9.1.md、および全11言語の実装コードを対照して導出。

**作成日:** 2026-03-07

---

## 要請と準拠状況の対照表

### R1. バリデーション — 事実層は非空必須

**根拠:**

> 事実層は「何があったか」の記録であり、空であることは事実の欠落を意味するため、非空を要求する。
> — DESIGN-v0.9.1.md L155

> | 3.1 | user を空文字列にして write | バリデーションエラー |
> | 3.4 | user を省略（フィールド自体がない）して write | バリデーションエラー |
> — SPEC-TEST-v0.9.1.md L41-46

**要件:** `user`, `thinking`, `assistant` は非空文字列必須。空文字列もフィールド欠落も拒否する。

| 言語 | 空文字列の拒否 | フィールド欠落の拒否 | 判定 |
|------|:---:|:---:|:---:|
| Python | `len(val) == 0` で拒否 | `isinstance` チェック | 準拠 |
| Node.js | `val.length === 0` で拒否 | `typeof` チェック | 準拠 |
| Rust | `.is_empty()` で拒否 | serde が欠落時にエラー | 準拠 |
| Go | `a.User == ""` で拒否 | `json.Unmarshal` が `""` を代入 → 拒否 | 準拠※ |
| Java | `val.isEmpty()` で拒否 | `val == null` チェック | 準拠 |
| C# | `IsNullOrEmpty` で拒否 | `TryGetValue` チェック | 準拠 |
| Ruby | `!val.empty?` で拒否 | `is_a?(String)` チェック | 準拠 |
| Haskell | `mkNonEmptyText ""` → Left | `jStr` が欠落時にエラー | 準拠 |
| C++ | `.empty()` で拒否 | JSON パース時に検出 | 準拠 |
| Common Lisp | `(plusp (length val))` | `(getf args key)` → nil | 準拠 |
| Bash | jq `length == 0` で拒否 | jq `type != "string"` | 準拠 |

※ Go では `json.Unmarshal` が欠落フィールドにゼロ値 `""` を代入した後、`Validate()` が `a.User == ""` で拒否する。結果的に正しく動作するが、エラーメッセージが「フィールド欠落」ではなく「空文字列」として報告される（テスト 3.4-3.6 のエラー原因の表現が他言語と異なる）。

**違反: なし（機能的には全言語準拠）。**

---

### R2. バリデーション — 解釈層は文字列必須・空許容、フィールド欠落は拒否

**根拠:**

> 意図的に空にする——「今回は書くべきことがない」——という判断も、一つの有効な判断である。空文字列を許容することで、書かないという選択を排除しない。
> — DESIGN-v0.9.1.md L157

> | 4.1 | current_focus を空文字列にして write | 成功。read で空文字列が返る |
> | 4.6 | 解釈層フィールドを省略して write | バリデーションエラー（「文字列必須」制約の違反） |
> — SPEC-TEST-v0.9.1.md L56-61

**要件:** `current_focus`, `theory_of_mind`, `self_narrative`, `annotation` は文字列必須。空文字列は許容する。フィールド自体の欠落は拒否する。

| 言語 | 空文字列の許容 | フィールド欠落の拒否 | 判定 |
|------|:---:|:---:|:---:|
| Python | OK | `isinstance(val, str)` → not str なら拒否 | 準拠 |
| Node.js | OK | `typeof val !== 'string'` → 拒否 | 準拠 |
| Rust | OK（型が String） | serde が欠落時にエラー | 準拠 |
| **Go** | OK | **`json.Unmarshal` が欠落を `""` にする → 暗黙的に通過** | **違反** |
| Java | OK | `val == null` → 拒否 | 準拠 |
| C# | OK | `!ContainsKey` → 拒否 | 準拠 |
| Ruby | OK | `!is_a?(String)` → 拒否 | 準拠 |
| Haskell | OK（型が String） | `jStr` が欠落時にエラー | 準拠 |
| C++ | OK（型が string） | JSON パース時に検出 | 準拠 |
| Common Lisp | OK | `(stringp val)` → nil なら拒否 | 準拠 |
| Bash | OK | jq `type != "string"` → 拒否 | 準拠 |

#### 違反 P1: Go が解釈層フィールド欠落を暗黙的に受け入れる

- **深刻度:** 高
- **ファイル:** `go/coglog.go` L72-80, L124-136
- **テスト仕様:** SPEC-TEST 4.6 に違反

**現状のコード:**

```go
// go/coglog.go L72-80
type WriteArgs struct {
	User          string `json:"user"`
	Thinking      string `json:"thinking"`
	Assistant     string `json:"assistant"`
	CurrentFocus  string `json:"current_focus"`
	TheoryOfMind  string `json:"theory_of_mind"`
	SelfNarrative string `json:"self_narrative"`
	Annotation    string `json:"annotation"`
}

// go/coglog.go L124-136
func (a *WriteArgs) Validate() error {
	if a.User == "" {
		return fmt.Errorf("%w: missing required field: user", ErrValidation)
	}
	// ... thinking, assistant も同様
	// Interpretation layer: string required, empty acceptable.
	// Go struct fields are always present (zero value is ""), so no check needed.
	return nil
}
```

**問題:** `json.Unmarshal` は JSON 入力に存在しないフィールドを Go 構造体のゼロ値（`""`）に設定する。`Validate()` は解釈層について「Go の構造体フィールドは常に存在する」としてチェックを省略している。

**結果:** 以下の入力がエラーなく通過する:

```json
{"user":"a","thinking":"b","assistant":"c"}
```

仕様ではこの入力は「解釈層フィールドの欠落」としてバリデーションエラーになるべきである。

**CLI の呼び出し箇所:**

```go
// go/cmd/coglog-cli/main.go L80-84
var args coglog.WriteArgs
if err := json.Unmarshal(input, &args); err != nil {
	return fmt.Errorf("invalid JSON: %w", err)
}
entry, err := cl.Write(args)
```

`json.Unmarshal` → `WriteArgs` 構造体 → `Write()` → `Validate()` の経路で、欠落フィールドの検出機会がない。

**修正方針:** `json.Unmarshal` の前に `map[string]interface{}` で一旦受けて、解釈層フィールドの存在を明示的に確認する。または `json.Decoder` の `DisallowUnknownFields` と組み合わせた独自チェックを行う。

---

### R3. タイムスタンプ — ISO 8601 形式の統一

**根拠:**

> `"timestamp": "2026-02-24T12:00:00.000Z"` — DESIGN-v0.9.1.md L79（スキーマ例）
>
> | `timestamp` | string (ISO8601) | ✓ | — | ✓ | 書き込み時刻 | — DESIGN-v0.9.1.md L167
>
> | 10.1 | write → read で timestamp を取得 | ISO 8601 形式に合致（YYYY-MM-DDThh:mm:ssZ 等） | — SPEC-TEST-v0.9.1.md L135

**要件:** タイムスタンプは ISO 8601 形式。DESIGN のスキーマ例はミリ秒付き `.000Z` を示している。テスト仕様は `YYYY-MM-DDThh:mm:ssZ 等` と記述し、`等` で変種を許容している。

各言語が生成するタイムスタンプ形式:

| 言語 | 生成コード | 出力例 |
|------|-----------|--------|
| Rust | `format!("...T...Z", ...)` | `2026-03-07T12:00:00Z` |
| Go | `Format("2006-01-02T15:04:05Z")` | `2026-03-07T12:00:00Z` |
| Java | `ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'")` | `2026-03-07T12:00:00Z` |
| C# | `ToString("yyyy-MM-ddTHH:mm:ssZ")` | `2026-03-07T12:00:00Z` |
| Ruby | `strftime('%Y-%m-%dT%H:%M:%SZ')` | `2026-03-07T12:00:00Z` |
| C++ | `strftime("%Y-%m-%dT%H:%M:%SZ")` | `2026-03-07T12:00:00Z` |
| Bash | `date -u +%Y-%m-%dT%H:%M:%SZ` | `2026-03-07T12:00:00Z` |
| Haskell | `formatTime ... "%Y-%m-%dT%H:%M:%SZ"` | `2026-03-07T12:00:00Z` |
| Common Lisp | `(format nil "...T...Z" ...)` | `2026-03-07T12:00:00Z` |
| **Python** | `datetime.now(timezone.utc).isoformat()` | `2026-03-07T12:00:00.123456+00:00` |
| **Node.js** | `new Date().toISOString()` | `2026-03-07T12:00:00.123Z` |

9言語が `YYYY-MM-DDThh:mm:ssZ`（秒精度・末尾 `Z`）を生成する。Python と Node.js のみ異なる。

#### 不整合 P2: Python タイムスタンプにマイクロ秒と `+00:00` オフセット

- **深刻度:** 高
- **ファイル:**
  - `python/coglog/src/coglog/__init__.py` L131
  - `python/coglog-mcp/src/coglog_mcp/__init__.py` L73
  - `coglog-skill/coglog/scripts/coglog.py` L129

**現状のコード:**

```python
"timestamp": datetime.now(timezone.utc).isoformat(),
# 出力: "2026-03-07T12:00:00.123456+00:00"
```

**問題:**
1. マイクロ秒（`.123456`）が含まれる — 他の9言語は秒精度
2. 末尾が `+00:00` — 他の9言語は `Z`

**影響:** Haskell の `parseTimestamp`（`Adapter.hs:215-222`）は `+00:00` → `Z` の正規化とマイクロ秒の切り捨てを行うコードを含んでおり、この不整合がクロス互換性に実際の影響を与えていることを示す。

**修正方針:** `.isoformat()` → `.strftime('%Y-%m-%dT%H:%M:%SZ')` に変更。

#### 不整合 P3: Node.js タイムスタンプにミリ秒

- **深刻度:** 高
- **ファイル:**
  - `node/coglog/index.mjs` L105
  - `node/coglog-mcp/index.mjs` L86

**現状のコード:**

```javascript
timestamp: new Date().toISOString(),
// 出力: "2026-03-07T12:00:00.123Z"
```

**問題:** ミリ秒（`.123`）が含まれる — 他の9言語（Python除く）は秒精度。

**修正方針:** ミリ秒を除去するフォーマットに変更。

```javascript
const now = new Date();
const timestamp = now.toISOString().replace(/\.\d{3}Z$/, 'Z');
```

#### 仕様自体の曖昧性について

DESIGN のスキーマ例 `"2026-02-24T12:00:00.000Z"` はミリ秒を含んでおり、テスト仕様は `等` で変種を許容している。しかし:

1. 9/11 言語が秒精度で一致している事実は、秒精度が**実質的な標準**であることを示す
2. Python の `+00:00` は `Z` と意味的に同一だが文字列比較では不一致
3. Haskell が Python/Node.js 形式の正規化コードを必要としている事実自体が問題

仕様を明確化するなら、タイムスタンプ形式を `YYYY-MM-DDThh:mm:ssZ`（秒精度・末尾 `Z`）に統一することが望ましい。

---

### R4. _schema の自動付与

**根拠:**

> `_schema` はツールの内部定数から自動生成される。ユーザーが渡す入力には含まれず、バリデーションの対象にもならない。
> — DESIGN-v0.9.1.md L159

| 要件 | 全11言語の準拠 |
|------|:---:|
| write 時に自動付与 | 準拠 |
| `version` = `"0.9.1"` | 準拠 |
| `fact_layer` に3フィールドの説明 | 準拠 |
| `interpretation_layer` に4フィールドの説明 | 準拠 |
| `constraints.window_size` = `"1 turn (overwritten each write)"` | 準拠 |
| `constraints.interpretation_empty` = `"choosing not to write is itself a metacognitive act"` | 準拠 |

**違反: なし。** 全言語に `@coglog-version` マーカーがあり、_schema の内容は完全一致。

---

### R5. 窓サイズ1 — 上書き・履歴なし

**根拠:**

> 窓サイズ | **1ターン固定** | 圧縮・選別の圧力を生む
> 履歴保持 | **なし（上書き）** | 不可逆性（時間の矢）の実装
> — DESIGN-v0.9.1.md L42-45

**違反: なし。** 全11言語で `current.json` を上書き。

---

### R6. turn_id — 単調増加

**根拠:**

> 単調増加するターン番号。セッション内で一意
> — DESIGN-v0.9.1.md L166

> | 7.1 | 初回 write → read | turn_id = 1 |
> | 8.4 | clear → write → read | turn_id = 1（漸化式の初期条件 $a_0$ に戻る） |
> — SPEC-TEST-v0.9.1.md L96-111

**違反: なし。** 全11言語で `prev.turn_id + 1`。clear 後は `1` にリセット。

---

### R7. パス解決 — 4段階の優先順位

**根拠:** SPEC-path-resolution-v0.9.1.md 全体

| 要件 | 準拠 | 備考 |
|------|:---:|------|
| 明示的指定が最優先 | 準拠 | |
| `COGLOG_DIR=""` を未設定扱い | 準拠 | V1 修正済み（PLAN-fix-path-resolution） |
| ホームディレクトリのフォールバック | 準拠 | V3, V4 修正済み |
| write 時のみディレクトリ自動作成（`mkdir -p` 相当） | 準拠 | V5 修正済み |
| Python MCP に `--coglog-dir` | 準拠 | V2 修正済み |
| Bash は環境変数のみ | 準拠 | |
| Skill 版は `Path.home()/.coglog` 固定 | 準拠 | |

**違反: なし（修正済み）。**

---

### R8. CLI インターフェース

**根拠:**

> | コマンド | 機能 |
> | `coglog write` | 現ターンのデータを保存 |
> | `coglog read` | 直前ターンのコグログを返す |
> | `coglog clear` | コグログを明示的にリセット |
> — DESIGN-v0.9.1.md L182-186

> | 14.1 | `coglog-cli read`（初期状態） | "(no coglog found)" を stdout に出力 |
> | 14.2 | JSON を stdin に渡して `coglog-cli write` | "coglog: turn N written" を stdout に出力 |
> | 14.4 | `coglog-cli clear` | "coglog: cleared" を stdout に出力 |
> | 14.5 | 不正な JSON を stdin に渡して `coglog-cli write` | エラーメッセージを stderr に出力。終了コード非 0 |
> — SPEC-TEST-v0.9.1.md L254-260

**違反: なし。** 全11言語で一貫した CLI インターフェース。

---

### R9. MCP プロトコル

**根拠:**

> MCPサーバー | read / write / clear の3ツール公開
> — DESIGN-v0.9.1.md L405

> | 13.1 | initialize ハンドシェイク | protocolVersion, capabilities.tools, serverInfo を含む応答 |
> | 13.2 | tools/list | coglog_read, coglog_write, coglog_clear の3ツールが列挙される |
> — SPEC-TEST-v0.9.1.md L239-245

**違反: なし。** Bash を除く全10言語で JSON-RPC 2.0 over stdio を実装。

---

### R10. クロス互換性

**根拠:**

> | 12.1 | 言語 X で write → 言語 Y で read | 全フィールドが一致する |
> — SPEC-TEST-v0.9.1.md L211-213

**要件:** 任意の言語で write したデータを任意の言語で read できる。

タイムスタンプ以外のフィールド（`_schema`, `turn_id`, `layers`, 解釈層4フィールド）は全言語で JSON 文字列として保存・読み出しされるため、完全な互換性がある。

タイムスタンプについては P2, P3 で述べた形式の不統一がある。ただし:

- タイムスタンプは write 時に自動生成されるため、クロス互換性テスト 12.1 の「全フィールドが一致する」は write 入力の7フィールド（user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation）の一致を指す
- タイムスタンプは read 時にそのまま文字列として返されるため、形式の違いは read 結果に影響しない
- **ただし** Haskell のみ、タイムスタンプを `UTCTime` 型にパースして再フォーマットするため、Python で write → Haskell で read → Haskell で re-write すると形式が変化する

**結論:** 事実上の互換性は保たれているが、P2・P3 の修正によりタイムスタンプ形式を統一することが望ましい。

---

### R11. 外部依存ゼロ

**根拠:**

> CogLogのコアはJSONの読み書きのみで構成される。依存ライブラリはゼロにでき
> — DESIGN-v0.9.1.md L397

> PLAN-release-v0.9.1.md で各言語の「外部依存なし」を明記

| 言語 | 外部依存 | 判定 |
|------|---------|:---:|
| Python | なし（json, datetime, pathlib — 標準ライブラリ） | 準拠 |
| Node.js | なし（node:fs, node:path, node:os） | 準拠 |
| Rust | serde, serde_json, libc（Rust エコシステムでは標準的） | 準拠 |
| Go | なし（encoding/json, os, time） | 準拠 |
| Java | なし（手書き JSON パーサー） | 準拠 |
| C# | なし（System.Text.Json — .NET 標準） | 準拠 |
| Ruby | なし（json, time, fileutils — 標準ライブラリ） | 準拠 |
| Haskell | directory, time（Haskell Platform 標準） | 準拠 |
| C++ | なし（手書き JSON パーサー） | 準拠 |
| Common Lisp | なし（SBCL 標準） | 準拠 |
| Bash | jq のみ（設計文書に明記） | 準拠 |

**違反: なし。**

---

### R12. 手書き JSON パーサーの正確性

外部依存ゼロの方針に従い、Java, C++, Haskell, Common Lisp は手書き JSON パーサーを持つ。パーサーの正確性は暗黙の要請である。

#### 違反 P4: Java MCP の null 解析が `"null"` を検証しない

- **深刻度:** 中
- **ファイル:** `java/coglog-mcp/src/main/java/io/github/harmoniaepic/coglog/mcp/CogLog.java` L253

**MCP 版（違反あり）:**

```java
// java/coglog-mcp/.../CogLog.java L245-255
private static Object parseValue(String src, int[] pos) {
    skipWS(src, pos);
    if (pos[0] >= src.length()) throw new RuntimeException("Unexpected end of input");
    char c = src.charAt(pos[0]);
    if (c == '"') return parseString(src, pos);
    if (c == '{') return parseObject(src, pos);
    if (c == '[') return parseArray(src, pos);
    if (c == 't' || c == 'f') return parseBool(src, pos);
    if (c == 'n') { pos[0] += 4; return null; }  // ← "null" を検証しない
    if (c == '-' || Character.isDigit(c)) return parseNumber(src, pos);
    throw new RuntimeException("Unexpected char '" + c + "' at " + pos[0]);
}
```

**CLI 版（正しい）:**

```java
// java/coglog/.../CogLog.java L264-270
if (c == 'n') {
    if (src.startsWith("null", pos[0])) {  // ← 正しく検証
        pos[0] += 4;
        return null;
    }
    throw new RuntimeException("Expected 'null' at " + pos[0]);
}
```

**問題:** MCP 版は `'n'` で始まる任意の文字列を4文字スキップして `null` を返す。CLI 版にある `src.startsWith("null", pos[0])` の検証が MCP 版では欠落している。CLI 版と MCP 版でコード複製時に修正が伝播していない。

**実影響:** JSON の値が `n` で始まる裸の文字列になる文脈は通常ないため、実運用での発生可能性は低い。しかし、コード複製方針の保守性リスクを示す具体例である。

**修正方針:** CLI 版と同じ `src.startsWith("null", pos[0])` の検証を追加する。

#### 注意点 P5: Haskell の Unicode エスケープ解析が16進数を検証しない

- **深刻度:** 低
- **ファイル:** `haskell/coglog/Adapter.hs` L141 付近

```haskell
parseUnicode rest acc =
  let (hex, rest') = splitAt 4 rest
  in if length hex == 4
     then go rest' (toEnum (read ("0x" ++ hex)) : acc)
     -- ↑ hex が有効な16進数か検証していない
```

**問題:** `read ("0x" ++ hex)` は `hex` に非16進文字が含まれると実行時例外を投げる。

**実影響:** CogLog の JSON は基本的に ASCII 文字列であり、Unicode エスケープ `\uXXXX` が出現する頻度は極めて低い。実運用での発生可能性はほぼない。

**修正方針:** `all isHexDigit hex` のガードを追加し、不正な場合は `Left` を返す。

---

### R13. テスト実装

**根拠:**

> SPEC-TEST-v0.9.1.md で14テスト群を定義
> PLAN-TEST-IMPL-v0.9.1.md で二層テスト構造を計画

**計画されたテスト構造:**

```
tests/
├── fixtures/          # 共有テストフィクスチャ（14ファイル）
├── fixtures-quine/    # Recurrent Quine 用 plist フィクスチャ（7ファイル）
├── harness.sh         # Layer 1 CLI ブラックボックスハーネス
├── harness-mcp.sh     # Layer 2 MCP テストハーネス
├── harness-quine.sh   # Recurrent Quine テストハーネス
└── README.md
```

#### 欠落 P6: テスト実装が未着手

- **深刻度:** —（機能的な問題ではないが、品質保証の欠落）
- **状態:** `tests/` ディレクトリ未作成。`harness.sh` 未作成。各言語のテストファイル未作成。

テスト仕様（SPEC-TEST）と実装プラン（PLAN-TEST-IMPL）は詳細に定義されているが、実装が行われていない。

---

## 問題一覧

| ID | 深刻度 | 要請 | 問題 | 影響ファイル |
|----|--------|------|------|-------------|
| P1 | 高 | R2 | Go が解釈層フィールド欠落を暗黙的に受け入れる（テスト 4.6 違反） | `go/coglog.go` L72-80, L124-136; `go/cmd/coglog-cli/main.go` L80-84; `go/cmd/coglog-mcp/main.go` |
| P2 | 高 | R3, R10 | Python タイムスタンプにマイクロ秒 + `+00:00` オフセット | `python/coglog/src/coglog/__init__.py` L131; `python/coglog-mcp/src/coglog_mcp/__init__.py` L73; `coglog-skill/coglog/scripts/coglog.py` L129 |
| P3 | 高 | R3, R10 | Node.js タイムスタンプにミリ秒 | `node/coglog/index.mjs` L105; `node/coglog-mcp/index.mjs` L86 |
| P4 | 中 | R12 | Java MCP の null 解析が `"null"` を検証しない（CLI 版からの複製漏れ） | `java/coglog-mcp/src/main/java/io/github/harmoniaepic/coglog/mcp/CogLog.java` L253 |
| P5 | 低 | R12 | Haskell の Unicode エスケープ解析が16進数を検証しない | `haskell/coglog/Adapter.hs` L141; `haskell/coglog-mcp/McpServer.hs` |
| P6 | — | R13 | テスト実装が未着手（仕様・プランは存在） | `tests/` 未作成 |

---

## 達成状況マトリクス（2026-03-07 時点の再確認）

本ドキュメントの P1-P6 は「問題報告としての初出時点」の記録であり、現行コードでは一部が解消済みである。以下に、報告時点と現状の差分を整理する。

| ID | 報告時点 | 現状 | 判定根拠（現行コード） |
|----|----------|------|-------------------------|
| P1 | 未達（Go が解釈層の欠落を暗黙受理） | **達成** | `ParseWriteArgs` で `current_focus` / `theory_of_mind` / `self_narrative` / `annotation` の存在と string 型を明示検証する実装に更新済み |
| P2 | 未達（Python timestamp が `+00:00` + マイクロ秒） | **達成** | Python CLI/MCP と skill script で `strftime('%Y-%m-%dT%H:%M:%SZ')` に統一済み |
| P3 | 未達（Node.js timestamp がミリ秒付き） | **達成** | Node CLI/MCP とも `toISOString().replace(/\.\d{3}Z$/, 'Z')` で秒精度 `...Z` に統一済み |
| P4 | 未達（Java MCP null 解析不備） | **達成** | Java MCP の JSON パーサで `n` 開始時に `null` リテラルを厳密検証する分岐を実装済み |
| P5 | 未達 | **未達（継続）** | Haskell 側の `\uXXXX` 解析で 16進数妥当性検証が未実装 |
| P6 | 未達 | **未達（継続）** | `tests/` 配下のハーネス・フィクスチャ実装は未着手 |

**補足:** 今後の優先順位付けは、上記のとおり未達が残る P5・P6 を中心に再設定することが望ましい。

---

## 推奨修正順序

| 順序 | 対象 | 理由 |
|------|------|------|
| 1 | **P1** Go 解釈層バリデーション | 仕様違反（テスト 4.6）。CLI と MCP の両方に影響 |
| 2 | **P2** Python タイムスタンプ | 3ファイル。他9言語との不整合。クロス互換性に影響 |
| 3 | **P3** Node.js タイムスタンプ | 2ファイル。同上 |
| 4 | **P4** Java MCP null 解析 | 1箇所。CLI 版からのコピーで修正可能 |
| 5 | **P5** Haskell Unicode 解析 | 2ファイル。実運用リスクは極低 |
| 6 | **P6** テスト実装 | P1-P5 の修正後に着手が望ましい |
