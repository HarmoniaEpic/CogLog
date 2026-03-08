# CogLog v0.9.1 — Test Report

**Date:** 2026-03-08
**Environment:** Linux 6.18.5 (x86_64)

## Summary

| Harness | PASS | FAIL | SKIP |
|---|---|---|---|
| Layer 1 (CLI Black-Box) | 518 | 0 | 0 |
| Layer 2 (MCP Protocol) | 60 | 0 | 0 |
| Recurrent Quine | 23 | 3 | 0 |
| **Total** | **601** | **3** | **0** |

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

**Result: 23 PASS / 3 FAIL**

### Failures

| Test | Description | Error |
|---|---|---|
| Q.11 | `:opt-self` identity write | `Comma not inside a backquote` (SBCL reader error) |
| Q.12 | All options simultaneously | `Comma not inside a backquote` (SBCL reader error) |
| Q.14 | `:opt-self` round-trip fidelity (3 generations) | exit code 1 |

All three failures relate to the `:opt-self` quine self-modification feature, where comma/backquote handling in the generated s-expression causes SBCL reader errors.

## Analysis

### Quine Failure Pattern

All 3 quine failures trace to `:opt-self` — the mechanism for a quine to rewrite its own source. The error `Comma not inside a backquote` indicates that the quine's self-representation contains unescaped commas that break when read back by SBCL.
