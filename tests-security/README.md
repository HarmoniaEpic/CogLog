# CogLog v0.9.1 Security Tests

Security-focused test suite for all 11 language implementations. Complements the functional tests in `tests/`.

## Prerequisites

Same as `tests/` — see [tests/README.md](../tests/README.md).

## Harnesses

| Harness | Priority | Scope | Languages |
|---|---|---|---|
| `harness-path.sh` | P0 | Path traversal, filesystem edge cases | 11 (all) |
| `harness-tampering.sh` | P0 | Data file corruption & tampering resistance | 11 (all) |
| `harness-input.sh` | P1 | Input boundary (large payloads, special chars) | 11 (all) |
| `harness-mcp-security.sh` | P1 | MCP protocol violations & abuse | 10 (no bash) |
| `harness-concurrency.sh` | P2 | Concurrent read/write/clear race conditions | 11 (all) |

## Usage

```bash
# Run a single harness for all languages
./tests-security/harness-path.sh all

# Run specific languages
./tests-security/harness-input.sh rust python node

# Run all security tests
for h in tests-security/harness-*.sh; do "$h" all; done
```

## Directory Structure

```
tests-security/
├── common.sh                  # Shared utilities (sourced by harnesses)
├── fixtures-security/         # Security test fixtures
│   ├── control-chars.json
│   ├── extra-fields.json
│   ├── tampered-negative-tid.json
│   ├── tampered-no-schema.json
│   └── unicode-edge.json
├── harness-concurrency.sh     # P2: Race conditions
├── harness-input.sh           # P1: Input boundary
├── harness-mcp-security.sh    # P1: MCP protocol abuse
├── harness-path.sh            # P0: Path traversal & filesystem
├── harness-tampering.sh       # P0: Data file tampering
└── README.md                  # This file
```

## Design

- `common.sh` sources shared functions (CLI runners, MCP session management, build helpers) extracted from `tests/harness.sh` and `tests/harness-mcp.sh`
- All harnesses follow the same `pass()`/`fail()`/`skip()` pattern as `tests/`
- Tests accept both "success" and "graceful rejection" as valid behaviors — the key property is **no crash, no corruption, no silent data loss**
