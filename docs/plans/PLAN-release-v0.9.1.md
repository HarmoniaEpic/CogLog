# CogLog v0.9.1 リリース準備計画

> **改訂履歴**
>
> | 日付 | 内容 |
> |------|------|
> | 初版 | PLAN-release-v0.9.1.md 作成 |
> | 2026-03-05 | リポジトリ実構造との整合: DESIGN-v0.9.1.md → docs/designs/ 移動、cpp/ と bash/ のサブディレクトリ化、skill/ → coglog-skill/coglog/ 改称、docs/ 配下に designs/ と研究ノートを追加、.github/workflows/ を構成図に追加 |

## 変更の性質

**MINOR VERSION 相当**（既存コードへの機能変更はないが、パッケージング構造の新規追加・11言語展開・Haskell/CL/Go/Ruby/Java/C#/Bash の新規実装を伴う）

---

## 概要

CogLog v0.9.1 を **9つのパッケージレジストリ**に公開する。

11言語の実装を単一の GitHub モノレポに統合し、計 **20パッケージ** を配布する。

---

## パッケージマトリクス

### 全体

| | PyPI | npm | crates.io | Hackage | Quicklisp | RubyGems | Maven Central | pkg.go.dev | NuGet |
|---|---|---|---|---|---|---|---|---|---|
| **coglog** | CLI | CLI | CLI | CLI | CLI | CLI | CLI | CLI | CLI |
| **coglog-core** | — | — | lib | — | — | — | — | — | — |
| **coglog-mcp** | MCP | MCP | MCP | MCP | MCP | MCP | MCP | MCP | MCP |
| **coglog-quine** | — | — | — | — | quine | — | — | — | — |
| 小計 | 2 | 2 | 3 | 2 | 3 | 2 | 2 | 2 | 2 |

合計: **20パッケージ**

### 各言語の層と役割

| 言語 | 層 | レジストリ | 照射するもの |
|---|---|---|---|
| Python | 実用層 | PyPI | Claude サンドボックスでの即時利用 |
| Node.js | 実用層 | npm | Claude サンドボックスでの即時利用 + TypeScript 型定義 |
| Rust | 実用層 | crates.io | 型安全 + ネイティブバイナリ |
| C++ | 実用層 | GitHub Releases | ユニバーサルバイナリ（cosmocc） |
| Go | 実用層 | pkg.go.dev | AI インフラ言語 + ランタイム不要バイナリ |
| Ruby | 実用層 | RubyGems | Rails AI エコシステム（MCP SDK 公式、Shopify 共同開発） |
| Java | 実用層 | Maven Central | エンタープライズ AI（Spring AI、MCP SDK 公式） |
| C# | 実用層 | NuGet | Microsoft AI エコシステム（Agent Framework、MCP SDK 公式） |
| Haskell | 分析層 | Hackage | 純粋/不純の分離。IO が advance に侵入しないことの型による証明 |
| Common Lisp | 分析層 | Quicklisp | ホモイコニシティ。_schema の必然性。コード=データ=状態の一致 |
| Bash | 分析層 | — (リポジトリ同梱) | グルー言語。CogLog の全操作が jq + POSIX ユーティリティに還元できることの証明 |

### MCP 公式 SDK カバレッジ

| MCP 公式 SDK | 共同メンテ | CogLog |
|---|---|---|
| Python | Anthropic | ✓ |
| TypeScript | Anthropic | ✓ (Node.js + .d.mts) |
| Java | Spring AI | ✓ |
| C# | Microsoft | ✓ |
| Go | Google | ✓ |
| Ruby | Shopify | ✓ |
| Swift | (募集中) | — (将来検討) |

### インストール

| レジストリ | coglog | coglog-mcp |
|---|---|---|
| PyPI | `pip install coglog` | `pip install coglog-mcp` |
| npm | `npm i -g coglog` | `npm i -g coglog-mcp` |
| crates.io | `cargo install coglog` | `cargo install coglog-mcp` |
| Hackage | `cabal install coglog` | `cabal install coglog-mcp` |
| Quicklisp | `(ql:quickload :coglog)` | `(ql:quickload :coglog-mcp)` |
| RubyGems | `gem install coglog` | `gem install coglog-mcp` |
| Maven Central | `mvn dependency:get ...` | 同上 |
| pkg.go.dev | `go install .../coglog-cli@v0.9.1` | `go install .../coglog-mcp@v0.9.1` |
| NuGet | `dotnet tool install -g coglog` | `dotnet tool install -g coglog-mcp` |

Quicklisp リカレントクワイン版: `(ql:quickload :coglog-quine)`

### インストール後のコマンド（全言語共通）

