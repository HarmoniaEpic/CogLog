# PLAN: Post-Translation Build & Smoke-Test Verification

> Status: Draft
> Scope: All language implementations affected by PLAN-i18n-comments.md
> Prerequisite: PLAN-i18n-comments.md Pass 2 (Translation) complete

---

## Background

PLAN-i18n-comments.md specifies a Verification section requiring that Haskell and Common Lisp packages still build after comment translation. This plan extends that requirement to all 11 language implementations, providing a systematic build and smoke-test checklist to confirm that no translation accidentally altered code.

---

## Scope

| In scope | Out of scope |
|---|---|
| Compile / syntax-check every translated source file | Functional / integration tests |
| Smoke-test built binaries (crash-free `--help`) | Performance benchmarks |
| Haddock generation for Haskell | Registry publication |

---

## Environment Notes

### C++ — cosmocc unavailability

The CI/CD pipeline (`release-cpp.yml`) builds C++ with:

```
cosmoc++ -std=c++17 -Os -mtiny
```

In virtual / sandboxed environments, `cosmocc` may not be installed or may fail. For verification purposes, use the system C++ compiler instead:

```bash
c++ -std=c++17 -Os -o /tmp/coglog-cli cpp/coglog/coglog-cli.cpp
```

- `-mtiny` is a Cosmopolitan-specific flag — omit it.
- `-fno-exceptions -fno-rtti` are optional; the source does not use exceptions or RTTI, but these flags are not required for correctness verification.
- The goal is to confirm that comment translation did not break compilation, not to produce a release binary.

---

## Verification Steps

### Step 1: Haskell (PLAN-i18n-comments.md explicitly requires this)

**Priority: Highest** — Literate Haskell prose is interleaved with code; translation errors can break compilation.

```bash
# Build both packages
cd haskell/coglog     && cabal build
cd haskell/coglog-mcp && cabal build

# Generate Haddock documentation (verifies Haddock markers are intact)
cd haskell/coglog     && cabal haddock
cd haskell/coglog-mcp && cabal haddock
```

**Pass criteria**: `cabal build` exits 0; `cabal haddock` exits 0 with no parse warnings on translated modules.

---

### Step 2: Common Lisp (PLAN-i18n-comments.md explicitly requires this)

**Priority: Highest** — Docstrings are string literals inside S-expressions; an unescaped quote breaks the reader.

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

**Pass criteria**: SBCL loads each system without reader or compilation errors.

---

### Step 2b: Common Lisp — Recurrent Quine (coglog-quine)

**Priority: Highest** — The recurrent quine contains translated comments *and* docstrings embedded in quoted S-expressions (`*self-source*`, `*advance-source*`, `*affordance*`). A mistranslation inside a quoted form silently corrupts the program's self-replication.

#### Why `asdf:load-system` cannot be used

`recurrent-quine.lisp` ends with top-level forms:

```lisp
(eval *advance-source*)
(eval *self-source*)
(main)
```

`asdf:load-system :coglog-quine` would execute `(main)`, which parses CLI arguments and calls `exit`. This makes ASDF loading unusable for build verification.

#### Why `write` and `clear` are destructive

The recurrent quine is a self-rewriting program. `write` calls `write-generation`, which overwrites `recurrent-quine.lisp` itself with the next generation. `clear` does the same (resetting state to nil). **Any execution of `write` or `clear` irreversibly modifies the source file.**

From Q_1 onward, the prose comments in the original Q_0 are gone by design — `write-generation` outputs only a minimal header. This means a careless smoke test can permanently strip the repository's Q_0 comments.

#### Safe verification: `read` command only

The `read` command is the only non-destructive operation. It prints `*state*` and `*affordance*` to stdout without modifying any file.

```bash
# Verify SBCL can read, compile, and execute the file without reader errors.
# The 'read' command inspects state without modifying the file.
sbcl --script common-lisp/coglog-quine/recurrent-quine.lisp read
```

**Pass criteria**:
- SBCL exits 0 (no reader errors, no compilation errors).
- stdout contains `;;; (no coglog found)` (initial state) followed by `;;; affordance` and the affordance S-expression.

#### Optional: destructive round-trip test (requires backup)

If a full round-trip verification is desired, **the source file must be backed up and restored**:

```bash
QUINE=common-lisp/coglog-quine/recurrent-quine.lisp

# 1. Backup
cp "$QUINE" /tmp/recurrent-quine-backup.lisp

# 2. Write (destructive — rewrites the file)
echo '(:user "test" :thinking "test" :assistant "test" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")' \
  | sbcl --script "$QUINE" write

# 3. Verify next generation can read
sbcl --script "$QUINE" read

# 4. Restore original Q_0
cp /tmp/recurrent-quine-backup.lisp "$QUINE"
```

**Pass criteria for optional test**:
- Step 2 prints `coglog: turn 1 written` and exits 0.
- Step 3 prints `;;; state` followed by the entry, and exits 0.
- Step 4 restores the file. Verify with `git diff` that no changes remain.

**Warning**: Do NOT skip step 4. If the backup is not restored, subsequent `git diff` or `git status` will show the file as modified, and the original Q_0 prose comments will be lost.

