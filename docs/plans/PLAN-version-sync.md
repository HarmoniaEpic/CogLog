# GitHub Actions によるバージョン一元管理計画

> **改訂履歴**
>
> | 日付 | 内容 |
> |------|------|
> | 2026-03-07 | 初版作成（ソースコード バージョン埋め込みの置換容易化計画） |
> | 2026-03-07 | GitHub Actions によるバージョン一元管理計画に拡張。パッケージマニフェスト・ワークフロー設計を追加。対象言語に C#・Haskell・Rust・Node.js・JSX を追加 |
> | 2026-03-07 | §1 ステータス更新（全言語 ◎）。§4 作業手順を改訂: テスト検証・計画書更新ステップ追加、§2 の明示的参照、ドライラン確認項目追加 |
> | 2026-03-07 | §4 Step 3 を改訂: 機能テスト中心から PLAN-i18n-build-verify.md 準拠のビルド/構文検証＋スモークテストに変更。機能テストは削除済み |
> | 2026-03-07 | Phase 2 実装: VERSION ファイル配置、version-sync.yml 作成。§3.3 の sed パターンをドライラン検証に基づき修正（エスケープ引用符対応、Bash ヒアドキュメント対応） |
> | 2026-03-07 | §4 Step 3 に完了判定チェックリスト・スキップ規則・遷移ゲートを追加。検証漏れ防止策 |
> | 2026-03-07 | §4 Step 3b（Recurrent Quine 機能テスト）・Step 3c（機能テスト・相互運用テスト・MCP 動作確認）を追加 |
> | 2026-03-07 | §4 Step 3b-2 テスト手順を修正: `echo \| sbcl --script` → heredoc 方式。CLI_CMD 対応表に実テスト所見を注記。Step 3b・3c チェックリスト記入（全 PASS、Python MCP のみ既存バグで SKIP） |

---

## 概要

バージョン文字列 `0.9.1` がリポジトリ内 30 箇所以上に分散している。これを **ルート `VERSION` ファイルを単一ソース・オブ・トゥルース** とし、GitHub Actions ワークフローで全ファイルを自動同期する体制を構築する。

```
VERSION (単一ソース・オブ・トゥルース)
  ↓
GitHub Actions (version-sync workflow)
  ├─ ソースコード定数      → sed (@coglog-version マーカー行)
  ├─ パッケージマニフェスト → jq / sed（ファイル形式別）
  ├─ Cargo.lock            → cargo generate-lockfile
  └─ コミット & v{VERSION} タグ → 既存リリースワークフロー発火
```

### 前提条件

本計画は以下の 2 段階で実現する。

| フェーズ | 内容 | 性質 |
|---------|------|------|
| **Phase 1** | ソースコードの準備（§1） | リファクタリング — 実行時動作に変更なし |
| **Phase 2** | ワークフロー構築（§2・§3） | CI/CD 追加 |

Phase 1 が完了しなければ Phase 2 の `sed` が安全に動作しない。

---

## §1. ソースコード バージョン埋め込みの置換容易化

### 背景と課題

ソースコード内のバージョン文字列は以下の 3 種類に分類される。

| 分類 | 説明 | 例 | 置換要否 |
|------|------|-----|---------|
| **A. ランタイム定数** | プログラムが実行時に参照する値 | `VERSION = "0.9.1"` | 必須 |
| **B. コメント/docstring** | ファイルヘッダー、関数説明内のバージョン | `# CogLog v0.9.1 — ...` | 追従が望ましい |
| **C. ドキュメント参照** | 特定ドキュメントのファイル名 | `DESIGN-v0.9.1.md` | 置換禁止 |

#### 問題点

1. **分類 A・B・C が同一の文字列** `0.9.1` であり、雑な `sed` で C を誤置換するリスクがある
2. **分類 B が多数存在**し、コメント内バージョンの更新漏れが起きやすい
3. バージョン更新時に **対象ファイルの列挙が手動** であり、新ファイル追加時に漏れが生じうる

### 方針

1. **マーカーコメント `@coglog-version` の導入** (分類 A) — ランタイム定数を含む行の末尾に言語ごとのコメント構文でマーカーを付与する
2. **コメント/docstring からのバージョン削除** (分類 B) — ヘッダーコメントや docstring からバージョン番号を除去する。バージョンは定数から参照可能であり、二重管理を排除する
3. **ドキュメント参照は変更しない** (分類 C) — `DESIGN-v0.9.1.md` 等の特定ドキュメントへの参照はそのまま残す

### 対象ファイル一覧

#### 分類 A: マーカーコメント追加

ランタイム定数行の末尾に `@coglog-version` マーカーを追加する。

**◎ = 実装済み、○ = 未実装**

