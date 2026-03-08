# CogLog v0.9.1 Tests

Two-layer test architecture for all 11 language implementations.

## Prerequisites

- `jq` (JSON processing)
- Language toolchains for each language under test
- `sbcl` (for Recurrent Quine tests only)

Java (JAR) and C++ (binary) are auto-built by the harness if needed. Maven is used when available; otherwise `javac`/`jar` is used as a fallback.

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

## Directory Structure

```
tests/
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
