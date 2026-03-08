# Ruby bin スタブ require 方式および Go スモークテストコマンドの問題報告

PLAN-version-sync.md、gemspec、bin スタブの実ファイル、および Go モジュール構成を対照して導出。

**作成日:** 2026-03-07

---

## P1. Ruby bin スタブの `require "coglog"` によるソースチェックアウト実行不可

### 発生コミット

`914ab19` (Add Ruby bin entrypoints to gem package files)

### 影響ファイル

| ファイル | 変更内容 |
|---------|---------|
| `ruby/coglog/bin/coglog-cli` | `require_relative '../lib/coglog'` → `require "coglog"` |
| `ruby/coglog-mcp/bin/coglog-mcp` | `require_relative '../lib/coglog_mcp'` → `require "coglog_mcp"` |

### 問題の内容

同コミットで両ファイルに実行権限（`chmod +x`）が付与されており、shebang (`#!/usr/bin/env ruby`) と合わせて `./ruby/coglog/bin/coglog-cli` での直接実行を意図した構成になっている。しかし `require "coglog"` はRuby の `$LOAD_PATH` 上に gem がインストールされていることを前提とするため、ソースチェックアウトからの直接実行は `LoadError` で失敗する。

```
$ ./ruby/coglog/bin/coglog-cli read
<internal:gem_prelude>: ... cannot load such file -- coglog (LoadError)
```

### ドキュメントとの関係

`PLAN-version-sync.md` 内で Ruby CLI を呼び出す 3 箇所はすべて `-I` フラグで回避している。

| 箇所 | 行 | コマンド |
|------|-----|---------|
| スモークテスト表 | L431 | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli --help` |
| 3c-1 CLI_CMD 対応表 | L597 | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli` |
| 3c-2 相互運用テスト | L635 | `ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli read` |

ドキュメント上の手順は動作するが、`-I` が必須であること自体が bin スタブの設計意図（直接実行可能）と矛盾している。

### gemspec との整合性

`ruby/coglog/coglog.gemspec` (L12-13):

```ruby
s.files       = ["lib/coglog.rb", "bin/coglog-cli"]
s.executables = ["coglog-cli"]
```

gem としてインストールされた場合は `require "coglog"` で正しく動作する。問題はソースチェックアウトからの実行に限定される。

### 重大度

**P2** — gem インストール時は正常動作。ソースチェックアウトからの直接実行のみ影響。ドキュメント上の手順は `-I` で回避済み。

---

## P2. Go スモークテストコマンドの不整合

### 発生コミット

`a5e9b07` (docs: sync plan command/path examples with current tree)

### 影響ファイル

`docs/plans/PLAN-version-sync.md` L425

### 問題の内容

スモークテスト表の Go コマンドが以下のように記載されている。

```
go run ./go/cmd/coglog-cli --help
```

Go モジュールのルートは `go/go.mod`（`module github.com/HarmoniaEpic/coglog/go`）であり、リポジトリルートには `go.mod` が存在しない。このため:

- **リポジトリルートから実行:** `cannot find main module` で失敗
- **`go/` ディレクトリから実行:** `./go/cmd/coglog-cli` というパスが存在しないため失敗

いずれの解釈でも実行不可能である。

### 同一ドキュメント内の不整合

同じ `PLAN-version-sync.md` 内の他 3 箇所はすべて `cd go &&` パターンで正しく記載されている。

| 箇所 | 行 | コマンド | 実行可否 |
|------|-----|---------|:-------:|
| **スモークテスト表** | **L425** | **`go run ./go/cmd/coglog-cli --help`** | **不可** |
| Priority 2 ビルド | L392 | `cd go && go build ./...` | 可 |
| 3c-1 CLI_CMD 対応表 | L596 | `cd go && go run ./cmd/coglog-cli` | 可 |
| 3c-2 相互運用テスト | L630 | `(cd go && COGLOG_DIR="$TMPDIR" go run ./cmd/coglog-cli read)` | 可 |

コミット `a5e9b07` は相互運用テスト (L630) やCLI_CMD 対応表 (L596) を正しく修正したが、スモークテスト表 (L425) の修正が漏れた。

### 実機検証結果

```
$ go run ./go/cmd/coglog-cli --help
go: cannot find main module, but found .git/config in /home/user/CogLog

$ cd go && go run ./cmd/coglog-cli --help
usage: coglog-cli <read|write|clear>
...
```

### 重大度

**P2** — ドキュメントの手順記載ミス。自動テストには影響しないが、手動スモークテストの手順をそのまま実行すると失敗する。

---

## 達成状況マトリクス

本ドキュメントの P1・P2 は問題報告としての初出時点の記録であり、現行コードおよびドキュメントでは解消済みである。以下に、報告時点と現状の差分を整理する。

| ID | 報告時点 | 現状 | 判定根拠（現行コード／ドキュメント） |
|----|----------|------|--------------------------------------|
| P1 | 未達（`require "coglog"` でソースチェックアウト実行不可） | **達成** | `ruby/coglog/bin/coglog-cli` L2 が `require_relative '../lib/coglog'` に復元済み。`ruby/coglog-mcp/bin/coglog-mcp` L2 も同様に `require_relative '../lib/coglog_mcp'` に復元済み。修正コミット `cac496b` |
| P2 | 未達（Go スモークテストコマンドが実行不可能） | **達成** | `docs/plans/PLAN-version-sync.md` L425 が `cd go && go run ./cmd/coglog-cli --help` に修正済み。同ドキュメント内の他 3 箇所と一貫した `cd go &&` パターンに統一。修正コミット `cac496b` |