| 状態 | 言語 | ファイル | 現状の記述 | 変更後 |
|:----:|------|---------|-----------|--------|
| ◎ | Python | `python/coglog/src/coglog/__init__.py` | `"version": "0.9.1",` | `"version": "0.9.1",  # @coglog-version` |
| ◎ | Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `"version": "0.9.1",` (SCHEMA) | `"version": "0.9.1",  # @coglog-version` |
| ◎ | Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `"version": "0.9.1",` (SERVER_INFO) | `"version": "0.9.1",  # @coglog-version` |
| ◎ | Ruby | `ruby/coglog/lib/coglog.rb` | `VERSION = '0.9.1'` | `VERSION = '0.9.1'  # @coglog-version` |
| ◎ | Ruby | `ruby/coglog-mcp/lib/coglog_mcp.rb` | `VERSION = '0.9.1'` | `VERSION = '0.9.1'  # @coglog-version` |
| ◎ | Java | `java/coglog/src/.../CogLog.java` | `VERSION = "0.9.1";` | `VERSION = "0.9.1";  // @coglog-version` |
| ◎ | Java | `java/coglog-mcp/src/.../CogLog.java` | `VERSION = "0.9.1";` | `VERSION = "0.9.1";  // @coglog-version` |
| ◎ | Java | `java/coglog-mcp/src/.../McpServer.java` | `"version":"0.9.1"` (JSON文字列内) | `... "0.9.1"...  // @coglog-version` |
| ◎ | C++ | `cpp/coglog/coglog-cli.cpp` | `schema.set("version", "0.9.1");` | `schema.set("version", "0.9.1");  // @coglog-version` |
| ◎ | C++ | `cpp/coglog-mcp/coglog-mcp.cpp` | `schema.set("version", "0.9.1");` | `schema.set("version", "0.9.1");  // @coglog-version` |
| ◎ | C++ | `cpp/coglog-mcp/coglog-mcp.cpp` | `server_info.set("version", "0.9.1");` | `server_info.set("version", "0.9.1");  // @coglog-version` |
| ◎ | Bash | `bash/coglog/coglog-cli.sh` | `readonly COGLOG_VERSION="0.9.1"` | `readonly COGLOG_VERSION="0.9.1"  # @coglog-version` |
| ◎ | Bash | `bash/coglog/coglog-cli.sh` | `version: "0.9.1",` (ヒアドキュメント内) | 直前行に `# @coglog-version` マーカーコメント |
| ◎ | Go | `go/coglog.go` | `Version: "0.9.1",` | `Version: "0.9.1",  // @coglog-version` |
| ◎ | Go | `go/cmd/coglog-mcp/main.go` | `"version": "0.9.1"` | `"version": "0.9.1",  // @coglog-version` |
| ◎ | CL | `common-lisp/coglog/coglog.lisp` | `(defparameter +schema-version+ "0.9.1")` | `(defparameter +schema-version+ "0.9.1")  ; @coglog-version` |
| ◎ | CL | `common-lisp/coglog-mcp/coglog.lisp` | `(defparameter +schema-version+ "0.9.1")` | `(defparameter +schema-version+ "0.9.1")  ; @coglog-version` |
| ◎ | CL | `common-lisp/coglog-mcp/mcp-server.lisp` | `"version\":\"0.9.1\"` (JSON文字列内) | `...  ; @coglog-version` |
| ◎ | CL | `common-lisp/coglog-quine/recurrent-quine.lisp` | `'((:version . "0.9.1")` | `'((:version . "0.9.1")  ; @coglog-version` |
| ◎ | Python | `coglog-skill/coglog/scripts/coglog.py` | `"version": "0.9.1",` | `"version": "0.9.1",  # @coglog-version` |
| ◎ | Python | `coglog-skill/coglog-viz/scripts/coglog-viz.py` | `"version": "0.9.1",` | `"version": "0.9.1",  # @coglog-version` |
| ◎ | C# | `csharp/coglog/CogLog.cs` | `public const string Version = "0.9.1";` | `public const string Version = "0.9.1";  // @coglog-version` |
| ◎ | C# | `csharp/coglog-mcp/CogLog.cs` | `public const string Version = "0.9.1";` | `public const string Version = "0.9.1";  // @coglog-version` |
| ◎ | C# | `csharp/coglog-mcp/Program.cs` | `["version"] = "0.9.1"` | `["version"] = "0.9.1"  // @coglog-version` |
| ◎ | Haskell | `haskell/coglog/CogLog.lhs` | `> schemaVersion = "0.9.1"` | `> schemaVersion = "0.9.1"  -- @coglog-version` |
| ◎ | Haskell | `haskell/coglog-mcp/CogLog.lhs` | `> schemaVersion = "0.9.1"` | `> schemaVersion = "0.9.1"  -- @coglog-version` |
| ◎ | Haskell | `haskell/coglog-mcp/McpServer.hs` | `"version\":\"0.9.1\"` (JSON文字列内) | `...  -- @coglog-version` |
| ◎ | Rust | `rust/coglog-core/src/lib.rs` | `version: "0.9.1".into(),` | `version: "0.9.1".into(),  // @coglog-version` |
| ◎ | Rust | `rust/coglog-mcp/src/main.rs` | `"version": "0.9.1"` (JSON文字列内) | `...  // @coglog-version` |
| ◎ | Node.js | `node/coglog/index.mjs` | `version: "0.9.1",` (SCHEMA) | `version: "0.9.1",  // @coglog-version` |
| ◎ | Node.js | `node/coglog-mcp/index.mjs` | `version: "0.9.1",` (SCHEMA) | `version: "0.9.1",  // @coglog-version` |
| ◎ | Node.js | `node/coglog-mcp/index.mjs` | `version: "0.9.1"` (SERVER_INFO) | `version: "0.9.1"  // @coglog-version` |
| ◎ | JSX | `coglog-skill/coglog-viz/viewer/coglog-viewer-template.jsx` | `"version": "0.9.1",` | `"version": "0.9.1",  // @coglog-version` |
| ◎ | JSX | `coglog-skill/coglog-viz/viewer/coglog-viewer-template.jsx` | `"0.9.1"` (フォールバック表示) | `... {/* @coglog-version */}` |

#### 分類 B: コメント/docstring からバージョン削除

以下のファイルのヘッダーコメント・docstring・usage 文字列からバージョン番号を除去する。