| コマンド | 動作 |
|---|---|
| `coglog-cli read` | 直前ターンのメタログを読み出し |
| `coglog-cli write` | stdin から JSON を読んで書き込み |
| `coglog-cli clear` | メタログをリセット |
| `coglog-mcp` | MCP サーバーを起動（stdio） |

---

## モノレポ構成

```
coglog/
├── README.md
├── LICENSE
├── THIRD_PARTY_LICENSES.md
│
├── rust/                               # ── crates.io ──
│   ├── Cargo.toml                      # [workspace]
│   ├── coglog-core/
│   │   ├── Cargo.toml
│   │   └── src/lib.rs                  # CogLog コア + データ型 + テスト
│   ├── coglog/
│   │   ├── Cargo.toml
│   │   ├── README.md
│   │   └── src/main.rs                 # CLI エントリポイント
│   └── coglog-mcp/
│       ├── Cargo.toml
│       ├── README.md
│       └── src/main.rs                 # MCP サーバー
│
├── node/                               # ── npm ──
│   ├── coglog/
│   │   ├── package.json
│   │   ├── index.mjs                   # CogLog クラス + CLI
│   │   ├── index.d.mts                 # TypeScript 型定義
│   │   └── README.md
│   └── coglog-mcp/
│       ├── package.json
│       ├── index.mjs                   # CogLog クラス（複製）+ MCP サーバー
│       ├── index.d.mts                 # TypeScript 型定義
│       └── README.md
│
├── python/                             # ── PyPI ──
│   ├── coglog/
│   │   ├── pyproject.toml
│   │   ├── README.md
│   │   └── src/coglog/
│   │       ├── __init__.py             # CogLog クラス + SCHEMA
│   │       └── __main__.py             # CLI エントリポイント
│   └── coglog-mcp/
│       ├── pyproject.toml
│       ├── README.md
│       └── src/coglog_mcp/
│           ├── __init__.py             # CogLog クラス（複製）+ MCP サーバー
│           └── __main__.py             # エントリポイント
│
├── go/                                 # ── pkg.go.dev ──
│   ├── go.mod                          # module github.com/HarmoniaEpic/coglog/go
│   ├── coglog.go                       # CogLog コア + データ型
│   ├── coglog_test.go                  # テスト
│   ├── cmd/
│   │   ├── coglog-cli/
│   │   │   ├── main.go                 # CLI エントリポイント
│   │   │   └── README.md
│   │   └── coglog-mcp/
│   │       ├── main.go                 # MCP サーバー
│   │       └── README.md
│   └── README.md
│
├── ruby/                               # ── RubyGems ──
│   ├── coglog/
│   │   ├── coglog.gemspec
│   │   ├── README.md
│   │   ├── lib/coglog.rb               # CogLog クラス + CLI
│   │   └── bin/coglog-cli              # 実行ファイルエントリポイント
│   └── coglog-mcp/
│       ├── coglog-mcp.gemspec
│       ├── README.md
│       ├── lib/coglog_mcp.rb           # CogLog クラス（複製）+ MCP サーバー
│       └── bin/coglog-mcp              # 実行ファイルエントリポイント
│
├── java/                               # ── Maven Central ──
│   ├── coglog/
│   │   ├── pom.xml
│   │   ├── README.md
│   │   └── src/main/java/
│   │       └── io/github/harmoniaepic/coglog/
│   │           ├── CogLog.java         # CogLog コア + データ型
│   │           └── Main.java           # CLI エントリポイント
│   └── coglog-mcp/
│       ├── pom.xml
│       ├── README.md
│       └── src/main/java/
│           └── io/github/harmoniaepic/coglog/mcp/
│               ├── CogLog.java         # CogLog クラス（複製）
│               └── McpServer.java      # MCP サーバー
│
├── csharp/                             # ── NuGet ──
│   ├── coglog/
│   │   ├── coglog.csproj
│   │   ├── README.md
│   │   ├── CogLog.cs                   # CogLog コア + データ型
│   │   └── Program.cs                  # CLI エントリポイント
│   └── coglog-mcp/
│       ├── coglog-mcp.csproj
│       ├── README.md
│       ├── CogLog.cs                   # CogLog クラス（複製）
│       └── Program.cs                  # MCP サーバー
│
├── haskell/                            # ── Hackage ──
│   ├── coglog/
│   │   ├── coglog.cabal
│   │   ├── README.md
│   │   ├── CogLog.lhs                 # Literate Haskell 純粋核（複製）
│   │   └── Adapter.hs                 # JSON + ファイル I/O + CLI
│   └── coglog-mcp/
│       ├── coglog-mcp.cabal
│       ├── README.md
│       ├── CogLog.lhs                 # Literate Haskell 純粋核（複製）
│       └── McpServer.hs               # MCP サーバー（import CogLog）
│
├── common-lisp/                        # ── Quicklisp ──
│   ├── coglog/
│   │   ├── coglog.asd
│   │   ├── README.md
│   │   ├── coglog.lisp                 # 純粋核
│   │   └── adapter.lisp               # JSON + ファイル I/O + CLI
│   ├── coglog-mcp/
│   │   ├── coglog-mcp.asd
│   │   ├── README.md
│   │   └── mcp-server.lisp            # MCP サーバー（load coglog.lisp）
│   └── coglog-quine/
│       ├── coglog-quine.asd
│       ├── README.md
│       └── recurrent-quine.lisp        # 自己書き換え版
│
├── cpp/                                # ── GitHub Releases（cosmocc）──
│   ├── coglog/
│   │   ├── coglog-cli.cpp              # CLI 版シングルファイル
│   │   └── README.md
│   └── coglog-mcp/
│       ├── coglog-mcp.cpp              # MCP サーバー版シングルファイル
│       └── README.md
│
├── bash/                               # ── リポジトリ同梱（CLI のみ）──
│   └── coglog/
│       ├── coglog-cli.sh               # bash + jq グルー実装
│       └── README.md
│
├── coglog-skill/                       # ── Claude Skill ──
│   └── coglog/
│       ├── SKILL.md
│       ├── references/
│       │   └── DESIGN.md
│       └── scripts/
│           └── coglog.py
│
├── .github/
│   └── workflows/
│       ├── release-cpp.yml             # C++ cosmocc ビルド + リリース
│       └── release-bash.yml            # Bash スクリプトパッケージ + リリース
│
└── docs/
    ├── designs/
    │   └── DESIGN-v0.9.1.md            # 設計書
    ├── oldsources/
    │   ├── coglog-cli-v0_9_1_qjs.js    # QuickJS CLI 版（アーカイブ）
    │   └── coglog-mcp-v0_9_1_qjs.js    # QuickJS MCP 版（アーカイブ）
    ├── plans/
    │   └── PLAN-release-v0.9.1.md      # ← 本文書
    └── coglog-research-notes-01.md     # 研究ノート
```

