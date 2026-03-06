# PLAN: README バイリンガル化 / README Bilingualization

> ステータス / Status: Draft
> 方針 / Policy: 日本語・英語の段落並列（冗長を許容）/ Japanese and English paragraphs in parallel (verbosity accepted)

---

## 対象ファイル / Target Files

モノレポ内の全 README.md。計 25 ファイル。

All README.md files in the monorepo. 25 files total.

| # | ファイル / File | 現状 / Current state |
|---|---|---|
| 1 | `README.md`（ルート / root） | 日本語 / Japanese |
| 2 | `rust/coglog/README.md` | 日本語 / Japanese |
| 3 | `rust/coglog-core/README.md` | 日本語 / Japanese |
| 4 | `rust/coglog-mcp/README.md` | 日本語 / Japanese |
| 5 | `python/coglog/README.md` | 日本語 / Japanese |
| 6 | `python/coglog-mcp/README.md` | 要確認 / To confirm |
| 7 | `node/coglog/README.md` | 要確認 / To confirm |
| 8 | `node/coglog-mcp/README.md` | 要確認 / To confirm |
| 9 | `go/README.md` | 要確認 / To confirm |
| 10 | `go/cmd/coglog-cli/README.md` | 要確認（stub の可能性）/ To confirm (possibly stub) |
| 11 | `go/cmd/coglog-mcp/README.md` | 要確認（stub の可能性）/ To confirm (possibly stub) |
| 12 | `ruby/coglog/README.md` | 新規作成 / New |
| 13 | `ruby/coglog-mcp/README.md` | 新規作成 / New |
| 14 | `java/coglog/README.md` | 新規作成 / New |
| 15 | `java/coglog-mcp/README.md` | 新規作成 / New |
| 16 | `csharp/coglog/README.md` | 日本語 / Japanese |
| 17 | `csharp/coglog-mcp/README.md` | 要確認 / To confirm |
| 18 | `haskell/coglog/README.md` | 要確認 / To confirm |
| 19 | `haskell/coglog-mcp/README.md` | 要確認 / To confirm |
| 20 | `common-lisp/coglog/README.md` | 要確認 / To confirm |
| 21 | `common-lisp/coglog-mcp/README.md` | 要確認 / To confirm |
| 22 | `common-lisp/coglog-quine/README.md` | 要確認 / To confirm |
| 23 | `cpp/coglog/README.md` | 日本語 / Japanese |
| 24 | `cpp/coglog-mcp/README.md` | 要確認 / To confirm |
| 25 | `bash/coglog/README.md` | 日本語 / Japanese |

---

## 併記フォーマット / Bilingual Format

セクションヘッダーを `## 日本語 / English` 形式とし、各段落を日本語→英語の順で並べる。

Section headers take the form `## 日本語 / English`. Within each section, the Japanese paragraph precedes the English paragraph.

```markdown
## インストール / Installation

```bash
cargo install coglog
```

AIが直前ターンの内容を次ターンで参照するためのメタ認知ログ。

A metacognition log that lets an AI reference the previous turn's content in the next turn.

---

## 使い方 / Usage

```bash
coglog-cli read
echo '{...}' | coglog-cli write
coglog-cli clear
```

`read` は直前ターンの JSON を stdout に出力する。データがない場合は `"(no coglog found)"` を返す。

`read` prints the previous turn's JSON to stdout. Returns `"(no coglog found)"` if no data exists.
```

---

## 作業順序 / Work Order

既存ファイルの改訂と新規作成を言語グループ単位でコミットする。

Revisions to existing files and creation of new files are committed per language group.

```
commit 1:  README.md（ルート）
commit 2:  rust/          (coglog-core, coglog, coglog-mcp)
commit 3:  python/        (coglog, coglog-mcp)
commit 4:  node/          (coglog, coglog-mcp)
commit 5:  go/            (README.md, cmd/coglog-cli, cmd/coglog-mcp)
commit 6:  cpp/           (coglog, coglog-mcp)
commit 7:  bash/
commit 8:  csharp/        (coglog, coglog-mcp)
commit 9:  haskell/       (coglog, coglog-mcp)
commit 10: ruby/          (coglog, coglog-mcp)          ← 新規 / new
commit 11: java/          (coglog, coglog-mcp)          ← 新規 / new
commit 12: common-lisp/   (coglog, coglog-mcp, coglog-quine)
```

---

## 確認チェック / Verification

各ファイル改訂後に AI が目視確認する。自動判定は行わない。

After each file is revised, AI performs a visual inspection. No automated判定 is used.

確認項目 / Checklist:

- [ ] 全セクションヘッダーが `## 日本語 / English` 形式になっているか
- [ ] 各セクション内に日本語段落と英語段落が両方存在するか
- [ ] コードブロックは共有（言語間で重複させない）になっているか
- [ ] 英語段落が日本語段落の意味を正確に伝えているか

All section headers follow the `## 日本語 / English` format.  
Each section contains both a Japanese paragraph and an English paragraph.  
Code blocks are shared (not duplicated between languages).  
English paragraphs accurately convey the meaning of the Japanese paragraphs.

---

## 対象外 / Out of Scope

| ファイル / File | 理由 / Reason |
|---|---|
| `docs/` 配下の設計文書 / Design docs under `docs/` | 別途判断 / Separate decision |
| `coglog-skill/coglog/SKILL.md` | 内部ドキュメント / Internal document |
| `tests/README.md` | 内部ドキュメント / Internal document |