| 言語 | ファイル | 現状 | 変更後 |
|------|---------|------|--------|
| Python | `python/coglog/src/coglog/__init__.py` | `CogLog v0.9.1 — Minimal cognitive...` | `CogLog — Minimal cognitive...` |
| Python | `python/coglog/src/coglog/__init__.py` | `python3 coglog-v0.9.1.py read` | `python -m coglog read` |
| Python | `python/coglog/src/coglog/__init__.py` | `coglog-v0.9.1.py <read\|write\|clear>` | `coglog.py <read\|write\|clear>` |
| Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `CogLog MCP Server v0.9.1` | `CogLog MCP Server` |
| Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `# CogLog class (copied from coglog-v0.9.1.py)` | `# CogLog class (copied from coglog.py)` |
| Ruby | `ruby/coglog/lib/coglog.rb` | `CogLog v0.9.1 — ...` | `CogLog — ...` |
| Ruby | `ruby/coglog-mcp/lib/coglog_mcp.rb` | `CogLog MCP Server v0.9.1` | `CogLog MCP Server` |
| Java | `java/coglog/src/.../CogLog.java` | `CogLog v0.9.1 — ...` | `CogLog — ...` |
| Java | `java/coglog/src/.../Main.java` | `CogLog CLI v0.9.1` | `CogLog CLI` |
| Java | `java/coglog/src/.../Main.java` | `java -jar coglog-0.9.1.jar read` | `java -jar coglog.jar read` |
| Java | `java/coglog-mcp/src/.../CogLog.java` | `CogLog v0.9.1 — ...` | `CogLog — ...` |
| Java | `java/coglog-mcp/src/.../McpServer.java` | `CogLog MCP Server v0.9.1` | `CogLog MCP Server` |
| C++ | `cpp/coglog/coglog-cli.cpp` | `CogLog v0.9.1 — ...` | `CogLog — ...` |
| C++ | `cpp/coglog-mcp/coglog-mcp.cpp` | `CogLog MCP Server v0.9.1 — ...` | `CogLog MCP Server — ...` |
| Bash | `bash/coglog/coglog-cli.sh` | `CogLog CLI v0.9.1 — ...` | `CogLog CLI — ...` |
| Go | `go/coglog.go` | `Package coglog provides CogLog v0.9.1 — ...` | `Package coglog provides CogLog — ...` |
| Go | `go/coglog.go` | `MakeSchema returns the CogLog v0.9.1 schema.` | `MakeSchema returns the CogLog schema.` |
| Go | `go/cmd/coglog-cli/main.go` | `CogLog CLI v0.9.1` | `CogLog CLI` |
| Go | `go/cmd/coglog-mcp/main.go` | `CogLog MCP Server v0.9.1` | `CogLog MCP Server` |
| CL | `common-lisp/coglog/coglog.lisp` | `CogLog v0.9.1 — Common Lisp Pure Core` | `CogLog — Common Lisp Pure Core` |
| CL | `common-lisp/coglog/coglog.lisp` | `Generate the CogLog v0.9.1 _schema.` | `Generate the CogLog _schema.` |
| CL | `common-lisp/coglog-mcp/coglog.lisp` | (同上、同一内容のコピー) | (同上) |
| CL | `common-lisp/coglog-mcp/mcp-server.lisp` | `CogLog MCP Server v0.9.1 — ...` | `CogLog MCP Server — ...` |
| CL | `common-lisp/coglog-quine/recurrent-quine.lisp` | `CogLog v0.9.1 — Recurrent Quine` | `CogLog — Recurrent Quine` |
| C# | `csharp/coglog/CogLog.cs` | `// CogLog v0.9.1 — ...` | `// CogLog — ...` |
| C# | `csharp/coglog/Program.cs` | `// CogLog CLI v0.9.1` | `// CogLog CLI` |
| C# | `csharp/coglog-mcp/CogLog.cs` | `// CogLog v0.9.1 — ...` | `// CogLog — ...` |
| C# | `csharp/coglog-mcp/Program.cs` | `// CogLog MCP Server v0.9.1` | `// CogLog MCP Server` |
| Haskell | `haskell/coglog/CogLog.lhs` | `CogLog v0.9.1 — Haskell Pure Core` | `CogLog — Haskell Pure Core` |
| Haskell | `haskell/coglog-mcp/CogLog.lhs` | `CogLog v0.9.1 — Haskell Pure Core` | `CogLog — Haskell Pure Core` |
| Rust | `rust/coglog-core/src/lib.rs` | `//! CogLog v0.9.1 — ...` | `//! CogLog — ...` |
| Rust | `rust/coglog/src/main.rs` | `//! CogLog CLI v0.9.1` | `//! CogLog CLI` |
| Rust | `rust/coglog-mcp/src/main.rs` | `//! CogLog MCP Server v0.9.1` | `//! CogLog MCP Server` |
| Node.js | `node/coglog/index.mjs` | `* CogLog v0.9.1 — ...` | `* CogLog — ...` |
| Node.js | `node/coglog/index.mjs` | `node coglog-v0.9.1.mjs read` (usage×3箇所) | `node coglog.mjs read` |
| Node.js | `node/coglog/index.mjs` | `import ... './coglog-v0.9.1.mjs'` | `import ... './coglog.mjs'` |
| Node.js | `node/coglog/index.mjs` | `coglog-v0.9.1.mjs <read\|...>` (実行時出力) | `coglog.mjs <read\|...>` |
| Node.js | `node/coglog-mcp/index.mjs` | `* CogLog MCP Server v0.9.1` | `* CogLog MCP Server` |
| Node.js | `node/coglog/index.d.mts` | `* CogLog v0.9.1 — ...` | `* CogLog — ...` |
| Node.js | `node/coglog-mcp/index.d.mts` | `* CogLog MCP Server v0.9.1 — ...` | `* CogLog MCP Server — ...` |

#### 分類 C: 変更しないファイル

| ファイル | 該当記述 | 理由 |
|---------|---------|------|
| `common-lisp/coglog/coglog.lisp` | `DESIGN-v0.9.1.md` | 特定バージョンのドキュメント参照 |
| `common-lisp/coglog-mcp/coglog.lisp` | `DESIGN-v0.9.1.md` | 同上 |
| `haskell/coglog/CogLog.lhs` | `DESIGN-v0.9.1.md` | 同上 |
| `haskell/coglog-mcp/CogLog.lhs` | `DESIGN-v0.9.1.md` | 同上 |

### リスクと注意点

| リスク | 対策 |
|--------|------|
| Bash ヒアドキュメント内の行はコメントを付与できない | 直前行にマーカーコメントを置く、または `$COGLOG_VERSION` 変数展開に置き換える |
| Java の McpServer.java で JSON 文字列リテラル内にバージョンがある | マーカー付与は行コメントで対応可能。将来的には定数参照に置き換えることも検討 |
| Go の package コメントは godoc に影響する | バージョン削除により godoc の表示が変わるが、バージョンはコード内定数で確認可能 |
| Common Lisp quine はコード自体が出力に関わる | マーカーコメントが quine 出力に含まれないことを確認する |
| Haskell `.lhs` の散文行にはコメント構文がない | マーカーはソースコード行 (`>` prefix) にのみ付与する。散文行のバージョンは分類 B として削除 |
| Node.js `index.mjs` の usage 出力文字列にファイル名が埋め込まれている | 分類 B として `coglog-v0.9.1.mjs` → `coglog.mjs` に変更し、バージョン依存を排除する |

---

## §2. パッケージマニフェストの更新戦略

パッケージマニフェストはコメント構文の制約により `@coglog-version` マーカー方式が使えないものが多い。ファイル形式ごとに固有の更新手段を用いる。

