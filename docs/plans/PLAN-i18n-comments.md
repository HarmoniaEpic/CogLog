# PLAN: Translate In-Code Japanese Comments to English

> Status: Draft
> Scope: Source code comments only (not documentation files)
> Trigger: International package registry publication (PyPI, npm, crates.io, Hackage, Quicklisp, RubyGems, Maven Central, pkg.go.dev, NuGet)

---

## Background

CogLog's user-facing strings (CLI output, MCP tool names, `_schema` field descriptions) are already in English. The remaining Japanese text lives in source code comments. Since these comments are visible to anyone reading the source on GitHub or via registry source links, they are effectively public documentation and should be readable by the international audience that package registries serve.

---

## Scope Definition

### In scope

| Category | Examples |
|---|---|
| Inline comments | `// 優先順位: COGLOG_DIR env > ...` |
| Block / section header comments | `-- ═══ JSON パース（手書き）═══` |
| Docstring-style comments | `-- \| JSON 文字列のエスケープ` (Haskell Haddock) |
| Common Lisp docstrings | `"JSON 数値（整数）をパースする。"` |
| Literate Haskell prose | Narrative sections in `CogLog.lhs` |

### Out of scope (separate decision)

| Category | Rationale |
|---|---|
| `docs/` directory (DESIGN, PLAN, SPEC, research notes) | Design documentation; separate localization decision |
| `coglog-skill/coglog/SKILL.md` | Internal skill; separate decision |
| `_schema` field description strings in JSON output | Already in English |
| CLI output strings | Already in English |
| Sample data in DESIGN.md (e.g. `"ユーザーの発話（原文）"`) | Illustrative example data in documentation |

---

## File Inventory

Confirmed or expected Japanese comment presence, by language:

### Priority 1 — Confirmed Japanese comments

| File | Comment volume | Special notes |
|---|---|---|
| `haskell/coglog/Adapter.hs` | High | Haddock-style `-- \|` docstrings; section separators; inline |
| `haskell/coglog/CogLog.lhs` | High | **Literate Haskell**: prose sections are the primary documentation medium; see special handling below |
| `haskell/coglog-mcp/CogLog.lhs` | High | Copy of above |
| `haskell/coglog-mcp/McpServer.hs` | Medium (new file) | Modelled on Adapter.hs |
| `common-lisp/coglog/adapter.lisp` | High | Inline `; コメント` and function docstrings |
| `common-lisp/coglog/coglog.lisp` | Medium | Pure core; likely Japanese docstrings |
| `common-lisp/coglog-mcp/mcp-server.lisp` | Medium (new file) | Modelled on adapter.lisp |
| `common-lisp/coglog-quine/recurrent-quine.lisp` | Medium | Self-modifying; comments explain quine structure |
| `rust/coglog-core/src/lib.rs` | Low | 1–2 confirmed: `// 優先順位: ...` |
| `rust/coglog-mcp/src/main.rs` | Low | 1 confirmed: `// --coglog-dir <path> の解析...` |

### Priority 2 — Likely Japanese comments (to be confirmed by file inspection)

| File | Basis for expectation |
|---|---|
| `rust/coglog/src/main.rs` | Same codebase as coglog-mcp |
| `python/coglog/src/coglog/__init__.py` | Original implementation |
| `python/coglog-mcp/src/coglog_mcp/__init__.py` | Original implementation |
| `node/coglog/index.mjs` | Original implementation |
| `node/coglog-mcp/index.mjs` | Original implementation |
| `cpp/coglog/coglog-cli.cpp` | Original implementation |
| `cpp/coglog-mcp/coglog-mcp.cpp` | Original implementation |
| `bash/coglog/coglog-cli.sh` | Original implementation |

### Priority 3 — New implementations (confirmed Japanese comments)

Go, Ruby, Java, C# were expected to have English-only comments, but audit confirmed that all four contain Japanese comments copied from existing implementations. The pattern is uniform: priority-resolution comments and `--coglog-dir` parsing comments.

