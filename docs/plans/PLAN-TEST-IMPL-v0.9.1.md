# CogLog v0.9.1 テスト実装プラン

TEST-SPEC-v0.9.1.md から導出。個々の実装コードは参照していない。

---

## 方針

### 二層テスト

テストを2層に分ける。

```
┌─────────────────────────────────────────────────────┐
│  Layer 1: CLI ブラックボックステスト（共通ハーネス）  │
│                                                     │
│  全11言語の CLI が同じインターフェースを持つ。       │
│  1つのシェルスクリプトで全言語を駆動する。           │
│  テスト仕様 1〜10, 14 の大部分をカバーする。        │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Layer 2: 言語固有テスト                             │
│                                                     │
│  各言語のテストフレームワークで記述する。             │
│  ライブラリ API テスト、パス解決 (11g)、             │
│  MCP プロトコル (13) をカバーする。                  │
└─────────────────────────────────────────────────────┘
```

理由: CogLog の全言語実装は同一の CLI インターフェース（read / write / clear + stdin JSON）と同一のデータ形式（current.json）を共有する。この共通性を活かし、CLI レベルのテストを共通ハーネスで実行することで、言語ごとのテストコード重複を排除する。

### テストデータ

テスト入力の JSON フィクスチャを共有ファイルとして定義する。全言語・全テストが同一の入力を使う。

---

## 共有フィクスチャ

```
tests/
├── fixtures/
│   ├── valid-full.json           # 全7フィールド非空（テスト群 2, 6, 7, 8, 14 で使用）
│   ├── valid-interpretation-empty.json  # 解釈層4フィールドが空文字列（テスト群 4）
│   ├── invalid-user-empty.json   # user が空文字列（テスト 3.1）
│   ├── invalid-thinking-empty.json     # thinking が空文字列（テスト 3.2）
│   ├── invalid-assistant-empty.json    # assistant が空文字列（テスト 3.3）
│   ├── invalid-user-missing.json       # user フィールド自体がない（テスト 3.4）
│   ├── invalid-thinking-missing.json   # thinking フィールド自体がない（テスト 3.5）
│   ├── invalid-assistant-missing.json  # assistant フィールド自体がない（テスト 3.6）
│   ├── invalid-interp-missing.json     # 解釈層フィールドが欠落（テスト 4.6）
│   ├── invalid-type-number.json        # user が数値（テスト 5.1）
│   ├── invalid-type-array.json         # thinking が配列（テスト 5.2）
│   ├── invalid-type-null.json          # current_focus が null（テスト 5.3）
│   ├── invalid-json.txt                # JSON として不正な文字列（テスト 14.5）
│   └── valid-second.json        # valid-full.json とは異なる内容（テスト群 6 の上書き検証用）
├── harness.sh                    # Layer 1 共通ハーネス
└── README.md
```

### valid-full.json

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

### valid-second.json

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

### valid-interpretation-empty.json

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

他のフィクスチャは valid-full.json から該当フィールドを削除または型変更して生成する。

---

## Layer 1: CLI ブラックボックステスト

### ハーネスの設計

1つのシェルスクリプト `harness.sh` が、言語名とコマンドの対応表を持ち、全テストを順に実行する。

```bash
# 使い方
./harness.sh rust       # Rust のみ
./harness.sh all        # 全言語
./harness.sh python go  # 複数指定
```

### 言語とコマンドの対応表

