# CogLog v0.9.1 パス解決仕様

## 概要

CogLog はデータを単一のディレクトリ（データディレクトリ）内の `current.json` に保存する。本文書はデータディレクトリの解決規則を定める。

---

## 共通仕様

### データファイル

```
<データディレクトリ>/current.json
```

ファイル名は `current.json` 固定。全言語共通。

### 解決の優先順位

```
1. 明示的指定（最優先）
       │
       ▼ 未指定の場合
2. COGLOG_DIR 環境変数
       │
       ▼ 未設定の場合
3. ホームディレクトリ/.coglog
       │
       ▼ ホームディレクトリが取得できない場合
4. ./.coglog（カレントディレクトリ。最終フォールバック）
```

### 各段階の定義

**1. 明示的指定**

利用者が直接データディレクトリを指定する。指定方法は利用形態によって異なる。

| 利用形態 | 指定方法 |
|---|---|
| CLI | `--coglog-dir <path>` 引数 |
| ライブラリ / モジュール | コンストラクタ引数・ファクトリ関数引数 |
| MCP サーバー | `--coglog-dir <path>` 引数 |

明示的指定がある場合、環境変数とデフォルトは無視する。

**2. COGLOG_DIR 環境変数**

環境変数 `COGLOG_DIR` が設定されている場合、その値をデータディレクトリとして使う。空文字列は「未設定」と同等に扱い、次の段階に進む。

**3. ホームディレクトリ/.coglog**

各言語の標準的なホームディレクトリ取得方法で `$HOME/.coglog` に相当するパスを構築する。

**4. 最終フォールバック**

ホームディレクトリが取得できない環境（一部のコンテナ、サンドボックス等）では、カレントディレクトリの `.coglog` をデータディレクトリとする。

### ディレクトリの自動作成

write 時にデータディレクトリが存在しない場合、自動的に作成する。中間ディレクトリも含む（`mkdir -p` 相当）。read と clear はディレクトリを作成しない。

---

## 言語別の実装指針

共通仕様の4段階を基本とし、言語の標準様式と衝突する場合は言語の標準様式を採用する。

### 衝突しない言語

以下の言語は共通仕様の4段階をそのまま実装する。

| 言語 | 明示的指定 | ホームディレクトリ取得 | フォールバック |
|---|---|---|---|
| Rust | `--coglog-dir` / `MetaLog::with_dir()` | `std::env::var("HOME")` | `./.coglog` |
| Go | `--coglog-dir` / `NewWithDir()` | `os.UserHomeDir()` | `./.coglog` |
| C++ | `--coglog-dir` / `init_paths()` | `$HOME` → `getpwuid()` | `./.coglog` |
| Node.js | `--coglog-dir` / コンストラクタ | `os.homedir()` | `./.coglog` |
| Python (PyPI) | `--coglog-dir` / コンストラクタ | `Path.home()` | — ※後述 |
| Ruby | `--coglog-dir` / コンストラクタ | `Dir.home` | `./.coglog` |

### 言語標準様式が優先される場合

**Haskell**

Haskell の `System.Directory.getHomeDirectory` は `HOME` 環境変数が未設定の場合に例外を投げる。フォールバックとして `getCurrentDirectory` を使い `.coglog` を付加する。

**Java**

Java では `System.getProperty("user.home")` がホームディレクトリの標準的な取得方法。`$HOME` 環境変数は直接参照しない。`user.home` はJVM起動時に必ず設定されるため、フォールバックに到達する可能性は極めて低い。

```
1. --coglog-dir 引数
2. COGLOG_DIR 環境変数 (System.getenv)
3. System.getProperty("user.home") + "/.coglog"
4. "./.coglog"
```

**C#**

.NET では `Environment.GetFolderPath(SpecialFolder.UserProfile)` が標準。`$HOME` は Linux/macOS では通常一致するが、Windows では `%USERPROFILE%` に対応する。

```
1. --coglog-dir 引数
2. COGLOG_DIR 環境変数 (Environment.GetEnvironmentVariable)
3. Environment.GetFolderPath(SpecialFolder.UserProfile) + "/.coglog"
4. "./.coglog"
```

**Bash**

シェルスクリプトでは `--coglog-dir` のような引数解析は一般的でなく、環境変数による制御が POSIX の標準様式。

```
1. COGLOG_DIR 環境変数（${COGLOG_DIR:-${HOME}/.coglog}）
2. $HOME/.coglog
```

CLI 引数による明示的指定は提供しない。フォールバックも省略する（`$HOME` が未設定の環境でシェルスクリプトを実行する想定がない）。

**Common Lisp**

SBCL では `(user-homedir-pathname)` がホームディレクトリの標準取得方法。処理系によって挙動が異なるため、SBCL 依存を明示する。

**Python (Skill版)**

Claude サンドボックス内で使われる前提のため、`COGLOG_DIR` 環境変数と `--coglog-dir` 引数は省略し、`Path.home() / ".coglog"` 固定とする。サンドボックス外で使う場合は PyPI 版を使用する。

---

## OS 固有の配置規則

XDG やその他の OS 固有の配置規則に従う必要がある場合は、`COGLOG_DIR` 環境変数で対応できる。

```bash
COGLOG_DIR=$XDG_DATA_HOME/coglog coglog-cli read          # Linux XDG
COGLOG_DIR=~/Library/Application\ Support/coglog coglog-cli read  # macOS
set COGLOG_DIR=%APPDATA%\coglog && coglog-cli read        # Windows cmd
```

---

## 一覧

| 言語 | 段階1（明示的指定） | 段階2（COGLOG_DIR） | 段階3（ホーム） | 段階4（フォールバック） |
|---|---|---|---|---|
| Rust | `--coglog-dir` / `with_dir()` | ✓ | `$HOME` | `./.coglog` |
| Go | `--coglog-dir` / `NewWithDir()` | ✓ | `UserHomeDir()` | `./.coglog` |
| Python (PyPI) | `--coglog-dir` / コンストラクタ | ✓ | `Path.home()` | — |
| Python (Skill) | — | — | `Path.home()` | — |
| Node.js | `--coglog-dir` / コンストラクタ | ✓ | `os.homedir()` | `./.coglog` |
| C++ | `--coglog-dir` / `init_paths()` | ✓ | `$HOME` → `getpwuid()` | `./.coglog` |
| Ruby | `--coglog-dir` / コンストラクタ | ✓ | `Dir.home` | `./.coglog` |
| Java | `--coglog-dir` / コンストラクタ | ✓ | `user.home` プロパティ | `./.coglog` |
| C# | `--coglog-dir` / コンストラクタ | ✓ | `SpecialFolder.UserProfile` | `./.coglog` |
| Haskell | `--coglog-dir` / 引数 | ✓ | `getHomeDirectory` | `getCurrentDirectory` |
| Common Lisp | `--coglog-dir` / 引数 | ✓ | `user-homedir-pathname` | `./.coglog` |
| Bash | — | ✓ | `$HOME` | — |