---

## 既存ファイルの移動

（既存6言語は変更なし。前版の対応表をそのまま維持）

### Python

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `coglog-cli.py` | `python/coglog/src/coglog/__init__.py` | CLI 部分を `main()` 関数に抽出 |
| — | `python/coglog/src/coglog/__main__.py` | 新規（3行） |
| `coglog-mcp.py` | `python/coglog-mcp/src/coglog_mcp/__init__.py` | 同上 |
| — | `python/coglog-mcp/src/coglog_mcp/__main__.py` | 新規（3行） |

### Node.js

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `coglog-cli.mjs` | `node/coglog/index.mjs` | ファイル名のみ |
| — | `node/coglog/index.d.mts` | **新規作成**（TypeScript 型定義） |
| `coglog-mcp.mjs` | `node/coglog-mcp/index.mjs` | ファイル名のみ |
| — | `node/coglog-mcp/index.d.mts` | **新規作成**（TypeScript 型定義） |

### Rust

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `src/lib.rs` | `rust/coglog-core/src/lib.rs` | 移動のみ |
| `src/bin/coglog-cli.rs` | `rust/coglog/src/main.rs` | `use coglog::` → `use coglog_core::` |
| `src/bin/coglog-mcp.rs` | `rust/coglog-mcp/src/main.rs` | 同上 |

### Haskell

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `CogLog.lhs` | `haskell/coglog/CogLog.lhs` | 複製 |
| `CogLog.lhs` | `haskell/coglog-mcp/CogLog.lhs` | 複製 |
| `Adapter.hs` | `haskell/coglog/Adapter.hs` | 移動のみ |
| — | `haskell/coglog-mcp/McpServer.hs` | **新規作成** |

### Common Lisp

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `coglog.lisp` | `common-lisp/coglog/coglog.lisp` | 移動のみ |
| `adapter.lisp` | `common-lisp/coglog/adapter.lisp` | 移動のみ |
| `recurrent-quine.lisp` | `common-lisp/coglog-quine/recurrent-quine.lisp` | 移動のみ |
| — | `common-lisp/coglog-mcp/mcp-server.lisp` | **新規作成** |

### C++

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `coglog-cli-v0.9.1.cpp` | `cpp/coglog/coglog-cli.cpp` | ファイル名のみ |
| `coglog-mcp-v0.9.1.cpp` | `cpp/coglog-mcp/coglog-mcp.cpp` | ファイル名のみ |

### QuickJS（アーカイブ）

| 現在 | 移動先 | 変更内容 |
|---|---|---|
| `coglog-cli-v0_9_1_qjs.js` | `docs/oldsources/coglog-cli-v0_9_1_qjs.js` | アーカイブ（リリース対象外） |
| `coglog-mcp-v0_9_1_qjs.js` | `docs/oldsources/coglog-mcp-v0_9_1_qjs.js` | アーカイブ（リリース対象外） |