### 対象ファイルと更新手段

| 形式 | ファイル | 更新手段 | sed/jq パターン |
|------|---------|---------|----------------|
| package.json | `node/coglog/package.json` | `jq` | `jq --arg v "$V" '.version = $v'` |
| package.json | `node/coglog-mcp/package.json` | `jq` | 同上 |
| pyproject.toml | `python/coglog/pyproject.toml` | `sed` | `s/^version = ".*"/version = "$V"/` |
| pyproject.toml | `python/coglog-mcp/pyproject.toml` | `sed` | 同上 |
| Cargo.toml | `rust/Cargo.toml` | `sed` | ワークスペース `version = "..."` 行を置換 |
| Cargo.toml | `rust/coglog/Cargo.toml` | `sed` | `coglog-core = { ... version = "..." }` を置換 |
| Cargo.toml | `rust/coglog-mcp/Cargo.toml` | `sed` | 同上 |
| Cargo.lock | `rust/Cargo.lock` | `cargo` | `cd rust && cargo generate-lockfile` |
| pom.xml | `java/coglog/pom.xml` | `sed` | `s|<version>.*</version>|<version>$V</version>|` (先頭の `<version>` のみ) |
| pom.xml | `java/coglog-mcp/pom.xml` | `sed` | 同上 |
| *.gemspec | `ruby/coglog/coglog.gemspec` | `sed` | `s/s\.version *= *".*"/s.version     = "$V"/` |
| *.gemspec | `ruby/coglog-mcp/coglog-mcp.gemspec` | `sed` | 同上 |
| *.csproj | `csharp/coglog/coglog.csproj` | `sed` | `s|<Version>.*</Version>|<Version>$V</Version>|` |
| *.csproj | `csharp/coglog-mcp/coglog-mcp.csproj` | `sed` | 同上 |
| *.cabal | `haskell/coglog/coglog.cabal` | `sed` | `s/^version: .*/version:       $V/` |
| *.cabal | `haskell/coglog-mcp/coglog-mcp.cabal` | `sed` | 同上 |
| *.asd | `common-lisp/coglog/coglog.asd` | `sed` | `s/:version ".*"/:version "$V"/` |
| *.asd | `common-lisp/coglog-mcp/coglog-mcp.asd` | `sed` | 同上 |
| *.asd | `common-lisp/coglog-quine/coglog-quine.asd` | `sed` | 同上 |

### 注意点

- **pom.xml**: `<version>` タグは `<parent>` や `<dependency>` にも現れうる。プロジェクト直下の `<version>` のみを対象とするため、行番号指定 (`sed '9s/...'`) またはコンテキスト付きパターン (`/<artifactId>coglog/,/<\/version>/` 等) が必要
- **Cargo.lock**: 手動 `sed` 禁止。`cargo generate-lockfile` で再生成する。GHA ランナーに Rust ツールチェインが必要
- **Cargo.toml (dep refs)**: `coglog-core = { path = "../coglog-core", version = "0.9.1" }` のように依存バージョンも含まれる。ワークスペースバージョンと同時に更新が必要

---

## §3. GitHub Actions ワークフロー設計

### 3.1 全体フロー

```
VERSION ファイル変更 (push to main)
  ↓ version-sync.yml が発火
  ↓
  ├─ VERSION を読み取り
  ├─ @coglog-version マーカー行を sed で一括置換
  ├─ パッケージマニフェストを形式別に更新
  ├─ Cargo.lock を再生成
  ├─ 変更をコミット
  └─ v{VERSION} タグをプッシュ
       ↓ 既存リリースワークフロー (v*.*.* タグ) が発火
       ├─ release-bash.yml
       ├─ release-cpp.yml
       └─ release-coglog-skill.yml
```

### 3.2 version-sync ワークフロー概要

| 項目 | 内容 |
|------|------|
| トリガー | `push` to `main` — `VERSION` ファイルの変更時 |
| ランナー | `ubuntu-latest` |
| 必要ツール | `jq` (プリインストール)、`cargo` (Rust ツールチェイン) |
| 出力 | バージョン同期コミット + `v{VERSION}` タグ |

### 3.3 ソースコード更新 (§1 完了後)

```bash
NEW_VERSION=$(cat VERSION | tr -d '[:space:]')

# @coglog-version マーカー行のバージョン文字列を一括置換
# \\? で通常の引用符 ("0.9.1") とエスケープされた引用符 (\"0.9.1\") の両方に対応
grep -rl '@coglog-version' \
  --include='*.py' --include='*.rb' --include='*.java' \
  --include='*.cpp' --include='*.sh' --include='*.go' \
  --include='*.lisp' --include='*.cs' --include='*.hs' \
  --include='*.lhs' --include='*.rs' --include='*.mjs' \
  --include='*.jsx' . |
  xargs sed -i -E \
    "s/(\\\\?[\"'])[0-9]+\.[0-9]+\.[0-9]+(\\\\?[\"'].*@coglog-version)/\1${NEW_VERSION}\2/g"

# Bash ヒアドキュメント: マーカーの 2 行後にバージョンがある
sed -i -E "/@coglog-version.*next line/{n;n; s/[0-9]+\.[0-9]+\.[0-9]+/${NEW_VERSION}/;}" \
  bash/coglog/coglog-cli.sh
```

### 3.4 パッケージマニフェスト更新

