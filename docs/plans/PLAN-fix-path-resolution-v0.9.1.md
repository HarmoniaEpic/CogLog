# PLAN: SPEC-path-resolution-v0.9.1 違反の修正

**ステータス:** 未着手
**対象仕様:** `docs/designs/SPEC-path-resolution-v0.9.1.md`
**作成日:** 2026-03-07

---

## スコープ外: Recurrent Quine（`common-lisp/coglog-quine/`）

### Recurrent Quine とは何か

`common-lisp/coglog-quine/recurrent-quine.lisp` は、CogLog の漸化式 $a_{n+1} = f(a_n, x_n, y_n)$ を **ファイル自己書き換え** として実装したプログラムである。他の全実装（CLI / MCP）がデータディレクトリ内の `current.json` を読み書きするのに対し、Recurrent Quine は **このファイル自身がプログラムであると同時に状態** であり、`write` コマンドはファイル自身を次世代 $Q_{n+1}$ として上書きする。

```
他の全実装:   プログラム → current.json を読み書き
Recurrent Quine:  recurrent-quine.lisp が自分自身を書き換える
```

内部構造は四つ組として設計されている:

| 成分 | 役割 | 変異頻度 |
|------|------|---------|
| `*state*` | 現在のエントリ（表現型） | 毎世代 |
| `*advance-source*` | 変換規則（構造遺伝子） | オプション引数で許容 |
| `*affordance*` | LLM への案内（調節配列） | オプション引数で許容 |
| `*self-source*` | 自己複製機構（DNA ポリメラーゼ） | 事実上不変 |

`write-generation` 関数が `*self-path*`（= `*load-truename*`、つまり自分自身の絶対パス）に四つ組を書き出すことで、各世代がスタンドアロンで動作する完全なプログラムとして再生成される。

### なぜ本計画のスコープ外か

SPEC-path-resolution-v0.9.1 は **データディレクトリの解決規則** を定める仕様である:

> CogLog はデータを単一のディレクトリ（データディレクトリ）内の `current.json` に保存する。本文書はデータディレクトリの解決規則を定める。
> — SPEC-path-resolution-v0.9.1.md, L5

Recurrent Quine はこの前提そのものに該当しない:

1. **データディレクトリが存在しない。** Recurrent Quine にはデータディレクトリという概念がない。状態は `current.json` ではなく `.lisp` ファイル自身に埋め込まれている。パス解決の4段階（明示的指定 → `COGLOG_DIR` → ホームディレクトリ → フォールバック）が適用される対象自体が不在である。

2. **書き込み先はプログラム自身。** `*self-path*` は `*load-truename*`（SBCL の `--script` モードで自動設定されるファイル自身の絶対パス）であり、環境変数やコマンドライン引数で解決されるものではない。

3. **仕様の言語別テーブルに含まれていない。** SPEC-path-resolution-v0.9.1 の一覧テーブル（L146-159）は Common Lisp の通常の CLI/MCP 実装（`common-lisp/coglog/`, `common-lisp/coglog-mcp/`）を対象としており、Recurrent Quine は列挙されていない。

したがって、本計画の違反分析および修正対象から Recurrent Quine を除外する。

---

## 違反一覧

| ID | 違反内容 | 影響範囲 | 深刻度 |
|----|---------|---------|--------|
| V1 | `COGLOG_DIR=""` を未設定として扱わない | 7言語 14ファイル | 中 |
| V2 | Python MCP に `--coglog-dir` 引数がない | 1ファイル | 中 |
| V3 | Haskell — `getHomeDirectory` 失敗時のフォールバック欠落 | CLI・MCP 2ファイル | 低 |
| V4 | Common Lisp — 段階4 `./.coglog` フォールバック欠落 | CLI・MCP 2ファイル | 低 |
| V5 | C++ — `mkdir` が非再帰的 | CLI・MCP 2ファイル | 低 |

---

## V1: COGLOG_DIR 空文字列の未処理