---

## 新規実装（5言語 + Haskell/CL MCP）

### Go（全体が新規）

```
go/
├── go.mod              # module github.com/HarmoniaEpic/coglog/go
├── coglog.go           # CogLog 構造体 + advance + read/write/clear + validation
├── coglog_test.go      # テスト
├── cmd/coglog-cli/main.go      # CLI
└── cmd/coglog-mcp/main.go      # MCP サーバー
```

**構造の特徴:**
- 単一 Go モジュール、2つのコマンド
- `go install github.com/HarmoniaEpic/coglog/go/cmd/coglog-cli@v0.9.1` でバイナリ即取得
- 外部依存なし（標準ライブラリのみ: `encoding/json`, `os`, `time`, `bufio`）
- `coglog.go` がライブラリとしても import 可能

**見積もり:**

| ファイル | 行数 |
|---|---|
| coglog.go（コア） | ~250行 |
| coglog_test.go | ~80行 |
| cmd/coglog-cli/main.go（CLI） | ~80行 |
| cmd/coglog-mcp/main.go（MCP） | ~200行 |
| **合計** | **~610行** |

### Ruby（全体が新規）

```
ruby/
├── coglog/
│   ├── coglog.gemspec
│   ├── lib/coglog.rb           # CogLog クラス + CLI ロジック
│   └── bin/coglog-cli          # #!/usr/bin/env ruby + require + main
└── coglog-mcp/
    ├── coglog-mcp.gemspec
    ├── lib/coglog_mcp.rb       # CogLog クラス（複製）+ MCP サーバー
    └── bin/coglog-mcp          # #!/usr/bin/env ruby + require + main
```

**構造の特徴:**
- 外部 gem 依存なし（標準ライブラリ: `json`, `time`, `fileutils`）
- CogLog クラスを各 gem に複製（Python / Node.js と同じ方針）
- `gem install coglog` → `coglog-cli read` で即使用

**見積もり:**

| ファイル | 行数 |
|---|---|
| lib/coglog.rb（CLI） | ~250行 |
| bin/coglog-cli | ~5行 |
| lib/coglog_mcp.rb（MCP） | ~350行 |
| bin/coglog-mcp | ~5行 |
| **合計** | **~610行** |

### Java（全体が新規）

```
java/
├── coglog/
│   ├── pom.xml
│   └── src/main/java/io/github/harmoniaepic/coglog/
│       ├── CogLog.java         # CogLog コア + データ型 + validation
│       └── Main.java           # CLI エントリポイント
└── coglog-mcp/
    ├── pom.xml
    └── src/main/java/io/github/harmoniaepic/coglog/mcp/
        ├── CogLog.java         # CogLog クラス（複製）
        └── McpServer.java      # MCP サーバー
```

**構造の特徴:**
- 外部依存なし（JDK 11+ 標準ライブラリ: `javax.json` は使わず手書き JSON）
- Maven で fat JAR をビルドし、CLI として `java -jar coglog-0.9.1.jar read`
- Maven Central への公開は Sonatype OSSRH 経由
- groupId: `io.github.harmoniaepic`

**JSON 処理の方針:** Python / Node.js / Rust と同じくパーサーを手書きする。CogLog の JSON 構造は固定的であり、外部ライブラリ不要。Jackson / Gson を入れると依存が膨らむ。

**見積もり:**

| ファイル | 行数 |
|---|---|
| CogLog.java（コア）× 2（複製） | ~350行 × 2 |
| Main.java（CLI） | ~80行 |
| McpServer.java（MCP） | ~250行 |
| **合計** | **~1030行** |

### C#（全体が新規）

```
csharp/
├── coglog/
│   ├── coglog.csproj
│   ├── CogLog.cs               # CogLog コア + データ型 + validation
│   └── Program.cs              # CLI エントリポイント
└── coglog-mcp/
    ├── coglog-mcp.csproj
    ├── CogLog.cs               # CogLog クラス（複製）
    └── Program.cs              # MCP サーバー
```

**構造の特徴:**
- 外部依存なし（.NET 8+ 標準ライブラリ: `System.Text.Json`）
- `dotnet tool install -g coglog` で CLI としてインストール（コマンド名は `coglog-cli`）
- NuGet で配布。`.csproj` に `<PackAsTool>true</PackAsTool>` を指定
- TargetFramework: `net8.0`

**見積もり:**

| ファイル | 行数 |
|---|---|
| CogLog.cs（コア）× 2（複製） | ~300行 × 2 |
| Program.cs（CLI） | ~70行 |
| Program.cs（MCP） | ~220行 |
| **合計** | **~890行** |

### Bash（全体が新規・CLI のみ）

