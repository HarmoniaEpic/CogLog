# CogLog v0.9.1 テスト実装 準備分析・実装方針書

PLAN-TEST-IMPL-v0.9.1.md の実装着手に先立ち、リポジトリ全体の現状分析と具体的な実装方針を記す。

**作成日:** 2026-03-08

---

## 現状分析

### テスト実装の状態

`tests/` ディレクトリは存在しない。テスト実装は完全に未着手であり、PROBLEMS-v0.9.1.md の P6（唯一の未達項目）に該当する。

```
現状:  tests/ なし。各言語ディレクトリ内にもテストファイルなし。
目標:  PLAN-TEST-IMPL-v0.9.1.md に記載の全構造を実装。
```

### 前提条件の達成状況

| 前提条件 | 状態 | 根拠 |
|---------|------|------|
| P1 Go 解釈層バリデーション修正 | 達成 | `ParseWriteArgs` で `map[string]interface{}` による明示検証を実装済み |
| P2 Python タイムスタンプ統一 | 達成 | `strftime('%Y-%m-%dT%H:%M:%SZ')` に統一済み |
| P3 Node.js タイムスタンプ統一 | 達成 | `toISOString().replace(/\.\d{3}Z$/, 'Z')` に統一済み |
| P4 Java MCP null 解析修正 | 達成 | `src.startsWith("null", pos[0])` の検証を追加済み |
| P5 Haskell Unicode エスケープ修正 | 達成 | `all isHexDigit hex` ガードを追加済み |
| V1-V5 パス解決違反修正 | 達成 | PLAN-fix-path-resolution-v0.9.1.md に基づき全修正済み |
| Ruby bin スタブ修正 | 達成 | `require_relative` に復元済み |
| バージョンマーカー統一 | 達成 | `@coglog-version` マーカーが全 34 箇所に付与済み |

全前提条件が達成されており、テスト実装に着手可能な状態である。

### 各言語実装の確認結果

全 11 言語の CLI 実装と 10 言語の MCP 実装（Bash 除く）が存在し、以下の共通インターフェースを持つことを確認した。

| 項目 | 全言語共通 |
|------|-----------|
| CLI コマンド | `read` / `write` / `clear` |
| write 入力 | stdin から JSON（7 フィールド） |
| read 出力 | stdout に JSON（`_schema` + `turn_id` + `timestamp` + `layers` + 解釈層 4 フィールド） |
| read 初期状態 | `(no coglog found)` を stdout |
| write 成功メッセージ | `coglog: turn N written` を stdout |
| clear 成功メッセージ | `coglog: cleared` を stdout |
| エラー出力 | stderr + 終了コード非 0 |
| データディレクトリ制御 | `COGLOG_DIR` 環境変数 |
| データファイル | `current.json` 固定 |
| タイムスタンプ形式 | `YYYY-MM-DDThh:mm:ssZ`（秒精度・末尾 Z） |

---

## 作成対象ファイル一覧

### Phase 1: 共有フィクスチャ

```
tests/
├── fixtures/
│   ├── valid-full.json
│   ├── valid-second.json
│   ├── valid-interpretation-empty.json
│   ├── invalid-user-empty.json
│   ├── invalid-thinking-empty.json
│   ├── invalid-assistant-empty.json
│   ├── invalid-user-missing.json
│   ├── invalid-thinking-missing.json
│   ├── invalid-assistant-missing.json
│   ├── invalid-interp-missing.json
│   ├── invalid-type-number.json
│   ├── invalid-type-array.json
│   ├── invalid-type-null.json
│   └── invalid-json.txt
├── fixtures-quine/
│   ├── valid-full.sexp
│   ├── valid-interpretation-empty.sexp
│   ├── invalid-user-empty.sexp
│   ├── with-opt-advance.sexp
│   ├── with-opt-affordance.sexp
│   ├── with-opt-self-identity.sexp
│   └── with-opt-self-broken.sexp
└── README.md
```

### Phase 3: Layer 1 ハーネス

```
tests/
└── harness.sh
```

### Phase 5: MCP ハーネス

```
tests/
└── harness-mcp.sh
```

### Phase 6: Quine ハーネス

```
tests/
└── harness-quine.sh

common-lisp/coglog-quine/
└── recurrent-quine-baseline.lisp   （Q_0 のバックアップコピー）
```

---

## 具体的実装方針

### Phase 1: フィクスチャ生成

PLAN-TEST-IMPL-v0.9.1.md に JSON の中身が定義済み。そのまま転記する。

#### valid-full.json