### 仕様

> 空文字列は「未設定」と同等に扱い、次の段階に進む。
> — SPEC-path-resolution-v0.9.1.md, L50

### 原因

各言語の truthiness セマンティクスに依存したコードを書いており、空文字列を明示的に除外していない。

### 準拠済みの実装（参考パターン）

| 言語 | コード | なぜ正しいか |
|------|--------|-------------|
| Go | `if d := os.Getenv("COGLOG_DIR"); d != ""` | 明示的な空判定 |
| Java | `if (env != null && !env.isEmpty())` | null と空を両方排除 |
| C# | `if (!string.IsNullOrEmpty(env))` | 同上 |
| Bash | `${COGLOG_DIR:-${HOME}/.coglog}` | `:-` は空文字列も未設定扱い |

### 修正対象（14ファイル）

#### V1-1. Python CLI

- **ファイル:** `python/coglog/src/coglog/__init__.py`
- **行:** L33-34
- **現状:**
  ```python
  DATA_DIR = Path(os.environ["COGLOG_DIR"]) if "COGLOG_DIR" in os.environ \
             else Path.home() / ".coglog"
  ```
- **問題:** `COGLOG_DIR=""` のとき `Path("")` が使われる
- **修正方針:** `os.environ.get("COGLOG_DIR")` を使い、truthy チェックを追加
  ```python
  _env = os.environ.get("COGLOG_DIR")
  DATA_DIR = Path(_env) if _env else Path.home() / ".coglog"
  ```

#### V1-2. Python MCP

- **ファイル:** `python/coglog-mcp/src/coglog_mcp/__init__.py`
- **行:** L23-24
- **現状:** V1-1 と同一コード
- **修正方針:** V1-1 と同一

#### V1-3. Node.js CLI

- **ファイル:** `node/coglog/index.mjs`
- **行:** L34
- **現状:**
  ```javascript
  const DATA_DIR = process.env.COGLOG_DIR ?? join(homedir(), '.coglog');
  ```
- **問題:** `??` は null/undefined のみフォールスルー。空文字列は有効値として扱われる
- **修正方針:** `||` に変更、または明示的チェック
  ```javascript
  const DATA_DIR = process.env.COGLOG_DIR || join(homedir(), '.coglog');
  ```

#### V1-4. Node.js MCP

- **ファイル:** `node/coglog-mcp/index.mjs`
- **行:** L25
- **現状:** V1-3 と同一コード
- **修正方針:** V1-3 と同一

#### V1-5. Rust (coglog-core)

- **ファイル:** `rust/coglog-core/src/lib.rs`
- **行:** L199-200
- **現状:**
  ```rust
  if let Ok(d) = std::env::var("COGLOG_DIR") {
      return PathBuf::from(d);
  }
  ```
- **問題:** `Ok("")` で空の PathBuf を返す
- **修正方針:** 空文字列ガードを追加
  ```rust
  if let Ok(d) = std::env::var("COGLOG_DIR") {
      if !d.is_empty() {
          return PathBuf::from(d);
      }
  }
  ```

#### V1-6. Ruby CLI

- **ファイル:** `ruby/coglog/lib/coglog.rb`
- **行:** L46
- **現状:**
  ```ruby
  @data_dir = data_dir || (ENV['COGLOG_DIR'] || File.join(Dir.home, '.coglog'))
  ```
- **問題:** Ruby では空文字列は truthy。`"" || x` は `""` を返す
- **修正方針:** `ENV.fetch` + `nil` 変換、または明示チェック
  ```ruby
  env = ENV['COGLOG_DIR']
  env = nil if env&.empty?
  @data_dir = data_dir || env || File.join(Dir.home, '.coglog')
  ```

#### V1-7. Ruby MCP

- **ファイル:** `ruby/coglog-mcp/lib/coglog_mcp.rb`
- **行:** L42
- **現状:** V1-6 と同一コード
- **修正方針:** V1-6 と同一