```
bash/
└── coglog/
    └── coglog-cli.sh           # bash + jq グルー実装（単一ファイル）
```

**構造の特徴:**
- 外部依存: jq のみ（ランタイム依存ゼロの静的バイナリ、全主要 OS のパッケージマネージャで配布）
- jq 未検出時に OS 判定してインストールコマンドを案内（apt, apk, dnf, pacman, brew, winget）
- アトミック書き込み（mktemp + mv）— 他の言語実装にはない安全策
- `COGLOG_DIR` 環境変数でデータディレクトリをオーバーライド可能
- MCP サーバーは実装しない（POSIX shell では Content-Length フレーミングの実用的な実装が不可能なため）

**照射するもの:**
CogLog の全操作が `jq` + POSIX ユーティリティ（`date`, `mkdir`, `rm`, `mv`, `mktemp`）のパイプラインに分解できること。グルー言語として「つなぐ対象」が jq しかないという事実が、CogLog の本質的単純さの証明になる。

**見積もり:**

| ファイル | 行数 |
|---|---|
| coglog-cli.sh | ~280行 |
| **合計** | **~280行** |

### Haskell MCP サーバー（McpServer.hs）

既存の CogLog.lhs（純粋核）を import。MCP の JSON-RPC 層を IO モナド内で実装。

```haskell
advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry   -- IO なし（CogLog.lhs）
handleToolsCall :: CogLog -> Value -> IO Value            -- IO あり（McpServer.hs）
```

**見積もり:** ~220行

### Common Lisp MCP サーバー（mcp-server.lisp）

coglog.lisp（純粋核）を load。JSON 層は adapter.lisp から複製。

**見積もり:** ~320行

---

## 設定ファイル詳細

### 1. Rust — Cargo workspace

（前版と同一のため省略。workspace 3クレート構成を維持）

### 2. npm

（前版と同一。`"types": "./index.d.mts"` を含む）

**TypeScript 型定義:** 各パッケージに `index.d.mts` を同梱。TypeScript プロジェクトから `import { CogLog } from 'coglog'` した際に型補完が効く。型定義は `CogLog` クラス、`Entry`、`WriteArgs`、`ClearResult`、`Schema` 等の公開インターフェースをカバーする。

### 3. PyPI

（前版と同一。hatchling ベース）

### 4. Hackage

（前版と同一。CogLog.lhs は各パッケージに複製し `cabal sdist` で自己完結）

### 5. Quicklisp (ASDF)

（前版と同一。3パッケージ: coglog, coglog-mcp, coglog-quine）

### 6. Go — go.mod

**`go/go.mod`**

```
module github.com/HarmoniaEpic/coglog/go

go 1.21
```

外部依存なし。`require` 行が存在しない。

Go モジュールはレジストリへの「公開」操作が不要。GitHub にタグ `go/v0.9.1` を打つと pkg.go.dev が自動的にインデックスする。

**インストール:**

```bash
go install github.com/HarmoniaEpic/coglog/go/cmd/coglog-cli@v0.9.1
go install github.com/HarmoniaEpic/coglog/go/cmd/coglog-mcp@v0.9.1
```

**バージョンタグ:** Go のサブモジュール慣習に従い、タグは `go/v0.9.1` とする（ルートの `v0.9.1` とは別）。

### 7. RubyGems — gemspec

**`ruby/coglog/coglog.gemspec`**

```ruby
Gem::Specification.new do |s|
  s.name        = "coglog"
  s.version     = "0.9.1"
  s.summary     = "CogLog — a meta-cognition log for LLMs"
  s.description = "CogLog provides scaffolding for temporal cognition mimicry in LLMs."
  s.authors     = ["HarmoniaEpic"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/HarmoniaEpic/coglog"
  s.metadata    = { "source_code_uri" => "https://github.com/HarmoniaEpic/coglog/tree/main/ruby/coglog" }

  s.required_ruby_version = ">= 3.0"
  s.files       = ["lib/coglog.rb"]
  s.executables = ["coglog-cli"]
  s.require_paths = ["lib"]
end
```

**`ruby/coglog-mcp/coglog-mcp.gemspec`**

```ruby
Gem::Specification.new do |s|
  s.name        = "coglog-mcp"
  s.version     = "0.9.1"
  s.summary     = "CogLog MCP server — a meta-cognition log for LLMs"
  s.description = "MCP (Model Context Protocol) server for CogLog."
  s.authors     = ["HarmoniaEpic"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/HarmoniaEpic/coglog"
  s.metadata    = { "source_code_uri" => "https://github.com/HarmoniaEpic/coglog/tree/main/ruby/coglog-mcp" }

  s.required_ruby_version = ">= 3.0"
  s.files       = ["lib/coglog_mcp.rb"]
  s.executables = ["coglog-mcp"]
  s.require_paths = ["lib"]
end
```