```bash
NEW_VERSION=$(cat VERSION | tr -d '[:space:]')

# package.json (jq)
for f in node/coglog/package.json node/coglog-mcp/package.json; do
  jq --arg v "$NEW_VERSION" '.version = $v' "$f" > tmp.$$ && mv tmp.$$ "$f"
done

# pyproject.toml
sed -i -E "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" \
  python/coglog/pyproject.toml \
  python/coglog-mcp/pyproject.toml

# Cargo.toml (workspace)
sed -i -E "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" rust/Cargo.toml

# Cargo.toml (dependency refs)
sed -i -E "s/(coglog-core = \{[^}]*version = \")([0-9]+\.[0-9]+\.[0-9]+)(\")/\1${NEW_VERSION}\3/" \
  rust/coglog/Cargo.toml rust/coglog-mcp/Cargo.toml

# pom.xml (プロジェクトバージョン — 9行目)
sed -i "9s|<version>.*</version>|<version>${NEW_VERSION}</version>|" \
  java/coglog/pom.xml java/coglog-mcp/pom.xml

# *.gemspec
sed -i -E "s/(s\.version[[:space:]]*=[[:space:]]*)\".*\"/\1\"${NEW_VERSION}\"/" \
  ruby/coglog/coglog.gemspec ruby/coglog-mcp/coglog-mcp.gemspec

# *.csproj
sed -i -E "s|<Version>.*</Version>|<Version>${NEW_VERSION}</Version>|" \
  csharp/coglog/coglog.csproj csharp/coglog-mcp/coglog-mcp.csproj

# *.cabal
sed -i -E "s/^version:[[:space:]]+.*/version:       ${NEW_VERSION}/" \
  haskell/coglog/coglog.cabal haskell/coglog-mcp/coglog-mcp.cabal

# *.asd
sed -i -E "s/:version \".*\"/:version \"${NEW_VERSION}\"/" \
  common-lisp/coglog/coglog.asd \
  common-lisp/coglog-mcp/coglog-mcp.asd \
  common-lisp/coglog-quine/coglog-quine.asd

# Cargo.lock (再生成)
cd rust && cargo generate-lockfile && cd ..
```

### 3.5 既存ワークフローとの整合性

既存 3 ワークフローはいずれも `v*.*.*` タグで発火する。version-sync がタグを打てば自動的にリリースパイプラインが走る。

| 既存ワークフロー | トリガー | 変更要否 |
|----------------|---------|---------|
| `release-bash.yml` | `push: tags: 'v*.*.*'` | 不要 |
| `release-cpp.yml` | `push: tags: 'v*.*.*'` | 不要 |
| `release-coglog-skill.yml` | `push: tags: 'v*.*.*'` | 不要 |

---

## §4. 作業手順

### Phase 1: ソースコードの準備

#### Step 1: 分類 B — コメント/docstring からバージョン削除

全 11 言語の対象ファイルのヘッダーコメント・docstring・usage 文字列からバージョン番号を除去する。

> **完了:** Python・Ruby・Java・C++・Bash・Go・Common Lisp（7c6d1e0）、C#・Haskell・Rust・Node.js・JSX（cf6bf45）

#### Step 2: 分類 A — マーカーコメント追加

全 11 言語のランタイム定数行に `@coglog-version` マーカーを追加する。

> **完了:** Python・Ruby・Java・C++・Bash・Go・Common Lisp（7c6d1e0）、C#・Haskell・Rust・Node.js・JSX（cf6bf45）

#### Step 3: ビルド・構文検証

Step 1・Step 2 の変更（コメント/docstring の編集およびマーカーコメント追加）はランタイムロジックに影響しない。したがって、重い機能テストではなく **ビルド/構文チェック＋スモークテスト** で十分である（PLAN-i18n-build-verify.md と同一のアプローチ）。

##### Priority 1: コードとコメントの境界が曖昧な言語

**Haskell** — Literate Haskell の散文行はコードと隣接しており、編集ミスがコンパイルエラーを引き起こしうる。

```bash
cd haskell/coglog     && cabal build && cabal haddock
cd haskell/coglog-mcp && cabal build && cabal haddock
```

Pass: `cabal build` / `cabal haddock` が exit 0。Haddock パース警告なし。

**Common Lisp** — docstring は S 式内の文字列リテラルであり、エスケープ漏れがリーダーエラーになる。

```bash
sbcl --non-interactive \
  --eval '(require :asdf)' \
  --load common-lisp/coglog/coglog.asd \
  --eval '(asdf:load-system :coglog)'

sbcl --non-interactive \
  --eval '(require :asdf)' \
  --load common-lisp/coglog-mcp/coglog-mcp.asd \
  --eval '(asdf:load-system :coglog-mcp)'
```

Pass: SBCL がリーダー/コンパイルエラーなしでロード完了。

**Common Lisp — Recurrent Quine** — `asdf:load-system` はトップレベルの `(main)` が `exit` を呼ぶため使えない。`write`/`clear` はファイル自身を不可逆に書き換えるため **`read` のみが安全** な検証手段である。

```bash
sbcl --script common-lisp/coglog-quine/recurrent-quine.lisp read
```

Pass: exit 0。stdout に `;;; (no coglog found)` と `;;; affordance` が出力される。

> **警告**: `write` / `clear` を実行すると Q_0 のコメントが不可逆に失われる。破壊的ラウンドトリップテストが必要な場合は、必ずバックアップ→復元の手順を踏むこと（詳細は PLAN-i18n-build-verify.md Step 2b を参照）。

##### Priority 2: コンパイル言語

```bash
cd rust && cargo build --release
c++ -std=c++17 -Os -o /tmp/coglog-cli     cpp/coglog/coglog-cli.cpp
c++ -std=c++17 -Os -o /tmp/coglog-mcp-cpp cpp/coglog-mcp/coglog-mcp.cpp
cd go && go build ./...
cd java/coglog     && mvn -q compile
cd java/coglog-mcp && mvn -q compile
cd csharp/coglog     && dotnet build --nologo -q
cd csharp/coglog-mcp && dotnet build --nologo -q
```

Pass: 全コマンドが exit 0。

> **C++ 環境注記**: CI は `cosmocc` を使用するが、ローカル環境では `c++` で代替する。`-mtiny` は Cosmopolitan 固有フラグのため省略。目的はコンパイル可否の確認であり、リリースバイナリの生成ではない。

##### Priority 3: インタプリタ言語（構文チェック）

```bash
python3 -c "import py_compile; py_compile.compile('python/coglog/src/coglog/__init__.py', doraise=True)"
python3 -c "import py_compile; py_compile.compile('python/coglog-mcp/src/coglog_mcp/__init__.py', doraise=True)"
node --check node/coglog/index.mjs
node --check node/coglog-mcp/index.mjs
ruby -c ruby/coglog/lib/coglog.rb
ruby -c ruby/coglog-mcp/lib/coglog_mcp.rb
bash -n bash/coglog/coglog-cli.sh
```

Pass: 全コマンドが exit 0（Ruby は `Syntax OK` を出力）。

##### スモークテスト