#### V1-8. C++ CLI

- **ファイル:** `cpp/coglog/coglog-cli.cpp`
- **行:** L410
- **現状:**
  ```cpp
  if (const char* env = std::getenv("COGLOG_DIR")) return env;
  ```
- **問題:** `getenv` はキーが存在すれば空文字列でも非NULL ポインタを返す
- **修正方針:** 長さチェックを追加
  ```cpp
  if (const char* env = std::getenv("COGLOG_DIR")) {
      if (env[0] != '\0') return env;
  }
  ```

#### V1-9. C++ MCP

- **ファイル:** `cpp/coglog-mcp/coglog-mcp.cpp`
- **行:** L399
- **現状:** V1-8 と同一コード
- **修正方針:** V1-8 と同一

#### V1-10. Common Lisp CLI

- **ファイル:** `common-lisp/coglog/adapter.lisp`
- **行:** L18-19
- **現状:**
  ```lisp
  (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
    (if env
  ```
- **問題:** `posix-getenv` は空文字列を返す（NIL ではない）。Lisp では空文字列は truthy
- **修正方針:** 空文字列を明示除外
  ```lisp
  (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
    (if (and env (plusp (length env)))
  ```

#### V1-11. Common Lisp MCP

- **ファイル:** `common-lisp/coglog-mcp/mcp-server.lisp`
- **行:** L21
- **現状:** V1-10 と同一コード
- **修正方針:** V1-10 と同一

#### V1-12. Haskell CLI

- **ファイル:** `haskell/coglog/Adapter.hs`
- **行:** L300-302
- **現状:**
  ```haskell
  envDir <- lookupEnv "COGLOG_DIR"
  case envDir of
    Just d  -> return (d FP.</> "current.json")
  ```
- **問題:** `Just ""` で空パスが使われる
- **修正方針:** パターンマッチでガード
  ```haskell
  case envDir of
    Just d | not (null d) -> return (d FP.</> "current.json")
    _ -> do
  ```

#### V1-13. Haskell MCP

- **ファイル:** `haskell/coglog-mcp/McpServer.hs`
- **行:** L257-264
- **現状:** V1-12 と同一コード
- **修正方針:** V1-12 と同一

---

## V2: Python MCP に `--coglog-dir` 引数がない

### 仕様

> | 利用形態 | 指定方法 |
> |---|---|
> | MCP サーバー | `--coglog-dir <path>` 引数 |
> — SPEC-path-resolution-v0.9.1.md, L44

### 修正対象

- **ファイル:** `python/coglog-mcp/src/coglog_mcp/__init__.py`
- **行:** サーバー起動部（末尾の `main()` 関数付近）
- **現状:** `--coglog-dir` 引数を受け取るコードが存在しない。`DATA_DIR` はモジュールレベルで環境変数のみから決定される
- **修正方針:** 他の MCP 実装（例: Node.js MCP の L243-247）と同等の `--coglog-dir` パースを追加。`sys.argv` から解析し、指定があればグローバルの `DATA_DIR` / `CURRENT_FILE` を上書き

---

## V3: Haskell — `getHomeDirectory` 失敗時のフォールバック欠落

### 仕様

> Haskell の `System.Directory.getHomeDirectory` は `HOME` 環境変数が未設定の場合に例外を投げる。フォールバックとして `getCurrentDirectory` を使い `.coglog` を付加する。
> — SPEC-path-resolution-v0.9.1.md, L87

### 修正対象

#### V3-1. Haskell CLI

- **ファイル:** `haskell/coglog/Adapter.hs`
- **行:** L303-305
- **現状:**
  ```haskell
  Nothing -> do
    home <- getHomeDirectory
    return (home FP.</> ".coglog" FP.</> "current.json")
  ```
