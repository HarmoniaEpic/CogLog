# Ruby bin スタブ require 方式および Go スモークテストコマンドの修正計画

> **関連問題報告:** `docs/problems/PROBLEMS-cli-docs-regression.md`

**作成日:** 2026-03-07

---

## 概要

コミット `914ab19` および `a5e9b07` で導入された以下 2 件のリグレッションを修正する。

| # | 問題 | 修正方針 |
|---|------|---------|
| P1 | Ruby bin スタブが `require "coglog"` を使用しており、ソースチェックアウトからの直接実行が不可 | `require_relative` に戻す |
| P2 | `PLAN-version-sync.md` の Go スモークテストコマンドが実行不可能 | `cd go &&` パターンに統一 |

---

## 修正内容

### 修正 1: Ruby bin スタブの `require_relative` 復元

#### 対象ファイル

| ファイル | 現状 | 修正後 |
|---------|------|--------|
| `ruby/coglog/bin/coglog-cli` | `require "coglog"` | `require_relative '../lib/coglog'` |
| `ruby/coglog-mcp/bin/coglog-mcp` | `require "coglog_mcp"` | `require_relative '../lib/coglog_mcp'` |

#### 根拠

`require_relative` は以下の両方の実行コンテキストで正しく動作する。

| コンテキスト | `require_relative` | `require "coglog"` |
|-------------|:------------------:|:------------------:|
| gem インストール後 (`gem exec coglog-cli`) | 動作する | 動作する |
| ソースチェックアウトからの直接実行 (`./ruby/coglog/bin/coglog-cli`) | 動作する | **LoadError** |
| `-I` 付き実行 (`ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli`) | 動作する | 動作する |

`require_relative` は gem の `bin/` スタブとして広く採用されている慣例であり（Bundler が生成するスタブも同方式）、gem インストール時にも問題なく機能する。

#### ドキュメントへの影響

`PLAN-version-sync.md` 内の Ruby コマンド（L431, L597, L635）は `-I` 付きで記載されている。`require_relative` に戻した場合、`-I` は冗長になるが無害であるため、ドキュメントの修正は任意とする。

---

### 修正 2: Go スモークテストコマンドの修正

#### 対象ファイル

`docs/plans/PLAN-version-sync.md` L425

#### 変更内容

```diff
-| Go | `go run ./go/cmd/coglog-cli --help` | Usage 表示、exit 0 |
+| Go | `cd go && go run ./cmd/coglog-cli --help` | Usage 表示、exit 0 |
```

#### 根拠

同ドキュメント内の他 3 箇所（L392, L596, L630）はすべて `cd go &&` パターンを使用しており、これに統一する。Go のモジュールルートが `go/go.mod` である以上、リポジトリルートからの `go run ./go/...` は動作しない。

---

## 検証手順

### 修正 1 の検証

```bash
# ソースチェックアウトからの直接実行
./ruby/coglog/bin/coglog-cli --help
./ruby/coglog-mcp/bin/coglog-mcp  # MCP は stdin 待ちになるため Ctrl+C で終了

# 既存ドキュメント記載のコマンド（-I 付き、引き続き動作すること）
ruby -Iruby/coglog/lib ruby/coglog/bin/coglog-cli --help
```

**判定基準:** 両方のコマンドが `LoadError` なしで実行されること。

### 修正 2 の検証

```bash
# 修正後のコマンドをそのまま実行
cd go && go run ./cmd/coglog-cli --help
```

**判定基準:** usage テキストが表示されること（終了コードは 1 でも可 — `--help` を未知フラグとして扱う実装の場合）。

---

## 影響範囲

| 項目 | 影響 |
|------|------|
| ランタイム動作 | 変更なし（`require_relative` と `require` は解決パスが異なるのみ） |
| gem ビルド・インストール | 影響なし |
| CI/CD | 影響なし |
| 他のドキュメント | 影響なし（`PLAN-version-sync.md` 以外に Go スモークテストコマンドの記載はない） |

---

## 作業順序

1. `ruby/coglog/bin/coglog-cli` の修正
2. `ruby/coglog-mcp/bin/coglog-mcp` の修正
3. 修正 1 の検証（直接実行 + `-I` 付き実行）
4. `docs/plans/PLAN-version-sync.md` L425 の修正
5. 修正 2 の検証（`cd go && go run ./cmd/coglog-cli --help`）
6. コミット・プッシュ