**外部 gem 依存: なし。**

### 8. Maven Central — pom.xml

**`java/coglog/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>io.github.harmoniaepic</groupId>
  <artifactId>coglog</artifactId>
  <version>0.9.1</version>
  <packaging>jar</packaging>

  <name>CogLog</name>
  <description>CogLog — a meta-cognition log for LLMs</description>
  <url>https://github.com/HarmoniaEpic/coglog</url>

  <licenses>
    <license>
      <name>MIT License</name>
      <url>https://opensource.org/licenses/MIT</url>
    </license>
  </licenses>

  <properties>
    <maven.compiler.source>11</maven.compiler.source>
    <maven.compiler.target>11</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
  </properties>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-jar-plugin</artifactId>
        <configuration>
          <archive>
            <manifest>
              <mainClass>io.github.harmoniaepic.coglog.Main</mainClass>
            </manifest>
          </archive>
        </configuration>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-shade-plugin</artifactId>
        <version>3.5.1</version>
        <executions>
          <execution>
            <phase>package</phase>
            <goals><goal>shade</goal></goals>
          </execution>
        </executions>
      </plugin>
    </plugins>
  </build>
</project>
```

coglog-mcp の pom.xml も同構造（artifactId, mainClass が異なる）。

**外部依存: なし。** JSON 処理は手書き（JDK 標準ライブラリのみ）。

**Maven Central 公開:** Sonatype OSSRH 経由。GPG 署名 + Sonatype アカウントが必要。`mvn deploy` で公開。

**CLI 実行:** `java -jar coglog-0.9.1.jar read`

### 9. NuGet — .csproj

**`csharp/coglog/coglog.csproj`**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <PackAsTool>true</PackAsTool>
    <ToolCommandName>coglog-cli</ToolCommandName>
    <PackageId>coglog</PackageId>
    <Version>0.9.1</Version>
    <Description>CogLog — a meta-cognition log for LLMs</Description>
    <Authors>HarmoniaEpic</Authors>
    <License>MIT</License>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <RepositoryUrl>https://github.com/HarmoniaEpic/coglog</RepositoryUrl>
    <PackageTags>metacognition;llm;cognitive;log;mcp;ai</PackageTags>
  </PropertyGroup>
</Project>
```

**`csharp/coglog-mcp/coglog-mcp.csproj`**

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <PackAsTool>true</PackAsTool>
    <ToolCommandName>coglog-mcp</ToolCommandName>
    <PackageId>coglog-mcp</PackageId>
    <Version>0.9.1</Version>
    <Description>CogLog MCP server — a meta-cognition log for LLMs</Description>
    <Authors>HarmoniaEpic</Authors>
    <License>MIT</License>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <RepositoryUrl>https://github.com/HarmoniaEpic/coglog</RepositoryUrl>
    <PackageTags>metacognition;llm;cognitive;log;mcp;mcp-server;ai</PackageTags>
  </PropertyGroup>
</Project>
```

**外部依存: なし。** `System.Text.Json`（.NET 標準ライブラリ）を使用。

**NuGet 公開:** `dotnet pack` → `dotnet nuget push`。NuGet.org アカウント + API キーが必要。

**インストール:** `dotnet tool install -g coglog` → `coglog-cli read`

---

## 純粋核の共有方式（全言語の一覧）

| 言語 | 方式 | 理由 |
|---|---|---|
| **Rust** | coglog-core クレート（構造上の制約） | 型の同一性を保つため必須 |
| **Go** | coglog.go をライブラリとして import | 同一モジュール内なので自然 |
| **Python** | 複製 | 1ファイル完結の方針 |
| **Node.js** | 複製 | 同上 |
| **Ruby** | 複製 | 同上 |
| **Java** | 複製 | 同上 |
| **C#** | 複製 | 同上 |
| **Haskell** | 複製 | cabal sdist の自己完結性 |
| **Common Lisp** | 複製 | 同上 |
| **Bash** | — (jq フィルタ内にインライン) | 純粋核がない。jq がスキーマ生成・エントリ構築を直接担う |

Go だけが Rust とも「複製グループ」とも異なるパターンになる。Go のモジュールシステムでは同一モジュール内のパッケージは自然に import でき、型の同一性も保たれるため。

---

## バージョニング方針

| 対象 | バージョン |
|---|---|
| `_schema.version`（データ形式） | `"0.9.1"` |
| 全20パッケージ | `0.9.1` |

Go のサブモジュールタグのみ `go/v0.9.1` とする（Go の慣習）。

---

## 公開順序

