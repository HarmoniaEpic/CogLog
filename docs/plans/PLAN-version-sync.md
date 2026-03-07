# GitHub Actions によるバージョン一元管理計画

> **改訂履歴**
>
> | 日付 | 内容 |
> |------|------|
> | 2026-03-07 | 初版作成（ソースコード バージョン埋め込みの置換容易化計画） |
> | 2026-03-07 | GitHub Actions によるバージョン一元管理計画に拡張。パッケージマニフェスト・ワークフロー設計を追加。対象言語に C#・Haskell・Rust・Node.js・JSX を追加 |
> | 2026-03-07 | §1 ステータス更新（全言語 ◎）。§4 作業手順を改訂: テスト検証・計画書更新ステップ追加、§2 の明示的参照、ドライラン確認項目追加 |

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
| Python | `python/coglog/src/coglog/__init__.py` | `python3 coglog-v0.9.1.py read` | `python3 coglog.py read` |
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
grep -rl '@coglog-version' \
  --include='*.py' --include='*.rb' --include='*.java' \
  --include='*.cpp' --include='*.sh' --include='*.go' \
  --include='*.lisp' --include='*.cs' --include='*.hs' \
  --include='*.lhs' --include='*.rs' --include='*.mjs' \
  --include='*.jsx' . |
  xargs sed -i -E \
    "s/([\"'])([0-9]+\.[0-9]+\.[0-9]+)\1(.*@coglog-version)/\1${NEW_VERSION}\1\3/g"
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

#### Step 3: テスト検証

各言語の既存テストを実行し、Step 1・Step 2 の変更が動作に影響しないことを検証する。

```bash
# 各言語のテストコマンド（存在するもののみ実行）
cd python/coglog && python -m pytest && cd ../..
cd python/coglog-mcp && python -m pytest && cd ../..
cd ruby/coglog && bundle exec rake test && cd ../..
cd java/coglog && mvn test && cd ../..
cd java/coglog-mcp && mvn test && cd ../..
cd rust && cargo test && cd ..
cd csharp/coglog && dotnet test && cd ../..
cd csharp/coglog-mcp && dotnet test && cd ../..
cd haskell/coglog && cabal test && cd ../..
cd haskell/coglog-mcp && cabal test && cd ../..
cd go && go test ./... && cd ..
# Bash・Common Lisp・JSX — 自動テストがない場合は手動確認
```

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

- [ ] `@coglog-version` マーカー行のバージョンが全て更新されている
- [ ] 全パッケージマニフェスト（§2 対象 18 ファイル）のバージョンが更新されている
- [ ] pom.xml で `<dependency>` 等の無関係な `<version>` が誤置換されていない
- [ ] `Cargo.lock` が `cargo generate-lockfile` で正常に再生成されている
- [ ] 分類 C（`DESIGN-v0.9.1.md`）が変更されていない
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