| File | Comment volume | Japanese comment pattern |
|---|---|---|
| `go/coglog.go` | Low (1 line) | `// 優先順位: COGLOG_DIR env > ...（最終フォールバック）` |
| `go/cmd/coglog-cli/main.go` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |
| `go/cmd/coglog-mcp/main.go` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |
| `ruby/coglog/lib/coglog.rb` | Low (1 line) | `# --coglog-dir <path> の解析（優先順位: ...）` |
| `ruby/coglog-mcp/lib/coglog_mcp.rb` | Low (1 line) | `# --coglog-dir <path> の解析（優先順位: ...）` |
| `java/coglog/.../CogLog.java` | Low (1 line) | `// 優先順位: COGLOG_DIR env > ...（最終フォールバック）` |
| `java/coglog/.../Main.java` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |
| `java/coglog-mcp/.../CogLog.java` | Low (1 line) | `// 優先順位: COGLOG_DIR env > ...（最終フォールバック）` |
| `java/coglog-mcp/.../McpServer.java` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |
| `csharp/coglog/CogLog.cs` | Low (1 line) | `// 優先順位: COGLOG_DIR env > ...（最終フォールバック）` |
| `csharp/coglog/Program.cs` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |
| `csharp/coglog-mcp/CogLog.cs` | Low (1 line) | `// 優先順位: COGLOG_DIR env > ...（最終フォールバック）` |
| `csharp/coglog-mcp/Program.cs` | Low (1 line) | `// --coglog-dir <path> の解析（優先順位: ...）` |

---

## Special Handling: Literate Haskell (`CogLog.lhs`)

Literate Haskell is a format where prose and code coexist in a single file. The prose sections are not "comments" in the traditional sense — they are the primary narrative. For `CogLog.lhs`, the translation serves a dual purpose:

1. **Correctness**: `cabal haddock` renders the prose as package documentation on Hackage. Japanese prose means Hackage docs are unreadable to the international audience.
2. **Design intent**: `CogLog.lhs` exists to demonstrate that IO does not penetrate the pure core. The narrative explaining this property is valuable documentation.

**Approach**: Translate prose sections to English. Preserve the mathematical notation (the recurrence relation `a_{n+1} = advance(a_n, w_n)`) as-is — it is language-neutral.

The file is duplicated in `haskell/coglog/` and `haskell/coglog-mcp/`. Both copies must be updated consistently.

---

## Work Order

Work proceeds in two passes:

### Pass 1: Audit (no edits)

Run `grep -rn '[^\x00-\x7F]' <file>` on each source file to enumerate all non-ASCII lines. Record findings in a checklist. This separates discovery from editing and avoids missed instances.

Files to audit in order:

```
1.  rust/coglog-core/src/lib.rs
2.  rust/coglog/src/main.rs
3.  rust/coglog-mcp/src/main.rs
4.  python/coglog/src/coglog/__init__.py
5.  python/coglog-mcp/src/coglog_mcp/__init__.py
6.  node/coglog/index.mjs
7.  node/coglog-mcp/index.mjs
8.  cpp/coglog/coglog-cli.cpp
9.  cpp/coglog-mcp/coglog-mcp.cpp
10. bash/coglog/coglog-cli.sh
11. go/coglog.go
12. go/cmd/coglog-cli/main.go
13. go/cmd/coglog-mcp/main.go
14. ruby/coglog/lib/coglog.rb
15. ruby/coglog-mcp/lib/coglog_mcp.rb
16. java/coglog/src/main/java/.../CogLog.java
17. java/coglog/src/main/java/.../Main.java
18. java/coglog-mcp/src/main/java/.../CogLog.java
19. java/coglog-mcp/src/main/java/.../McpServer.java
20. csharp/coglog/CogLog.cs
21. csharp/coglog/Program.cs
22. csharp/coglog-mcp/CogLog.cs
23. csharp/coglog-mcp/Program.cs
24. haskell/coglog/Adapter.hs
25. haskell/coglog/CogLog.lhs          ← Literate Haskell
26. haskell/coglog-mcp/McpServer.hs
27. haskell/coglog-mcp/CogLog.lhs      ← Literate Haskell (copy)
28. common-lisp/coglog/coglog.lisp
29. common-lisp/coglog/adapter.lisp
30. common-lisp/coglog-mcp/mcp-server.lisp
31. common-lisp/coglog-quine/recurrent-quine.lisp
```