| 言語 | CLI コマンド | MCP コマンド |
|---|---|---|
| Rust | `cargo run -p coglog --` | `cargo run -p coglog-mcp --` |
| Python | `python -m coglog` | `python -m coglog_mcp` |
| Node.js | `node node/coglog/index.mjs` | `node node/coglog-mcp/index.mjs` |
| Go | `go run ./go/cmd/coglog-cli` | `go run ./go/cmd/coglog-mcp` |
| Ruby | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli` | `ruby -Iruby/coglog-mcp/lib ruby/coglog-mcp/bin/coglog-mcp` |
| Java | `java -jar java/coglog/target/coglog-cli.jar` | `java -jar java/coglog-mcp/target/coglog-mcp.jar` |
| C# | `dotnet run --project csharp/coglog --` | `dotnet run --project csharp/coglog-mcp --` |
| Haskell | `cabal run coglog-cli --` | `cabal run coglog-mcp --` |
| CL | `sbcl --script common-lisp/coglog/adapter.lisp` | `sbcl --script common-lisp/coglog-mcp/mcp-server.lisp` |
| C++ | `cpp/coglog/coglog-cli` | `cpp/coglog-mcp/coglog-mcp` |
| Bash | `bash bash/coglog/coglog-cli.sh` | —（MCP なし） |

注: Java は事前に `mvn package` が必要。C++ は事前ビルドが必要。ハーネスはビルド済みを前提とし、ビルド自体はテストしない。

### テスト仕様とカバレッジの対応

| テスト群 | Layer 1 でカバー | Layer 2 に委譲 | 理由 |
|---|---|---|---|
| 1. 初期状態 | ✓ | — | CLI の read/clear で検証可能 |
| 2. ラウンドトリップ | ✓ | — | write → read の JSON 比較 |
| 3. 事実層バリデーション | ✓ | — | 不正入力→終了コード非0+stderr |
| 4. 解釈層バリデーション | ✓ | — | 空文字列入力→成功+read で確認 |
| 5. 型チェック | ✓ | — | 不正型入力→エラー |
| 6. 窓サイズ1 | ✓ | — | write A → write B → read で B のみ |
| 7. turn_id | ✓ | — | 連続 write → read で turn_id 確認 |
| 8. clear | ✓ | — | write → clear → read |
| 9. _schema | ✓ | — | read 結果の JSON から _schema を抽出・検証 |
| 10. timestamp | ✓ | — | read 結果から ISO 8601 パターンマッチ |
| 11a-f. パス解決 (共通) | ✓ | — | --coglog-dir, COGLOG_DIR, 一時ディレクトリで検証 |
| 11g. パス解決 (言語固有) | — | ✓ | Java/C#/Haskell 固有のホーム取得を検証 |
| 12. クロス互換性 | ✓ | — | 言語 X で write → 言語 Y で read |
| 13. MCP | — | ✓ | JSON-RPC over stdio は CLI ハーネスでは扱いにくい |
| 14. CLI | ✓ | — | stdout/stderr/終了コードの検証 |

### ハーネスの各テストの実行パターン

```
┌──────────────────────────────────────────────────────────────┐
│ テスト実行のライフサイクル（各テストケース）                   │
│                                                              │
│  1. 一時ディレクトリを作成（mktemp -d）                      │
│  2. COGLOG_DIR を一時ディレクトリに設定                       │
│  3. テストを実行（CLI コマンド呼び出し）                      │
│  4. 期待結果と比較（jq で JSON 抽出・grep でパターン照合）    │
│  5. PASS / FAIL を出力                                       │
│  6. 一時ディレクトリを削除                                   │
└──────────────────────────────────────────────────────────────┘
```

テスト間の状態汚染を防ぐため、各テストケースが独立した一時ディレクトリを使う。

### 判定ツール

ハーネスは以下の外部ツールに依存する。

| ツール | 用途 |
|---|---|
| jq | JSON の特定フィールド抽出・値比較 |
| grep | パターンマッチ（ISO 8601、エラーメッセージ） |
| diff | JSON 出力の全体比較 |
| mktemp | 一時ディレクトリ生成 |

jq は Bash 版 CogLog の依存でもあるため、テスト実行環境に追加の依存は jq のみ。

---

## Layer 2: 言語固有テスト

### テストフレームワーク

| 言語 | フレームワーク | テストファイル |
|---|---|---|
| Rust | `#[cfg(test)]` (組込み) | `rust/coglog-core/src/` 内 |
| Go | `testing` (標準) | `go/coglog_test.go` |
| Python | `unittest` or `pytest` | `python/coglog/tests/` |
| Node.js | `node:test` (標準) | `node/coglog/test/` |
| Ruby | `minitest` or `rspec` | `ruby/coglog/test/` |
| Java | `JUnit` or main メソッド | `java/coglog/src/test/` |
| C# | `xUnit` or `dotnet test` | `csharp/coglog/Tests/` |
| Haskell | `HUnit` or `hspec` | `haskell/coglog/test/` |
| Common Lisp | `assert` or `prove` | `common-lisp/coglog/tests.lisp` |
| C++ | main + assert | `cpp/coglog/test.cpp` |
| Bash | ハーネス自体がテスト | — |

### Layer 2 が担うテスト仕様

#### 11g. 言語固有ホームディレクトリ解決

各言語のテストフレームワーク内で、環境変数を操作してホーム解決のパスを検証する。

| テスト | 対象言語 | 検証方法 |
|---|---|---|
| 11.15 | Java | `System.clearProperty("user.home")` は不可。環境変数 HOME を削除し、user.home プロパティがフォールバック先を決めることを確認 |
| 11.16 | C# | テストプロセス内で `Environment.GetFolderPath` の結果を確認 |
| 11.17 | Haskell | `unsetEnv "HOME"` → `defaultCoglogPath` が `getCurrentDirectory` ベースになることを確認 |

#### 13. MCP プロトコル

MCP は JSON-RPC over stdio であり、CLI ハーネスでは扱いにくい。言語ごとに stdin/stdout をパイプで接続してテストする。

```
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}' | coglog-mcp
```