```json
{
  "user": "Hello",
  "thinking": "User greeted me",
  "assistant": "Hi there!",
  "current_focus": "greeting",
  "theory_of_mind": "friendly",
  "self_narrative": "conversational partner",
  "annotation": "follow up on tone"
}
```

#### valid-second.json

```json
{
  "user": "How are you?",
  "thinking": "User is making small talk",
  "assistant": "I'm doing well, thanks!",
  "current_focus": "small talk",
  "theory_of_mind": "casual",
  "self_narrative": "approachable",
  "annotation": ""
}
```

#### valid-interpretation-empty.json

```json
{
  "user": "Test",
  "thinking": "Testing empty interpretation",
  "assistant": "OK",
  "current_focus": "",
  "theory_of_mind": "",
  "self_narrative": "",
  "annotation": ""
}
```

#### invalid-*.json の導出規則

PLAN の記載に従い、`valid-full.json` から該当フィールドを削除または型変更して生成する。

| ファイル | 導出方法 |
|---------|---------|
| `invalid-user-empty.json` | `valid-full.json` の `user` を `""` に |
| `invalid-thinking-empty.json` | `valid-full.json` の `thinking` を `""` に |
| `invalid-assistant-empty.json` | `valid-full.json` の `assistant` を `""` に |
| `invalid-user-missing.json` | `valid-full.json` から `user` キーを削除 |
| `invalid-thinking-missing.json` | `valid-full.json` から `thinking` キーを削除 |
| `invalid-assistant-missing.json` | `valid-full.json` から `assistant` キーを削除 |
| `invalid-interp-missing.json` | `valid-full.json` から `current_focus` キーを削除 |
| `invalid-type-number.json` | `valid-full.json` の `user` を数値 `123` に |
| `invalid-type-array.json` | `valid-full.json` の `thinking` を配列 `["a"]` に |
| `invalid-type-null.json` | `valid-full.json` の `current_focus` を `null` に |
| `invalid-json.txt` | `{this is not valid json` |

#### fixtures-quine/ の導出規則

plist 形式。`valid-full.json` の内容を CL plist に変換する。

```
valid-full.sexp:
(:user "Hello" :thinking "User greeted me" :assistant "Hi there!" :current-focus "greeting" :theory-of-mind "friendly" :self-narrative "conversational partner" :annotation "follow up on tone")

valid-interpretation-empty.sexp:
(:user "Test" :thinking "Testing empty interpretation" :assistant "OK" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")

invalid-user-empty.sexp:
(:user "" :thinking "User greeted me" :assistant "Hi there!" :current-focus "greeting" :theory-of-mind "friendly" :self-narrative "conversational partner" :annotation "follow up on tone")
```

`with-opt-*` フィクスチャは Recurrent Quine のオプションキー仕様を参照して作成する。`with-opt-self-identity.sexp` と `with-opt-self-broken.sexp` は実行時に `*self-source*` を参照するラッパースクリプトが必要になるため、ハーネス側でインラインに生成する方が適切。

---

### Phase 3: harness.sh の実装方針

#### 構造

```bash
#!/usr/bin/env bash
set -euo pipefail

# ── 言語・コマンド対応表 ──
# PLAN-TEST-IMPL-v0.9.1.md の表をそのまま連想配列に

# ── ユーティリティ関数 ──
# setup_tmpdir()    一時ディレクトリ作成 + COGLOG_DIR 設定
# teardown_tmpdir() 一時ディレクトリ削除
# pass() / fail()   結果出力 + カウンタ更新
# run_cli()         言語名 + コマンド引数で CLI 実行
# assert_stdout_contains()   stdout に文字列が含まれるか
# assert_exit_code()         終了コードの検証
# assert_json_field()        jq でフィールド値を検証

# ── テスト関数 ──
# test_01_initial_state()
# test_02_roundtrip()
# ...
# test_14_cli_interface()
# test_12_cross_compatibility()

# ── メイン ──
# 引数解析（言語指定 or "all"）
# 指定言語に対してテスト関数を順に実行
# 結果サマリ出力
```

#### 各テストの実行パターン

PLAN に記載のライフサイクルに従う。

```
1. TMPDIR=$(mktemp -d)
2. export COGLOG_DIR="$TMPDIR"
3. テスト実行（CLI コマンド呼び出し）
4. 期待結果と比較（jq / grep / diff）
5. PASS / FAIL 出力
6. rm -rf "$TMPDIR"
```

#### テスト仕様からのテスト関数への対応

