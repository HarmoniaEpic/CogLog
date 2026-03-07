# ソースコード バージョン埋め込みの置換容易化計画

> **改訂履歴**
>
> | 日付 | 内容 |
> |------|------|
> | 2026-03-07 | 初版作成 |

## 変更の性質

**リファクタリング** — 実行時の動作に変更なし。ソースコード内のバージョン文字列を機械的に安全に置換できるようマーカーコメントを導入し、コメント/docstring 内の冗長なバージョン記述を削除する。

---

## 背景と課題

現在、バージョン文字列 `0.9.1` は 18 以上のソースファイルに埋め込まれている。これらは以下の 3 種類に分類される。

| 分類 | 説明 | 例 | 置換要否 |
|------|------|-----|---------|
| **A. ランタイム定数** | プログラムが実行時に参照する値 | `VERSION = "0.9.1"` | 必須 |
| **B. コメント/docstring** | ファイルヘッダー、関数説明内のバージョン | `# CogLog v0.9.1 — ...` | 追従が望ましい |
| **C. ドキュメント参照** | 特定ドキュメントのファイル名 | `DESIGN-v0.9.1.md` | 置換禁止 |

### 問題点

1. **分類 A・B・C が同一の文字列** `0.9.1` であり、雑な `sed` で C を誤置換するリスクがある
2. **分類 B が多数存在**し、コメント内バージョンの更新漏れが起きやすい
3. バージョン更新時に **対象ファイルの列挙が手動** であり、新ファイル追加時に漏れが生じうる

---

## 方針

### 1. マーカーコメント `@coglog-version` の導入 (分類 A)

ランタイム定数を含む行の末尾に言語ごとのコメント構文でマーカーを付与する。

### 2. コメント/docstring からのバージョン削除 (分類 B)

ヘッダーコメントや docstring からバージョン番号を除去する。バージョンは定数から参照可能であり、二重管理を排除する。

### 3. ドキュメント参照は変更しない (分類 C)

`DESIGN-v0.9.1.md` 等の特定ドキュメントへの参照はそのまま残す。

---

## 対象ファイル一覧

### 分類 A: マーカーコメント追加

ランタイム定数行の末尾に `@coglog-version` マーカーを追加する。

| 言語 | ファイル | 現状の記述 | 変更後 |
|------|---------|-----------|--------|
| Python | `python/coglog/src/coglog/__init__.py` | `"version": "0.9.1",` | `"version": "0.9.1",  # @coglog-version` |
| Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `"version": "0.9.1",` (SCHEMA) | `"version": "0.9.1",  # @coglog-version` |
| Python | `python/coglog-mcp/src/coglog_mcp/__init__.py` | `"version": "0.9.1",` (SERVER_INFO) | `"version": "0.9.1",  # @coglog-version` |
| Ruby | `ruby/coglog/lib/coglog.rb` | `VERSION = '0.9.1'` | `VERSION = '0.9.1'  # @coglog-version` |
| Ruby | `ruby/coglog-mcp/lib/coglog_mcp.rb` | `VERSION = '0.9.1'` | `VERSION = '0.9.1'  # @coglog-version` |
| Java | `java/coglog/src/.../CogLog.java` | `public static final String VERSION = "0.9.1";` | `public static final String VERSION = "0.9.1";  // @coglog-version` |
| Java | `java/coglog-mcp/src/.../CogLog.java` | `public static final String VERSION = "0.9.1";` | `public static final String VERSION = "0.9.1";  // @coglog-version` |
| Java | `java/coglog-mcp/src/.../McpServer.java` | `"version":"0.9.1"` (JSON文字列内) | `... "0.9.1"...  // @coglog-version` |
| C++ | `cpp/coglog/coglog-cli.cpp` | `schema.set("version", "0.9.1");` | `schema.set("version", "0.9.1");  // @coglog-version` |
| C++ | `cpp/coglog-mcp/coglog-mcp.cpp` | `schema.set("version", "0.9.1");` | `schema.set("version", "0.9.1");  // @coglog-version` |
| C++ | `cpp/coglog-mcp/coglog-mcp.cpp` | `server_info.set("version", "0.9.1");` | `server_info.set("version", "0.9.1");  // @coglog-version` |
| Bash | `bash/coglog/coglog-cli.sh` | `readonly COGLOG_VERSION="0.9.1"` | `readonly COGLOG_VERSION="0.9.1"  # @coglog-version` |
| Bash | `bash/coglog/coglog-cli.sh` | `version: "0.9.1",` (ヒアドキュメント内) | `version: "0.9.1",` + 直前行にマーカーコメント追加 |
| Go | `go/coglog.go` | `Version: "0.9.1",` | `Version: "0.9.1",  // @coglog-version` |
| Go | `go/cmd/coglog-mcp/main.go` | `"version": "0.9.1"` | `"version": "0.9.1",  // @coglog-version` |
| CL | `common-lisp/coglog/coglog.lisp` | `(defparameter +schema-version+ "0.9.1")` | `(defparameter +schema-version+ "0.9.1")  ; @coglog-version` |
| CL | `common-lisp/coglog-mcp/coglog.lisp` | `(defparameter +schema-version+ "0.9.1")` | `(defparameter +schema-version+ "0.9.1")  ; @coglog-version` |
| CL | `common-lisp/coglog-quine/recurrent-quine.lisp` | `'((:version . "0.9.1")` | `'((:version . "0.9.1")  ; @coglog-version` |

