# CogLog v0.9.1 Tests

Two-layer test architecture for all 11 language implementations.

## Prerequisites

- `bash` (v4+ recommended; test harnesses are Bash scripts)
- `jq` (JSON processing, required)

### Language toolchains

Each language requires its toolchain to be installed. The harness checks for the required command before running tests; **languages whose toolchain is not found are automatically skipped** (reported as SKIP in the summary).

| Language | Required command(s) | Notes |
|----------|-------------------|-------|
| Rust | `cargo` | Builds and runs via `cargo run` |
| Python | `python3` | |
| Node | `node` | |
| Go | `go` | Builds and runs via `go run` |
| Ruby | `ruby` | |
| Java | `java`, `javac` | JAR auto-built; uses `mvn` if available, falls back to `javac`/`jar` |
| C# | `dotnet` | Builds and runs via `dotnet run` |
| Haskell | `cabal` | Builds and runs via `cabal run` |
| Common Lisp | `sbcl` | Also required for Recurrent Quine tests |
| C++ | `c++` | Binary auto-built from source |
| Bash | *(always available)* | Layer 1 only (no MCP) |

## Layer 1: CLI Black-Box Tests

A single shell script drives all 11 language implementations through the same CLI interface.

```bash
# Run all languages
./tests/harness.sh all

# Run specific languages
./tests/harness.sh rust python go

# Run a single language
./tests/harness.sh node
```

### Test groups covered by harness.sh

| Group | Description |
|-------|-------------|
| 1 | Initial state |
| 2 | Write/read round-trip |
| 3 | Fact layer validation |
| 4 | Interpretation layer validation |
| 5 | Type checking |
| 6 | Window size 1 (overwrite) |
| 7 | turn_id monotonic increase |
| 8 | Clear |
| 9 | _schema auto-generation |
| 10 | Timestamp (ISO 8601) |
| 11a-f | Path resolution |
| 12 | Cross-language compatibility |
| 14 | CLI interface |

## Layer 2: MCP Protocol Tests

```bash
# Run all languages (Bash excluded — no MCP)
./tests/harness-mcp.sh all

# Run specific languages
./tests/harness-mcp.sh rust python node
```

## Recurrent Quine Tests

```bash
./tests/harness-quine.sh
```

**Warning:** Quine tests execute `write` which irreversibly rewrites `recurrent-quine.lisp`. The harness automatically backs up and restores the file using `recurrent-quine-baseline.lisp`.

## Cleanup

Remove all build artifacts and caches across every language:

```bash
./tests/clean.sh          # Remove artifacts
./tests/clean.sh --dry    # Preview what would be removed
```

Running `clean.sh` before tests ensures a fresh build from source; running it after tests reclaims disk space. Recommended workflow:

```bash
./tests/clean.sh            # Pre-test: start from clean state
./tests/harness.sh all      # Run Layer 1
./tests/harness-mcp.sh all  # Run Layer 2
./tests/clean.sh            # Post-test: reclaim ~170 MB
```

## Directory Structure

```
tests/
├── clean.sh               # Repository cleanup script
├── fixtures/              # Shared JSON test fixtures (14 files)
├── fixtures-quine/        # Recurrent Quine plist fixtures (7 files)
├── harness.sh             # Layer 1 CLI black-box test harness
├── harness-mcp.sh         # MCP protocol test harness
├── harness-quine.sh       # Recurrent Quine test harness
└── README.md              # This file
```

## Specification References

- `docs/designs/SPEC-TEST-v0.9.1.md` — Test specification
- `docs/designs/SPEC-path-resolution-v0.9.1.md` — Path resolution specification
- `docs/plans/PLAN-TEST-IMPL-v0.9.1.md` — Test implementation plan