- **問題:** `getHomeDirectory` が例外を投げた場合、未処理のまま伝播する
- **修正方針:** `catch` で例外を捕捉し、`getCurrentDirectory` にフォールバック
  ```haskell
  Nothing -> do
    home <- getHomeDirectory `catch` (\(_ :: IOException) -> getCurrentDirectory)
    return (home FP.</> ".coglog" FP.</> "current.json")
  ```

#### V3-2. Haskell MCP

- **ファイル:** `haskell/coglog-mcp/McpServer.hs`
- **行:** L261-264
- **修正方針:** V3-1 と同一

---

## V4: Common Lisp — 段階4 `./.coglog` フォールバック欠落

### 仕様

仕様テーブル（L158）で Common Lisp のフォールバックは `./.coglog` と定義されている。

### 修正対象

#### V4-1. Common Lisp CLI

- **ファイル:** `common-lisp/coglog/adapter.lisp`
- **行:** L16-21
- **現状:**
  ```lisp
  (defun default-coglog-dir ()
    (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
      (if env
          (parse-namestring (concatenate 'string env "/"))
          (merge-pathnames ".coglog/" (user-homedir-pathname)))))
  ```
- **問題:** `user-homedir-pathname` が有効なパスを返せない場合のフォールバックがない
- **修正方針:** `handler-case` で `user-homedir-pathname` の失敗を捕捉し、`.coglog/` にフォールバック

#### V4-2. Common Lisp MCP

- **ファイル:** `common-lisp/coglog-mcp/mcp-server.lisp`
- **行:** L21 付近
- **修正方針:** V4-1 と同一

---

## V5: C++ — `mkdir` が非再帰的

### 仕様

> write 時にデータディレクトリが存在しない場合、自動的に作成する。中間ディレクトリも含む（`mkdir -p` 相当）。
> — SPEC-path-resolution-v0.9.1.md, L62

### 修正対象

#### V5-1. C++ CLI

- **ファイル:** `cpp/coglog/coglog-cli.cpp`
- **行:** L433-436
- **現状:**
  ```cpp
  static void ensure_dir(const std::string& path) {
      if (!file_exists(path)) {
          ::mkdir(path.c_str(), 0755);
      }
  }
  ```
- **問題:** `::mkdir` は1階層のみ。`--coglog-dir /a/b/c/d` のような深いパスで中間ディレクトリが存在しない場合に失敗する
- **修正方針:** パスを `/` で分割して順次作成するループ、またはプラットフォーム API を使用

#### V5-2. C++ MCP

- **ファイル:** `cpp/coglog-mcp/coglog-mcp.cpp`
- **行:** L424 付近
- **修正方針:** V5-1 と同一

---

## 修正順序

作業効率（同一パターンの一括修正）とリスク（影響範囲）を考慮した推奨順序:

| 順序 | 対象 | 理由 |
|------|------|------|
| 1 | **V1** (全14ファイル) | 最多影響。同一パターンの修正を一括で行える |
| 2 | **V2** (Python MCP) | 機能欠損。V1 修正時に Python MCP を触るので併せて対応 |
| 3 | **V5** (C++ CLI・MCP) | データ損失リスク（書き込み先ディレクトリを作成できない） |
| 4 | **V3** (Haskell CLI・MCP) | 特殊環境のみ影響 |
| 5 | **V4** (Common Lisp CLI・MCP) | 特殊環境のみ影響 |

## テスト方針

各修正に対して以下を検証:

1. **V1:** `COGLOG_DIR=""` を設定した状態で `read` を実行し、`~/.coglog/current.json` が参照されることを確認
2. **V2:** `python -m coglog_mcp --coglog-dir /tmp/test` でカスタムパスが使われることを確認
3. **V3:** `HOME` 未設定環境で Haskell CLI/MCP がカレントディレクトリにフォールバックすることを確認
4. **V4:** `user-homedir-pathname` が失敗する環境で `.coglog/` が使われることを確認
5. **V5:** `--coglog-dir /tmp/a/b/c` のような深いパスに対して write が成功することを確認
