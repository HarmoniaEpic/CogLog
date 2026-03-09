# CogLog v0.9.1 — Test Report

**Date:** 2026-03-08
**Environment:** Linux 6.18.5 (x86_64)

## Summary

| Harness | PASS | FAIL | SKIP |
|---|---|---|---|
| Layer 1 (CLI Black-Box) | 518 | 0 | 0 |
| Layer 2 (MCP Protocol) | 60 | 0 | 0 |
| Recurrent Quine | 33 | 0 | 0 |
| **Total** | **611** | **0** | **0** |

## Toolchain Versions

| Tool | Version |
|---|---|
| jq | 1.7 |
| Python | 3.11.14 |
| Node.js | v22.22.0 |
| Go | 1.24.7 |
| Rust | 1.93.1 |
| Java | 21.0.10 |
| C++ | GCC 13.3.0 |
| Ruby | 3.3.6 |
| SBCL | (Common Lisp) |

## Layer 1: CLI Black-Box Tests (`harness.sh all`)

**Result: 518 PASS / 0 FAIL / 0 SKIP**

All 11 languages tested: rust, python, node, go, ruby, java, csharp, haskell, cl, cpp, bash.

All languages pass all tests.

## Layer 2: MCP Protocol Tests (`harness-mcp.sh all`)

**Result: 60 PASS / 0 FAIL**

All 10 MCP-capable languages pass all 6 MCP tests (13.1–13.6). Bash is excluded as it has no MCP server.

## Recurrent Quine Tests (`harness-quine.sh`)

**Result: 33 PASS / 0 FAIL**

All 14 test groups (Q.1–Q.14) pass, including `:opt-self` identity, all-options simultaneous write, and 3-generation round-trip fidelity.

### Previously Failing Tests (now fixed)

| Test | Description | Root Cause | Fix |
|---|---|---|---|
| Q.11 | `:opt-self` identity write | `extract_self_source` lacked `--noinform`; SBCL banner (containing commas) leaked into stdout and was embedded in the plist, causing `Comma not inside a backquote` | Added `--noinform` flag |
| Q.12 | All options simultaneously | Same as Q.11 | Same fix |
| Q.14 | `:opt-self` round-trip fidelity | Same as Q.11, plus `(caddr form)` returned `(quote (progn ...))` instead of stripping the quote wrapper from the reader macro expansion of `'(progn ...)` | Added `--noinform` + unwrap `(quote ...)` to extract the raw form |

The failures were in the test harness (`extract_self_source`), not in the quine itself. The quine's backquote avoidance design — using only `list`/`cons` to maintain `print → read` round-trip fidelity — is correct and verified across 3 generations.