---

### Step 3: Rust

```bash
cd rust && cargo build --release
```

Builds all three crates (coglog-core, coglog, coglog-mcp) in workspace.

**Pass criteria**: `cargo build` exits 0 with no errors.

---

### Step 4: C++ (system compiler — see Environment Notes)

```bash
c++ -std=c++17 -Os -o /tmp/coglog-cli     cpp/coglog/coglog-cli.cpp
c++ -std=c++17 -Os -o /tmp/coglog-mcp-cpp cpp/coglog-mcp/coglog-mcp.cpp
```

**Pass criteria**: Compilation exits 0; binaries are produced.

---

### Step 5: Go

```bash
cd go && go build ./...
```

Builds coglog.go, cmd/coglog-cli, and cmd/coglog-mcp in one pass.

**Pass criteria**: `go build` exits 0.

---

### Step 6: Java

```bash
cd java/coglog     && mvn -q compile
cd java/coglog-mcp && mvn -q compile
```

**Pass criteria**: Maven compilation exits 0.

---

### Step 7: C#

```bash
cd csharp/coglog     && dotnet build --nologo -q
cd csharp/coglog-mcp && dotnet build --nologo -q
```

**Pass criteria**: `dotnet build` exits 0.

---

### Step 8: Python (syntax check)

Python is interpreted; verify syntax only.

```bash
python3 -c "import py_compile; py_compile.compile('python/coglog/src/coglog/__init__.py', doraise=True)"
python3 -c "import py_compile; py_compile.compile('python/coglog-mcp/src/coglog_mcp/__init__.py', doraise=True)"
```

**Pass criteria**: No `SyntaxError`.

---

### Step 9: Node.js (syntax check)

```bash
node --check node/coglog/index.mjs
node --check node/coglog-mcp/index.mjs
```

**Pass criteria**: Exits 0.

---

### Step 10: Ruby (syntax check)

```bash
ruby -c ruby/coglog/lib/coglog.rb
ruby -c ruby/coglog-mcp/lib/coglog_mcp.rb
```

**Pass criteria**: Prints `Syntax OK`.

---

### Step 11: Bash (syntax check)

```bash
bash -n bash/coglog/coglog-cli.sh
```

**Pass criteria**: Exits 0 (no syntax errors).

---

## Smoke Tests

For compiled languages, run the built binary with `--help` (or no arguments) to verify it does not crash at startup.

| Language | Command | Expected |
|---|---|---|
| Rust | `rust/target/release/coglog-cli --help` | Usage text, exit 0 |
| C++ | `/tmp/coglog-cli --help` | Usage text, exit 0 |
| Go | `go run ./cmd/coglog-cli --help` | Usage text, exit 0 |
| Haskell | `cabal run coglog -- --help` | Usage text, exit 0 |
| Java | `java -jar java/coglog/target/coglog-cli.jar --help` | Usage text, exit 0 |
| C# | `dotnet run --project csharp/coglog -- --help` | Usage text, exit 0 |
| Python | `python3 python/coglog/src/coglog/__init__.py --help` | Usage text, exit 0 |
| Node.js | `node node/coglog/index.mjs --help` | Usage text, exit 0 |
| Ruby | `ruby ruby/coglog/lib/coglog.rb --help` | Usage text, exit 0 |
| Bash | `bash bash/coglog/coglog-cli.sh --help` | Usage text, exit 0 |

MCP server variants (`coglog-mcp`) are not smoke-tested here because they require stdio JSON-RPC interaction.

**Recurrent Quine**: The `read` command in Step 2b already serves as the smoke test. No additional entry is needed here. Do NOT run `write` or `clear` as a smoke test — see Step 2b for the rationale.

---

## Execution Order & Priority

```
Priority 1 (PLAN-required):  Step 1 (Haskell) + Step 2 (Common Lisp) + Step 2b (Recurrent Quine)
Priority 2 (compiled):       Step 3 (Rust) + Step 4 (C++) + Step 5 (Go)
                              Step 6 (Java) + Step 7 (C#)
Priority 3 (interpreted):    Step 8 (Python) + Step 9 (Node) + Step 10 (Ruby) + Step 11 (Bash)
Smoke tests:                  After each priority group
```

Steps within the same priority group are independent and may run in parallel.

**Note**: Step 2b's optional destructive round-trip test must NOT run in parallel with any other Common Lisp step, as it modifies and restores `recurrent-quine.lisp`.

---

## Failure Handling

If any step fails:

1. Inspect the error to determine whether it is a translation-induced breakage (e.g. unclosed string, broken Haddock marker) or an environment issue (e.g. missing toolchain).
2. For translation-induced breakage: fix the affected source file and re-run the failed step.
3. For environment issues: document the issue and skip. The step can be retried in a different environment or deferred to CI.

---

## What This Plan Does Not Cover

- **Functional correctness tests** — covered by PLAN-TEST-IMPL-v0.9.1.md
- **Registry publication** — covered by PLAN-release-v0.9.1.md
- **Documentation translation** — covered by PLAN-i18n-readme.md