| テスト群 | 関数名 | フィクスチャ | 検証手段 |
|---------|--------|------------|---------|
| 1. 初期状態 | `test_01_initial_state` | なし | stdout に `(no coglog found)` |
| 2. ラウンドトリップ | `test_02_roundtrip` | `valid-full.json` | jq で 7 フィールド + `_schema.version` + `turn_id` + `timestamp` |
| 3. 事実層バリデーション | `test_03_fact_validation` | `invalid-user-empty.json` 等 6 ファイル | 終了コード非 0 + stderr にエラー |
| 4. 解釈層バリデーション | `test_04_interp_validation` | `valid-interpretation-empty.json`, `invalid-interp-missing.json` | 空許容テスト→成功、欠落テスト→エラー |
| 5. 型チェック | `test_05_type_check` | `invalid-type-*.json` 3 ファイル | 終了コード非 0 |
| 6. 窓サイズ 1 | `test_06_window_size` | `valid-full.json`, `valid-second.json` | write A → write B → read で B のみ |
| 7. turn_id | `test_07_turn_id` | `valid-full.json` | 連続 write → read で turn_id 確認 |
| 8. clear | `test_08_clear` | `valid-full.json` | write → clear → read で初期状態 |
| 9. _schema | `test_09_schema` | `valid-full.json` | jq で `_schema` の各フィールド値を厳密比較 |
| 10. timestamp | `test_10_timestamp` | `valid-full.json` | grep で ISO 8601 パターンマッチ |
| 11a-f. パス解決 | `test_11_path_resolution` | `valid-full.json` | `--coglog-dir` / `COGLOG_DIR` / 一時ディレクトリ |
| 12. クロス互換性 | `test_12_cross_compat` | `valid-full.json` | 言語 X write → 言語 Y read |
| 14. CLI | `test_14_cli` | `valid-full.json`, `invalid-json.txt` | stdout/stderr/終了コード |

#### 言語コマンド対応表の実装

PLAN の表を bash 関数に変換する。Go と Haskell は `cd` が必要なため、サブシェルで実行する。

```bash
get_cli_cmd() {
  local lang="$1"
  case "$lang" in
    rust)    echo "cargo run --manifest-path rust/Cargo.toml -p coglog -q --" ;;
    python)  echo "PYTHONPATH=python/coglog/src python3 -m coglog" ;;
    node)    echo "node node/coglog/index.mjs" ;;
    go)      echo "cd go && go run ./cmd/coglog-cli" ;;
    ruby)    echo "ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli" ;;
    java)    echo "java -jar java/coglog/target/coglog-cli.jar" ;;
    csharp)  echo "dotnet run --project csharp/coglog --" ;;
    haskell) echo "cd haskell/coglog && cabal -v0 run coglog --" ;;
    cl)      echo "sbcl --script common-lisp/coglog/adapter.lisp" ;;
    cpp)     echo "./cpp-coglog-cli" ;;
    bash)    echo "bash bash/coglog/coglog-cli.sh" ;;
  esac
}
```

注意点:

- **Go**: モジュールルートが `go/go.mod` のため、`cd go &&` が必須。サブシェル `(cd go && ...)` で実行し、`COGLOG_DIR` はサブシェルに引き継ぐ。
- **Haskell**: `cabal -v0` で `Up to date` の stdout 混入を抑制。
- **Java**: 事前に `mvn -f java/coglog/pom.xml package` で JAR を生成する前提。ハーネスはビルド済みを前提とし、ビルド自体はテストしない（PLAN に明記）。
- **C++**: 事前に `c++ -std=c++17 -o ./cpp-coglog-cli cpp/coglog/coglog-cli.cpp` でビルド。ハーネス実行前に実行する。
- **Bash**: `COGLOG_DIR` は `${COGLOG_DIR:-${HOME}/.coglog}` で展開するため、export が必要。
- **Rust**: `-q` フラグでコンパイラ出力を抑制。stderr が混入するとテスト判定に影響するため。

#### クロス互換性テスト（テスト群 12）の組み合わせ

PLAN に定義済みの 12 組み合わせ:

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

実装パターン:

```bash
test_12_cross_compat() {
  local writer="$1" reader="$2"
  local TMPDIR=$(mktemp -d)
  export COGLOG_DIR="$TMPDIR"

  cat tests/fixtures/valid-full.json | run_cli "$writer" write
  local result=$(run_cli "$reader" read)

  # jq で 7 フィールドの値を比較
  local expected=$(cat tests/fixtures/valid-full.json)
  for field in user thinking assistant current_focus theory_of_mind self_narrative annotation; do
    local exp_val=$(echo "$expected" | jq -r ".$field")
    local got_val=$(echo "$result" | jq -r ".layers.$field // .$field")
    assert_eq "$exp_val" "$got_val" "$writer→$reader: $field"
  done

  rm -rf "$TMPDIR"
}
```