### Pass 2: Translation

Edit files in the same order as Pass 1. Commit per language group to keep diffs reviewable:

```
commit 1:  rust/ (all three files)
commit 2:  python/ (both files)
commit 3:  node/ (both files)
commit 4:  cpp/ (both files)
commit 5:  bash/
commit 6:  go/ (coglog.go, cmd/coglog-cli/main.go, cmd/coglog-mcp/main.go)
commit 7:  ruby/ (coglog.rb, coglog_mcp.rb)
commit 8:  java/ (CogLog.java x2, Main.java, McpServer.java)
commit 9:  csharp/ (CogLog.cs x2, Program.cs x2)
commit 10: haskell/Adapter.hs + McpServer.hs
commit 11: haskell/CogLog.lhs (both copies) ← Literate Haskell, larger change
commit 12: common-lisp/ (all four files)
```

---

## Translation Guidelines

### General

- Translate meaning, not word-for-word. A comment that explains *why* something is done is more valuable than one that restates *what* the code does.
- Section separator comments (`-- ═══ JSON パース ═══`) become English equivalents (`-- ═══ JSON parsing ═══`).
- Keep comment markers consistent with each language's conventions (`//`, `--`, `;`, `#`).

### Haskell Haddock

Haddock markers (`-- |`, `-- ^`) must be preserved. Only the text following the marker is translated.

```haskell
-- Before
-- | JSON 文字列のエスケープ
escapeJson :: String -> String

-- After
-- | Escape a string for JSON serialization.
escapeJson :: String -> String
```

### Common Lisp docstrings

CL function docstrings appear as string literals immediately after the parameter list. They are part of the runtime image and appear in `(describe #'fn)` output.

```lisp
;; Before
(defun parse-json-number (p)
  "JSON 数値（整数）をパースする。"
  ...)

;; After
(defun parse-json-number (p)
  "Parse a JSON integer number."
  ...)
```

### Rust path-resolution comments

Short inline comments; straightforward substitution.

```rust
// Before
// 優先順位: COGLOG_DIR env > $HOME/.coglog > ./.coglog（最終フォールバック）

// After
// Priority: COGLOG_DIR env > $HOME/.coglog > ./.coglog (final fallback)
```

---

## Verification

After each commit, confirm no Japanese remains in the edited files:

```bash
grep -Pn '[^\x00-\x7F]' <file>
```

Remaining non-ASCII hits are acceptable if they are only box-drawing characters (`═══`) or em dashes (`—`) used in section separators and English CLI help text. Only Japanese text (CJK Unified Ideographs, Hiragana, Katakana) should be absent.

Additionally, after the Haskell and Common Lisp commits, verify that the packages still build:

```bash
# Haskell
cabal build coglog coglog-mcp

# Common Lisp
sbcl --load common-lisp/coglog/coglog.asd
sbcl --load common-lisp/coglog-mcp/coglog-mcp.asd
```

Build failures here indicate that a translation accidentally altered code rather than comments.

---

## What This Plan Does Not Cover

- **README.md files** — [PLAN-i18n-readme.md](docs/plans/PLAN-i18n-readme.md)'s scope.
- **Documentation files** (`docs/`) — out of scope; separate decision required.
- **SKILL.md and CogLog for ClaudeSkills**(`coglog-skill/`) — out of scope.