コンパイル済みバイナリおよびスクリプトに `--help` を渡し、クラッシュせず usage テキストが表示されることを確認する。

| 言語 | コマンド | 期待結果 |
|------|---------|---------|
| Rust | `rust/target/release/coglog-cli --help` | Usage 表示、exit 0 |
| C++ | `/tmp/coglog-cli --help` | Usage 表示、exit 0 |
| Go | `cd go && go run ./cmd/coglog-cli --help` | Usage 表示、exit 0 |
| Haskell | `cd haskell/coglog && cabal run coglog-cli -- --help` | Usage 表示、exit 0 |
| Java | `java -jar java/coglog/target/coglog-cli.jar --help` | Usage 表示、exit 0 |
| C# | `dotnet run --project csharp/coglog -- --help` | Usage 表示、exit 0 |
| Python | `PYTHONPATH=python/coglog/src python3 -m coglog --help` | Usage 表示、exit 0 |
| Node.js | `node node/coglog/index.mjs --help` | Usage 表示、exit 0 |
| Ruby | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli --help` | Usage 表示、exit 0 |
| Bash | `bash bash/coglog/coglog-cli.sh --help` | Usage 表示、exit 0 |
| CL Quine | `sbcl --script .../recurrent-quine.lisp read` | 状態表示、exit 0（Priority 1 で実施済み） |

MCP サーバー (`coglog-mcp`) は stdio JSON-RPC が必要なためスモークテスト対象外。

##### 失敗時の切り分け

| 原因 | 対応 |
|------|------|
| 変更起因の破損（文字列閉じ忘れ、Haddock マーカー破損等） | 該当ソースを修正し、失敗ステップを再実行 |
| 環境起因（ツールチェイン不在等） | 記録してスキップ。CI または別環境で再検証 |

##### 完了判定チェックリスト

Step 3 の全検証項目の結果を以下のテーブルに記録する。**全行が PASS または SKIP（理由付き）で埋まるまで Step 4 に進んではならない。**

| 言語 | 構文/ビルド | スモーク | 結果 | スキップ理由 |
|------|-----------|--------|------|------------|
| Rust | `cargo build --release` | `--help` | PASS | |
| C++ | `c++ -std=c++17` | `--help` | PASS | |
| Go | `go build ./...` | `--help` | PASS | |
| Java | `mvn compile` / `javac` | `--help` | PASS | javac 直接コンパイルで確認（Maven は DNS 解決失敗で使用不可） |
| C# | `dotnet build` | `--help` | PASS | |
| Haskell | `cabal build` | `--help` | PASS | |
| Common Lisp | `sbcl --eval '(load ...)'` | `read` | PASS | STYLE-WARNING は既存の前方参照（変更無関係） |
| Python | `py_compile` | `--help` | PASS | |
| Node.js | `node --check` | `--help` | PASS | |
| Ruby | `ruby -c` | `--help` | PASS | |
| Bash | `bash -n` | `--help` | PASS | |

##### スキップ規則

スキップが許容されるのは **ツールチェインが未インストール** の場合のみ。ツールが利用可能にもかかわらず省略する場合は、具体的理由をチェックリストの「スキップ理由」欄に記載し、ユーザーの承認を得ること。

#### Step 3b: Recurrent Quine 機能テスト

##### 前提

Recurrent Quine は自己書き換えプログラムであり、通常の CogLog 実装とは質的に異なる。

| 項目 | 通常の 11 言語実装 | Recurrent Quine |
|------|-------------------|-----------------|
| write / clear の影響範囲 | `$COGLOG_DIR/current.json` のみ | **`recurrent-quine.lisp` 自身** |
| COGLOG_DIR による隔離 | 有効（一時ディレクトリで安全） | **無効**（ファイル自身の書き換えは防げない） |
| テスト後の状態復元 | 一時ディレクトリ削除で完了 | バックアップからの `cp` が必須 |
| 入力形式 | JSON (stdin) | Common Lisp plist (stdin) |

> **禁止事項:** バックアップなしで `write` または `clear` を実行してはならない。Q_0 の散文コメントが不可逆に失われる。

##### 3b-1. 非破壊テスト（read のみ）

`read` はファイルを一切変更しない唯一の操作である。

```bash
sbcl --script common-lisp/coglog-quine/recurrent-quine.lisp read
```

**判定基準:**

| 項目 | 期待結果 |
|------|---------|
| 終了コード | 0 |
| stdout | `;;; (no coglog found)` を含む（初期状態） |
| stdout | `;;; affordance` と affordance S 式を含む |
| ファイル | `git diff` で変更なし |

##### 3b-2. 破壊的テスト（write → read → 復元）

write / clear の動作確認には、バックアップ→実行→復元の手順を厳守する。

> **注意:** `sbcl --script` はパイプ入力をスクリプトソースとして解釈するため、`echo ... | sbcl --script` は使用できない。stdin からデータを渡すには **heredoc** (`<<'EOF'`) を使う必要がある。

```bash
QUINE=common-lisp/coglog-quine/recurrent-quine.lisp

# 1. バックアップ（スキップ厳禁）
cp "$QUINE" /tmp/recurrent-quine-backup.lisp