```
Phase 1: crates.io（依存順序あり）
  1. cargo publish -p coglog-core
  2. cargo publish -p coglog
  3. cargo publish -p coglog-mcp

Phase 2: npm（順序制約なし）
  4. cd node/coglog && npm publish
  5. cd node/coglog-mcp && npm publish

Phase 3: PyPI（順序制約なし）
  6. cd python/coglog && python -m build && twine upload dist/*
  7. cd python/coglog-mcp && python -m build && twine upload dist/*

Phase 4: Go（タグのみ）
  8. git tag go/v0.9.1 && git push --tags
     # pkg.go.dev が自動インデックス

Phase 5: RubyGems（順序制約なし）
  9.  cd ruby/coglog && gem build && gem push coglog-0.9.1.gem
  10. cd ruby/coglog-mcp && gem build && gem push coglog-mcp-0.9.1.gem

Phase 6: Maven Central（Sonatype OSSRH）
  11. cd java/coglog && mvn deploy
  12. cd java/coglog-mcp && mvn deploy

Phase 7: NuGet（順序制約なし）
  13. cd csharp/coglog && dotnet pack && dotnet nuget push ...
  14. cd csharp/coglog-mcp && dotnet pack && dotnet nuget push ...

Phase 8: Hackage（順序制約なし）
  15. cd haskell/coglog && cabal sdist && cabal upload ...
  16. cd haskell/coglog-mcp && cabal sdist && cabal upload ...

Phase 9: Quicklisp（審査制・GitHub リポジトリ整備後）
  17. coglog — 取り込みリクエスト
  18. coglog-mcp — 取り込みリクエスト
  19. coglog-quine — 取り込みリクエスト

Phase 10: GitHub Releases
  20. cosmocc ビルドの C++ バイナリ + Bash スクリプト (coglog-cli.sh) をアップロード
```

各 Phase の前に dry-run / check で事前検証。

---

## 変更しないもの

- データ形式（`_schema`, `current.json` の構造）
- バリデーション規則（事実層＝非空必須、解釈層＝空許容）
- CLI インターフェース（read / write / clear）
- MCP プロトコル（JSON-RPC 2.0 over stdio, tools 3種）
- 窓サイズ1・上書きロジック
- Claude Skill パッケージの構成
- CogLog.lhs の純粋核（IO が一切現れないこと）
- coglog.lisp の純粋核

---

## ソースコードの変更・新規作成サマリ

### 既存コードの変更

| ファイル | 変更種別 | 内容 |
|---|---|---|
| `rust/coglog/src/main.rs` | 微修正 | `use coglog::` → `use coglog_core::` |
| `rust/coglog-mcp/src/main.rs` | 微修正 | 同上 |
| `python/coglog/src/coglog/__init__.py` | リファクタ | CLI 部分を `main()` 関数に抽出 |
| `python/coglog-mcp/src/coglog_mcp/__init__.py` | リファクタ | 同上 |

### 新規作成（既存言語の補完）

| ファイル | 行数 |
|---|---|
| `python/coglog/src/coglog/__main__.py` | 3行 |
| `python/coglog-mcp/src/coglog_mcp/__main__.py` | 3行 |
| `node/coglog/index.d.mts` | ~50行 |
| `node/coglog-mcp/index.d.mts` | ~50行 |
| `haskell/coglog-mcp/McpServer.hs` | ~220行 |
| `common-lisp/coglog-mcp/mcp-server.lisp` | ~320行 |

### 新規作成（5言語の全実装）

| 言語 | ファイル数 | 合計行数 |
|---|---|---|
| **Go** | 5 (go.mod, coglog.go, coglog_test.go, 2× main.go) | ~610行 |
| **Ruby** | 6 (2× gemspec, 2× lib, 2× bin) | ~610行 |
| **Java** | 6 (2× pom.xml, 2× CogLog.java, Main.java, McpServer.java) | ~1030行 |
| **C#** | 6 (2× csproj, 2× CogLog.cs, 2× Program.cs) | ~890行 |
| **Bash** | 1 (coglog-cli.sh) | ~280行 |

### 設定ファイル

各パッケージの設定ファイル（Cargo.toml, package.json, pyproject.toml, .cabal, .asd, go.mod, .gemspec, pom.xml, .csproj）と README.md。

### 総見積もり

| カテゴリ | 行数 |
|---|---|
| 新規5言語の実装 | ~3,420行 |
| 既存言語の MCP サーバー新規 | ~540行 |
| TypeScript 型定義 | ~100行 |
| Python __main__.py | ~6行 |
| 設定ファイル + README | ~2,000行 |
| **合計** | **~6,070行** |

---

## 検証チェックリスト