### 分類 B: コメント/docstring からバージョン削除

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

### 分類 C: 変更しないファイル

| ファイル | 該当記述 | 理由 |
|---------|---------|------|
| `common-lisp/coglog/coglog.lisp` | `DESIGN-v0.9.1.md` | 特定バージョンのドキュメント参照 |
| `common-lisp/coglog-mcp/coglog.lisp` | `DESIGN-v0.9.1.md` | 同上 |

---

## 置換スクリプトのイメージ

マーカー導入後、将来のバージョン更新は以下のワンライナーで全言語を一括置換できる。

```bash
NEW_VERSION="1.0.0"

# ソースコード内のランタイム定数 (@coglog-version マーカー行のみ対象)
grep -rl '@coglog-version' \
  --include='*.py' --include='*.rb' --include='*.java' \
  --include='*.cpp' --include='*.sh' --include='*.go' \
  --include='*.lisp' . |
  xargs sed -i -E \
    "s/([\"'])([0-9]+\.[0-9]+\.[0-9]+)\1(.*@coglog-version)/\1${NEW_VERSION}\1\3/g"
```

**安全性:**
- `@coglog-version` マーカーがない行は一切変更されない
- `DESIGN-v0.9.1.md` のようなドキュメント参照は構造的に保護される
- 新しいファイルを追加する際、`@coglog-version` を付ければ自動的に対象に含まれる

---

## 作業手順

### Step 1: 分類 B — コメント/docstring からバージョン削除

全対象ファイルのヘッダーコメント・docstring・usage 文字列からバージョン番号を除去する。

**確認:** 各言語のテストを実行し、動作に影響がないことを検証する。

### Step 2: 分類 A — マーカーコメント追加

ランタイム定数を含む行の末尾に `@coglog-version` マーカーを追加する。

**確認:** 各言語のテストを実行し、動作に影響がないことを検証する。

### Step 3: 検証

```bash
# マーカー行の一覧を確認
grep -rn '@coglog-version' --include='*.py' --include='*.rb' \
  --include='*.java' --include='*.cpp' --include='*.sh' \
  --include='*.go' --include='*.lisp' .

# 分類 C (ドキュメント参照) が残っていることを確認
grep -rn 'DESIGN-v0.9.1.md' --include='*.lisp' .

# ソースコード内に残るマーカーなしの "0.9.1" を確認
# (分類 C のドキュメント参照のみが残るはず)
grep -rn '0\.9\.1' --include='*.py' --include='*.rb' \
  --include='*.java' --include='*.cpp' --include='*.sh' \
  --include='*.go' --include='*.lisp' . | grep -v '@coglog-version'
```

---

## リスクと注意点

| リスク | 対策 |
|--------|------|
| Bash ヒアドキュメント内の行はコメントを付与できない | 直前行にマーカーコメントを置く、または `$COGLOG_VERSION` 変数展開に置き換える |
| Java の McpServer.java で JSON 文字列リテラル内にバージョンがある | マーカー付与は行コメントで対応可能。将来的には定数参照に置き換えることも検討 |
| Go の package コメントは godoc に影響する | バージョン削除により godoc の表示が変わるが、バージョンはコード内定数で確認可能 |
| Common Lisp quine はコード自体が出力に関わる | マーカーコメントが quine 出力に含まれないことを確認する |