# 2. write（ファイル自身が次世代に書き換わる）
#    ※ パイプ (echo ... |) ではなく heredoc を使うこと
sbcl --script "$QUINE" write <<'EOF'
(:user "test" :thinking "test" :assistant "test" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")
EOF

# 3. 次世代が read できることを確認
sbcl --script "$QUINE" read

# 4. clear
sbcl --script "$QUINE" clear

# 5. clear 後の read
sbcl --script "$QUINE" read

# 6. 復元（スキップ厳禁）
cp /tmp/recurrent-quine-backup.lisp "$QUINE"

# 7. 復元確認
git diff --stat "$QUINE"  # 差分がないこと
```

**判定基準:**

| 手順 | 期待結果 |
|------|---------|
| 手順 2 | `coglog: turn 1 written` を含む。exit 0 |
| 手順 3 | `;;; state` に続いて全フィールドが出力される。exit 0 |
| 手順 4 | `coglog: cleared` を含む。exit 0 |
| 手順 5 | `;;; (no coglog found)` を含む。exit 0 |
| 手順 7 | `git diff` の出力が空（完全復元） |

> **手順 6 を実行せずに Step 3b を完了としてはならない。** 復元を怠ると `git status` にファイル変更が残り、以降のコミットで Q_0 が失われる。

##### 3b-3. 並列実行の禁止

Step 3b の破壊的テスト（3b-2）は `recurrent-quine.lisp` を直接書き換えるため、他のいかなるステップとも **並列実行してはならない**。特に Step 3c の Common Lisp 機能テスト（`common-lisp/coglog/` 経由）とは無関係なファイルを操作するが、同一の SBCL プロセスモデルを共有するため、混乱を避ける意味でも逐次実行とする。

##### 完了判定チェックリスト

| テスト | 結果 | スキップ理由 |
|--------|------|------------|
| 3b-1 非破壊テスト（read） | PASS | |
| 3b-2 破壊的テスト（write → read → clear → read → 復元） | PASS | |
| 3b-2 復元確認（git diff 差分なし） | PASS | |

#### Step 3c: 機能テスト・相互運用テスト・MCP 動作確認

Step 3 のビルド/構文検証、Step 3b の Recurrent Quine テストに続き、通常の 11 言語実装の実動作を確認する。SPEC-TEST-v0.9.1.md のテスト群 1・2・8・12・13 から最小限のサブセットを抽出する。

> **注:** 本ステップの Common Lisp テストは `common-lisp/coglog/`（通常の CLI 実装）が対象である。Recurrent Quine (`common-lisp/coglog-quine/`) は Step 3b で個別にテスト済みであり、ここでは実施しない。

##### 3c-1. 機能テスト（read / write / clear）

各言語の CLI で初期状態 read → write → read → clear → read の一連フローを実行し、基本動作を確認する。

```bash
# 共通手順（言語ごとに CLI_CMD を差し替え）
TMPDIR=$(mktemp -d)
FIXTURE='{"user":"Hello","thinking":"User greeted me","assistant":"Hi there!","current_focus":"greeting","theory_of_mind":"friendly","self_narrative":"conversational partner","annotation":"follow up on tone"}'

# 1. 初期状態 read → "(no coglog found)"
COGLOG_DIR="$TMPDIR" $CLI_CMD read

# 2. write
echo "$FIXTURE" | COGLOG_DIR="$TMPDIR" $CLI_CMD write

# 3. write 後の read → JSON にフィールドが含まれる
COGLOG_DIR="$TMPDIR" $CLI_CMD read

# 4. clear
COGLOG_DIR="$TMPDIR" $CLI_CMD clear

# 5. clear 後の read → "(no coglog found)"
COGLOG_DIR="$TMPDIR" $CLI_CMD read

rm -rf "$TMPDIR"
```

**CLI_CMD 対応表:**

| 言語 | CLI_CMD | 備考 |
|------|---------|------|
| Rust | `cd rust && cargo run -q -p coglog --` | `rust/` から実行。stderr にコンパイラ警告が混入するため `2>/dev/null` 推奨 |
| Python | `PYTHONPATH=python/coglog/src python3 -m coglog` | `__init__.py` 直接実行は `main()` が呼ばれない。`-m coglog` を使う |
| Node.js | `node node/coglog/index.mjs` | |
| Go | `cd go && go run ./cmd/coglog-cli` | `go/` から実行 |
| Ruby | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli` | |
| Java | `java -jar <path-to-jar>` | 要事前ビルド（`javac` + `jar`）。Maven は環境依存 |
| C# | `dotnet run --project csharp/coglog --` | |
| Haskell | `cd haskell/coglog && cabal -v0 run coglog --` | `cabal -v0` で `Up to date` の stdout 混入を抑制 |
| Common Lisp | `sbcl --script common-lisp/coglog/adapter.lisp` | |
| C++ | `/tmp/coglog-cli` (要事前ビルド: `c++ -std=c++17 -Os -o /tmp/coglog-cli cpp/coglog/coglog-cli.cpp`) | |
| Bash | `bash bash/coglog/coglog-cli.sh` | |

**判定基準:**

| 手順 | 期待結果 |
|------|---------|
| 手順 1 | stdout に `(no coglog found)` を含む。exit 0 |
| 手順 2 | stdout に `coglog: turn 1 written` を含む。exit 0 |
| 手順 3 | stdout が valid JSON。`user` = `"Hello"`, `_schema.version` = `"0.9.1"` |
| 手順 4 | stdout に `coglog: cleared` を含む。exit 0 |
| 手順 5 | stdout に `(no coglog found)` を含む。exit 0 |

##### 3c-2. 相互運用テスト（クロス言語 write → read）

異なる言語間でデータ形式の互換性を確認する。SPEC-TEST-v0.9.1.md テスト群 12 から、異なるランタイム系統（コンパイル型・インタプリタ型・VM 型）を跨ぐ代表 3 組を選定する。

```bash
TMPDIR=$(mktemp -d)
FIXTURE='{"user":"cross-test","thinking":"interop check","assistant":"OK","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}'

# 組 1: Rust write → Python read
echo "$FIXTURE" | COGLOG_DIR="$TMPDIR" cargo run --manifest-path rust/Cargo.toml -p coglog -- write
COGLOG_DIR="$TMPDIR" PYTHONPATH=python/coglog/src python3 -m coglog read

# 組 2: Node.js write → Go read
rm -f "$TMPDIR/current.json"
echo "$FIXTURE" | COGLOG_DIR="$TMPDIR" node node/coglog/index.mjs write
(cd go && COGLOG_DIR="$TMPDIR" go run ./cmd/coglog-cli read)

# 組 3: Python write → Ruby read
rm -f "$TMPDIR/current.json"
echo "$FIXTURE" | COGLOG_DIR="$TMPDIR" PYTHONPATH=python/coglog/src python3 -m coglog write
COGLOG_DIR="$TMPDIR" ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli read

rm -rf "$TMPDIR"
```

**判定基準:** 各組の read 結果が write 入力の全 7 フィールドと一致すること。`_schema.version` が `"0.9.1"` であること。

##### 3c-3. MCP サーバー動作確認

MCP サーバーが起動し、`initialize` ハンドシェイクと `tools/list` に正しく応答することを確認する。代表 3 言語（Rust・Python・Node.js）で実施する。

```bash
TMPDIR=$(mktemp -d)

# JSON-RPC リクエスト
INIT='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}'
LIST='{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'

# Rust
echo -e "${INIT}\n${LIST}" | COGLOG_DIR="$TMPDIR" cargo run --manifest-path rust/Cargo.toml -p coglog-mcp -- 2>/dev/null

# Python
echo -e "${INIT}\n${LIST}" | COGLOG_DIR="$TMPDIR" PYTHONPATH=python/coglog-mcp/src python3 -m coglog_mcp 2>/dev/null

# Node.js
echo -e "${INIT}\n${LIST}" | COGLOG_DIR="$TMPDIR" node node/coglog-mcp/index.mjs 2>/dev/null

rm -rf "$TMPDIR"
```

**判定基準:**

| 応答 | 期待結果 |
|------|---------|
| `initialize` 応答 | `protocolVersion`, `capabilities.tools`, `serverInfo` を含む |
| `tools/list` 応答 | `coglog_read`, `coglog_write`, `coglog_clear` の 3 ツールが列挙される |

##### 完了判定チェックリスト

**全行が PASS または SKIP（理由付き）で埋まるまで Step 4 に進んではならない。**

| テスト | 言語 | 結果 | スキップ理由 |
|--------|------|------|------------|
| 3c-1 機能テスト | Rust | PASS | |
| 3c-1 機能テスト | Python | PASS | |
| 3c-1 機能テスト | Node.js | PASS | |
| 3c-1 機能テスト | Go | PASS | |
| 3c-1 機能テスト | Ruby | PASS | |
| 3c-1 機能テスト | Java | PASS | |
| 3c-1 機能テスト | C# | PASS | |
| 3c-1 機能テスト | Haskell | PASS | |
| 3c-1 機能テスト | Common Lisp (not coglog-quine) | PASS | |
| 3c-1 機能テスト | C++ | PASS | |
| 3c-1 機能テスト | Bash | PASS | |
| 3c-2 相互運用 | Rust → Python | PASS | |
| 3c-2 相互運用 | Node.js → Go | PASS | |
| 3c-2 相互運用 | Python → Ruby | PASS | |
| 3c-3 MCP | Rust | PASS | |
| 3c-3 MCP | Python | PASS | 既存バグ `coglog_dir` 未定義を修正済み |
| 3c-3 MCP | Node.js | PASS | |

##### スキップ規則

Step 3 と同一。ツールチェインが未インストールの場合のみスキップ可。機能テストの失敗は Step 1・2 の変更に起因する回帰の可能性があるため、環境問題でない限りスキップ不可。

#### Step 4: マーカー・残存バージョンの検証

```bash
# マーカー行の一覧を確認
grep -rn '@coglog-version' \
  --include='*.py' --include='*.rb' --include='*.java' \
  --include='*.cpp' --include='*.sh' --include='*.go' \
  --include='*.lisp' --include='*.cs' --include='*.hs' \
  --include='*.lhs' --include='*.rs' --include='*.mjs' \
  --include='*.jsx' --include='*.d.mts' .

# 分類 C (ドキュメント参照) が残っていることを確認
grep -rn 'DESIGN-v0.9.1.md' --include='*.lisp' --include='*.lhs' .

# ソースコード内に残るマーカーなしの "0.9.1" を確認
# (分類 C のドキュメント参照のみが残るはず)
grep -rn '0\.9\.1' \
  --include='*.py' --include='*.rb' --include='*.java' \
  --include='*.cpp' --include='*.sh' --include='*.go' \
  --include='*.lisp' --include='*.cs' --include='*.hs' \
  --include='*.lhs' --include='*.rs' --include='*.mjs' \
  --include='*.jsx' --include='*.d.mts' . | grep -v '@coglog-version'
```

#### Step 5: 計画書ステータス更新

§1 分類 A テーブルの ○ → ◎ を反映し、改訂履歴にコミットハッシュを追記する。

### Phase 2: ワークフロー構築

#### Step 6: VERSION ファイル配置

リポジトリルートに `VERSION` ファイルを配置する（内容: 現在のバージョン文字列のみ）。

#### Step 7: version-sync ワークフロー作成

`.github/workflows/version-sync.yml` を作成する。

- **ソースコード定数の更新**: §3.3 に基づき、`@coglog-version` マーカー行を sed で一括置換する
- **パッケージマニフェストの更新**: §2 の対象ファイル一覧と §3.4 のスクリプトに基づき、ファイル形式ごとに更新する
- **Cargo.lock の再生成**: `cargo generate-lockfile` を実行する（Rust ツールチェインが必要）
- **コミット・タグ**: 変更をコミットし、`v{VERSION}` タグをプッシュする

#### Step 8: ドライラン検証

ブランチ上で VERSION を変更し、ワークフローが正しく全ファイルを更新することを確認する。

**確認項目:**

- [x] `@coglog-version` マーカー行のバージョンが全て更新されている（ローカルドライラン: 9.9.9 で全34箇所＋Bashヒアドキュメント1箇所を確認）
- [ ] 全パッケージマニフェスト（§2 対象 18 ファイル）のバージョンが更新されている
- [ ] pom.xml で `<dependency>` 等の無関係な `<version>` が誤置換されていない
- [ ] `Cargo.lock` が `cargo generate-lockfile` で正常に再生成されている
- [x] 分類 C（`DESIGN-v0.9.1.md`）が変更されていない（ローカルドライランで残存確認済み）
- [ ] `v{VERSION}` タグが正しく作成されている
- [ ] 既存リリースワークフロー（release-bash / release-cpp / release-coglog-skill）がタグにより正常に発火する

---

## §5. 対象外

以下は本計画の対象外とする。

| 対象外 | 理由 |
|--------|------|
| README ファイル (`*.md`) | 設計ドキュメントへのリンクやインストールコマンドにバージョンが含まれるが、これらはリリースごとに手動で確認・更新する |
| `docs/` 配下の設計書・研究ノート | 特定バージョンの設計記録であり、バージョン番号は歴史的事実として固定 |
| `docs/oldsources/` | アーカイブ資料 |
| `coglog-skill/*/SKILL.md` | スキル定義ファイル。リリース時に手動更新 |