各テストケースの実行パターン:

```
┌──────────────────────────────────────────────────────────────┐
│ MCP テストのライフサイクル                                     │
│                                                              │
│  1. 一時ディレクトリを作成                                    │
│  2. coglog-mcp --coglog-dir <tmpdir> をバックグラウンド起動   │
│  3. stdin に JSON-RPC メッセージを書き込む                    │
│  4. stdout から応答を読み取る                                 │
│  5. 応答の JSON を検証                                        │
│  6. プロセスを終了                                            │
│  7. 一時ディレクトリを削除                                    │
└──────────────────────────────────────────────────────────────┘
```

MCP テストは全10言語（Bash 以外）に対して実行する。テストケース 13.1〜13.6 は全言語共通だが、起動コマンドが言語ごとに異なるため、MCP 用の小規模ハーネス（`harness-mcp.sh`）を別に用意する。

---

## クロス互換性テスト（テスト群 12）

Layer 1 ハーネス内に専用のセクションを設ける。

```
┌──────────────────────────────────────────────────────────────┐
│ クロス互換性テストの実行パターン                               │
│                                                              │
│  1. 一時ディレクトリを作成                                    │
│  2. 言語 X の CLI で write（COGLOG_DIR=<tmpdir>）             │
│  3. 言語 Y の CLI で read （COGLOG_DIR=<tmpdir>）             │
│  4. read 結果が write 入力と一致することを検証                │
│  5. 一時ディレクトリを削除                                    │
└──────────────────────────────────────────────────────────────┘
```

PLAN で定義済みの12組み合わせを実行する。全組み合わせ（11×10=110通り）は不要。

---

## 実行順序

```
Phase 1: フィクスチャ生成
  tests/fixtures/ に JSON ファイルを配置

Phase 2: 各言語のビルド（テスト対象の準備）
  cargo build --workspace
  mvn package (java/coglog, java/coglog-mcp)
  dotnet build (csharp/coglog, csharp/coglog-mcp)
  g++ / cosmoc++ (cpp)
  # Python, Node.js, Ruby, Go, Haskell, CL, Bash はビルド不要

Phase 3: Layer 1 — CLI ブラックボックステスト
  ./tests/harness.sh all
  # テスト群 1〜10, 11a-f, 12, 14

Phase 4: Layer 2 — 言語固有テスト
  cargo test --workspace                    # Rust
  go test ./go/...                          # Go
  cd python/coglog && pytest                # Python
  cd node/coglog && node --test             # Node.js
  cd ruby/coglog && ruby -Itest test/*      # Ruby
  cd java/coglog && mvn test                # Java
  cd csharp/coglog && dotnet test           # C#
  cd haskell/coglog && cabal test           # Haskell
  sbcl --load common-lisp/coglog/tests.lisp # CL
  ./cpp/coglog/test                         # C++

Phase 5: Layer 2 — MCP テスト
  ./tests/harness-mcp.sh all
  # テスト群 13（全10言語）
```

---

## CI 統合

GitHub Actions で実行する場合のジョブ構成:

```yaml
jobs:
  build:
    # Phase 2: 全言語のビルド

  test-cli:
    needs: build
    # Phase 3: harness.sh all

  test-unit:
    needs: build
    # Phase 4: 言語ごとに並列実行（matrix strategy）

  test-mcp:
    needs: build
    # Phase 5: harness-mcp.sh all

  test-cross:
    needs: build
    # Phase 3 内のクロス互換性セクション（harness.sh が含む）
```

注: 全11言語のランタイムを1つのランナーに入れる必要がある。Rust, Go, Python, Node.js, Ruby, Java, C#, Haskell (GHC), SBCL, jq, g++。GitHub Actions の ubuntu-latest にはこれらの大部分が入っているが、GHC と SBCL は追加インストールが必要。

---

## ファイル一覧

| ファイル | 説明 |
|---|---|
| `tests/fixtures/*.json` | 共有テストフィクスチャ（14ファイル） |
| `tests/harness.sh` | Layer 1 CLI ブラックボックスハーネス |
| `tests/harness-mcp.sh` | Layer 2 MCP テストハーネス |
| `tests/README.md` | テストの実行方法 |

言語固有テスト（Layer 2 の単体テスト部分）は各言語のディレクトリ内に置く。

---

## 恒真命題の再確認

ハーネス実装時に以下を混入しないこと（TEST-SPEC-v0.9.1.md より）:

- ❌ CLI の終了コードが 0 であることだけを検証する（何を出力したかを検証しなければ無意味）
- ❌ write 後に current.json が存在することだけを検証する（中身を検証しなければ無意味）
- ❌ jq がエラーなく実行できることだけを検証する（抽出した値の比較なしでは無意味）