注: `user`, `thinking`, `assistant` は read 結果では `layers` オブジェクト内に格納される。解釈層 4 フィールドはトップレベル。

---

### Phase 5: harness-mcp.sh の実装方針

MCP テストは JSON-RPC over stdio で通信する。各言語の MCP コマンドに対して、stdin に JSON-RPC メッセージを書き込み、stdout から応答を読み取る。

#### テストケース

| # | 操作 | 検証 |
|---|------|------|
| 13.1 | `initialize` | `protocolVersion`, `capabilities.tools`, `serverInfo` を含む |
| 13.2 | `tools/list` | 3 ツール（`coglog_read`, `coglog_write`, `coglog_clear`）が列挙 |
| 13.3 | `tools/call coglog_read`（初期状態） | `(no coglog found)` |
| 13.4 | `tools/call coglog_write` → `coglog_read` | write した内容が返る |
| 13.5 | `tools/call coglog_clear` → `coglog_read` | `(no coglog found)` |
| 13.6 | `tools/call coglog_write` に不正引数 | `isError: true` |

#### 実装上の考慮事項

- MCP サーバーは起動後に stdin を待ち続けるため、全メッセージを一括で送り込む方式を採用する。
- 各 JSON-RPC メッセージは改行区切り（NDJSON）で送信する。
- 応答は行単位でパースし、`id` で対応を取る。
- `COGLOG_DIR` で一時ディレクトリを指定し、テスト間の状態汚染を防ぐ。

```bash
run_mcp_test() {
  local lang="$1"
  local TMPDIR=$(mktemp -d)
  local mcp_cmd=$(get_mcp_cmd "$lang")

  # 全 JSON-RPC メッセージを連結して stdin に送る
  {
    echo "$INIT_MSG"
    echo "$TOOLS_LIST_MSG"
    echo "$READ_MSG"
    echo "$WRITE_MSG"
    echo "$READ_AFTER_WRITE_MSG"
    echo "$CLEAR_MSG"
    echo "$READ_AFTER_CLEAR_MSG"
    echo "$WRITE_INVALID_MSG"
  } | COGLOG_DIR="$TMPDIR" eval "$mcp_cmd" 2>/dev/null > "$TMPDIR/responses.txt"

  # 応答を id ごとに抽出・検証
  # ...

  rm -rf "$TMPDIR"
}
```

---

### Phase 6: harness-quine.sh の実装方針

#### ベースライン生成

Phase 6 の冒頭で、現在の `recurrent-quine.lisp` を `recurrent-quine-baseline.lisp` としてコピーする。

```bash
QUINE_DIR=common-lisp/coglog-quine
QUINE_FILE="$QUINE_DIR/recurrent-quine.lisp"
QUINE_BASELINE="$QUINE_DIR/recurrent-quine-baseline.lisp"

# ベースラインが未生成なら作成
if [ ! -f "$QUINE_BASELINE" ]; then
  cp "$QUINE_FILE" "$QUINE_BASELINE"
fi

restore_quine() {
  cp "$QUINE_BASELINE" "$QUINE_FILE"
}
```

#### テスト実行パターン

```
1. restore_quine（ベースラインから復元）
2. テスト実行（sbcl --script recurrent-quine.lisp [read|write|clear]）
3. 期待結果と比較
4. 必要に応じて次世代の動作を検証
5. PASS / FAIL 出力
```

write テストでは stdin から plist を渡す。PLAN-version-sync.md の知見に基づき、パイプではなく heredoc を使用する（`sbcl --script` はパイプ入力をスクリプトソースとして解釈するため）。

#### テスト項目（Q.1-Q.14）

基本動作（Q.1-Q.6）、世代間 round-trip（Q.7-Q.8）、オプションキー（Q.9-Q.12）、系譜の断絶（Q.13）、`:opt-self` round-trip（Q.14）の全 14 テスト。

Q.7-Q.14 は世代をまたぐテストであり、`restore_quine` を呼ばずに連続実行する箇所がある（意図的に次世代のファイルで再実行する）。PLAN のライフサイクル図を厳密に遵守する。

---

### Phase 4: Layer 2 言語固有テスト

PLAN で Layer 2 に委譲されるのは以下の 2 カテゴリ:

1. **11g. 言語固有ホームディレクトリ解決**（Java, C#, Haskell のみ）
2. **13. MCP プロトコル**（harness-mcp.sh で共通化するため、言語固有テストとしては不要）

したがって、Layer 2 の言語固有テストの実装量は限定的である。harness-mcp.sh が MCP テストを全言語共通で担うため、各言語のテストフレームワーク内で書くべきテストは以下に限定される。

| 言語 | テスト内容 | フレームワーク |
|------|-----------|--------------|
| Java | `System.getProperty("user.home")` ベースのパス解決 | JUnit or main メソッド |
| C# | `Environment.GetFolderPath(UserProfile)` ベースのパス解決 | xUnit or dotnet test |
| Haskell | `getHomeDirectory` 例外時のフォールバック | HUnit or hspec |

Go の `coglog_test.go` は PLAN のモノレポ構成に記載があるが、現時点では存在しない。Layer 1 ハーネスが Go の CLI をカバーするため、Go 固有テストの優先度は低い。

---

## 実装順序

```
Step 1: tests/ ディレクトリ構造の作成
Step 2: tests/fixtures/ に JSON フィクスチャ 14 ファイルを配置
Step 3: tests/fixtures-quine/ に plist フィクスチャを配置
Step 4: tests/README.md を作成
Step 5: tests/harness.sh を実装（テスト群 1-10, 11a-f, 14）
Step 6: tests/harness.sh にクロス互換性テスト（テスト群 12）を追加
Step 7: tests/harness-mcp.sh を実装（テスト群 13）
Step 8: recurrent-quine-baseline.lisp を生成
Step 9: tests/harness-quine.sh を実装（テスト Q.1-Q.14）
```

各 Step はコミット単位に対応する。Step 5 が最大の実装量を持つ。

---

## 依存ツール

ハーネスの実行に必要な外部ツール:

| ツール | 用途 | インストール確認 |
|--------|------|----------------|
| `jq` | JSON フィールド抽出・値比較 | `jq --version` |
| `grep` | パターンマッチ | POSIX 標準 |
| `diff` | JSON 出力の全体比較 | POSIX 標準 |
| `mktemp` | 一時ディレクトリ生成 | POSIX 標準 |
| `sbcl` | Recurrent Quine テスト | `sbcl --version`（Phase 6 のみ） |

jq は Bash 版 CogLog の依存でもあるため、テスト環境に jq が入っていれば追加依存はない。

---

## リスクと対策

| リスク | 対策 |
|--------|------|
| Java JAR の事前ビルド（Maven が DNS 解決失敗する環境） | `javac` + `jar` で直接ビルドするフォールバック手順をハーネスの README に記載 |
| C++ のビルド（cosmocc 不在） | `c++ -std=c++17` で代替（PLAN-i18n-build-verify.md の方針に準拠） |
| Go テストで `cd` が必要 | サブシェル `(cd go && ...)` で実行。`COGLOG_DIR` を export してサブシェルに引き継ぐ |
| Haskell の `cabal run` が stdout に `Up to date` を混入 | `cabal -v0 run` で抑制 |
| Rust の `cargo run` が stderr にコンパイラ出力を混入 | `-q` フラグで抑制。stderr は `/dev/null` にリダイレクト |
| Recurrent Quine の write がファイルを不可逆に書き換え | `restore_quine` を各テスト冒頭で実行。ベースラインは `recurrent-quine-baseline.lisp` に固定 |
| MCP サーバーが stdin 終了後もプロセスが残る | タイムアウト付きで実行（`timeout 10s` 等） |

---

## 恒真命題の再確認

SPEC-TEST-v0.9.1.md および PLAN-TEST-IMPL-v0.9.1.md に記載の恒真命題チェックリストを実装時に遵守する。

### CLI テスト

- ❌ CLI の終了コードが 0 であることだけを検証する（何を出力したかを検証しなければ無意味）
- ❌ write 後に current.json が存在することだけを検証する（中身を検証しなければ無意味）
- ❌ jq がエラーなく実行できることだけを検証する（抽出した値の比較なしでは無意味）

### Recurrent Quine

- ❌ write 後にファイルが存在することだけを検証する（中身が有効なプログラムかどうかを検証しなければ無意味）
- ❌ 次世代が「エラーなく起動する」ことだけを検証する（read / write / clear が正しく動作するかを検証しなければ無意味）
- ❌ `:opt-self` を渡した後に「ファイルが変わった」ことだけを検証する（次世代の `*self-source*` が正しく round-trip しているかを検証しなければ無意味）