```
【ビルド検証】
 □ cargo test --workspace
 □ cargo build --release（3バイナリ生成）
 □ npm pack --dry-run（coglog, coglog-mcp）
 □ tsc --noEmit で .d.mts の型検証（coglog, coglog-mcp）
 □ python -m build（coglog, coglog-mcp）
 □ twine check dist/*
 □ go build ./...（Go モジュール全体）
 □ go test ./...
 □ gem build（coglog, coglog-mcp）
 □ mvn package（coglog, coglog-mcp）
 □ dotnet build（coglog, coglog-mcp）
 □ dotnet pack（coglog, coglog-mcp）
 □ cabal build（coglog, coglog-mcp）
 □ sbcl --load coglog.asd
 □ bash -n bash/coglog/coglog-cli.sh（構文検証）

【機能検証 — CLI（全11実装）】
 □ Rust:    coglog-cli read/write/clear
 □ Node.js: coglog-cli read/write/clear
 □ Python:  coglog-cli read/write/clear
 □ Go:      coglog-cli read/write/clear
 □ Ruby:    coglog-cli read/write/clear
 □ Java:    java -jar coglog-0.9.1.jar read/write/clear
 □ C#:      coglog-cli read/write/clear（dotnet tool）
 □ C++:     coglog-cli read/write/clear（cosmocc バイナリ）
 □ Haskell: cabal run coglog-cli -- read/write/clear
 □ CL:      sbcl --script adapter.lisp read/write/clear
 □ Bash:    bash coglog-cli.sh read/write/clear（jq 必須）

【機能検証 — MCP（全10実装）】
 □ Rust:    coglog-mcp が initialize ハンドシェイクに応答
 □ Node.js: coglog-mcp が initialize ハンドシェイクに応答
 □ Python:  coglog-mcp が initialize ハンドシェイクに応答
 □ Go:      coglog-mcp が initialize ハンドシェイクに応答
 □ Ruby:    coglog-mcp が initialize ハンドシェイクに応答
 □ Java:    coglog-mcp が initialize ハンドシェイクに応答
 □ C#:      coglog-mcp が initialize ハンドシェイクに応答
 □ C++:     coglog-mcp が initialize ハンドシェイクに応答
 □ Haskell: coglog-mcp が initialize ハンドシェイクに応答
 □ CL:      coglog-mcp が initialize ハンドシェイクに応答

【機能検証 — リカレントクワイン】
 □ sbcl --script recurrent-quine.lisp read
 □ write 後のファイル自身が有効なプログラムとして実行可能
 □ sbcl --script recurrent-quine.lisp clear

【クロス互換性検証（代表的な組み合わせ）】
 □ Rust write    → Python read
 □ Node.js write → Go read
 □ Go write      → Ruby read
 □ Ruby write    → Java read
 □ Java write    → C# read
 □ C# write      → Rust read
 □ Python write  → Haskell read
 □ Haskell write → CL read
 □ CL write      → Node.js read
 □ C++ write     → Go read
 □ Bash write    → Python read
 □ C++ write     → Bash read

【公開前検証】
 □ cargo publish --dry-run（3クレート）
 □ npm publish --dry-run（2パッケージ）
 □ twine check（2パッケージ）
 □ go vet ./...
 □ gem build --strict（2 gem）
 □ mvn verify（2モジュール）
 □ dotnet pack（2パッケージ）
 □ cabal sdist（2パッケージ）
```

---

## 作業順序

```
Phase A: モノレポ構造の構築
  1. ディレクトリ構造を作成
  2. 既存ソースファイルを配置（リネーム・移動）
  3. 既存言語の設定ファイル作成

Phase B: 既存言語の補完
  4. Rust workspace 分割 + use 文修正
  5. Python __init__.py / __main__.py 分離
  6. Node.js TypeScript 型定義（.d.mts）
  7. Haskell MCP サーバー (McpServer.hs)
  8. Common Lisp MCP サーバー (mcp-server.lisp)

Phase C: 新規言語の実装
  9.  Go（コア + CLI + MCP + テスト）
  10. Ruby（CLI + MCP）
  11. Java（CLI + MCP）
  12. C#（CLI + MCP）
  13. Bash（CLI のみ — 実装済み）

Phase D: 設定ファイル + README
  14. 新規5言語の設定ファイル
  15. 全パッケージの README.md
  16. ルート README.md 更新

Phase E: 検証
  17. 全言語 CLI 検証
  18. 全言語 MCP 検証
  19. クロス互換性検証

Phase F: 公開
  20. crates.io（coglog-core → coglog → coglog-mcp）
  21. npm（coglog, coglog-mcp）
  22. PyPI（coglog, coglog-mcp）
  23. Go（タグ push → pkg.go.dev 自動インデックス）
  24. RubyGems（coglog, coglog-mcp）
  25. Maven Central（coglog, coglog-mcp）
  26. NuGet（coglog, coglog-mcp）
  27. Hackage（coglog, coglog-mcp）
  28. Quicklisp（coglog, coglog-mcp, coglog-quine）
  29. GitHub Releases（C++ cosmocc バイナリ + Bash スクリプト）
```
