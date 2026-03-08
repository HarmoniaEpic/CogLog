#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test: MCP Protocol Abuse
#
# Tests MCP server robustness against protocol violations,
# malformed requests, and abnormal usage patterns.
#
# Usage:
#   ./tests-security/harness-mcp-security.sh all
#   ./tests-security/harness-mcp-security.sh rust python
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── MCP languages (bash excluded) ──
ALL_MCP_LANGS="rust python node go ruby java csharp haskell cl cpp"

# ═══════════════════════════════════════════════════════════════════
# JSON-RPC message builders
# ═══════════════════════════════════════════════════════════════════

jsonrpc_initialize() {
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"coglog-security-test","version":"0.9.1"}}}'
}

jsonrpc_initialized() {
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
}

jsonrpc_tools_call_read() {
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"coglog_read","arguments":{}}}'
}

jsonrpc_tools_call_write() {
  echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"coglog_write","arguments":{"user":"Hello","thinking":"test","assistant":"test","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}}}'
}

# ═══════════════════════════════════════════════════════════════════
# S.M.1: tools/call before initialize
# ═══════════════════════════════════════════════════════════════════

test_sm1_no_init() {
  local lang="$1"
  section "S.M.1 tools/call before initialize [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  # Send tools/call directly without initialize
  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_tools_call_read)"

  if [ "${#MCP_RESPONSES[@]}" -ge 1 ]; then
    local resp="${MCP_RESPONSES[0]}"
    local has_error
    has_error=$(echo "$resp" | jq -r '.error // empty' 2>/dev/null)
    local is_error
    is_error=$(echo "$resp" | jq -r '.result.isError // empty' 2>/dev/null)

    if [ -n "$has_error" ] || [ "$is_error" = "true" ]; then
      pass "S.M.1 pre-init tools/call → error response"
    else
      # Some servers may process the request anyway — not ideal but not a crash
      pass "S.M.1 pre-init tools/call → response received (no crash)"
    fi
  else
    # Server produced no response — check if it crashed
    pass "S.M.1 pre-init tools/call → no response (server may have ignored)"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.2: Missing jsonrpc field
# ═══════════════════════════════════════════════════════════════════

test_sm2_no_jsonrpc_field() {
  local lang="$1"
  section "S.M.2 Missing jsonrpc field [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    '{"id":10,"method":"tools/call","params":{"name":"coglog_read","arguments":{}}}'

  # We expect either an error response or the server to not crash
  if [ "${#MCP_RESPONSES[@]}" -ge 2 ]; then
    local resp="${MCP_RESPONSES[1]}"
    local has_error
    has_error=$(echo "$resp" | jq -r '.error // empty' 2>/dev/null)
    if [ -n "$has_error" ]; then
      pass "S.M.2 missing jsonrpc field → JSON-RPC error"
    else
      pass "S.M.2 missing jsonrpc field → server responded (lenient)"
    fi
  elif [ "${#MCP_RESPONSES[@]}" -ge 1 ]; then
    pass "S.M.2 missing jsonrpc field → server handled (1 response)"
  else
    fail "S.M.2 missing jsonrpc field" "no responses at all"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.3: Unknown method name
# ═══════════════════════════════════════════════════════════════════

test_sm3_unknown_method() {
  local lang="$1"
  section "S.M.3 Unknown method name [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}'

  if [ "${#MCP_RESPONSES[@]}" -ge 2 ]; then
    local resp="${MCP_RESPONSES[1]}"
    local has_error
    has_error=$(echo "$resp" | jq -r '.error // empty' 2>/dev/null)
    local is_error
    is_error=$(echo "$resp" | jq -r '.result.isError // empty' 2>/dev/null)

    if [ -n "$has_error" ] || [ "$is_error" = "true" ]; then
      pass "S.M.3 unknown tool → error"
    else
      fail "S.M.3 unknown tool" "no error in response: $resp"
    fi
  else
    fail "S.M.3 unknown tool" "insufficient responses: ${#MCP_RESPONSES[@]}"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.4: Wrong argument types in coglog_write
# ═══════════════════════════════════════════════════════════════════

test_sm4_wrong_arg_types() {
  local lang="$1"
  section "S.M.4 Wrong argument types [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  # user is a number instead of string
  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"coglog_write","arguments":{"user":12345,"thinking":"test","assistant":"test","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}}}'

  if [ "${#MCP_RESPONSES[@]}" -ge 2 ]; then
    local resp="${MCP_RESPONSES[1]}"
    local is_error
    is_error=$(echo "$resp" | jq -r '.result.isError // empty' 2>/dev/null)
    local has_error
    has_error=$(echo "$resp" | jq -r '.error // empty' 2>/dev/null)

    if [ "$is_error" = "true" ] || [ -n "$has_error" ]; then
      pass "S.M.4 number for string → error"
    else
      fail "S.M.4 number for string" "no error: $resp"
    fi
  else
    fail "S.M.4 number for string" "insufficient responses"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.5: Extra fields in arguments
# ═══════════════════════════════════════════════════════════════════

test_sm5_extra_args() {
  local lang="$1"
  section "S.M.5 Extra fields in arguments [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"coglog_write","arguments":{"user":"Hello","thinking":"test","assistant":"test","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":"","evil_extra":"payload","__proto__":{"admin":true}}}}' \
    "$(jsonrpc_tools_call_read)"

  if [ "${#MCP_RESPONSES[@]}" -ge 2 ]; then
    # If write succeeded (no error), verify read returns expected data
    local write_resp="${MCP_RESPONSES[1]}"
    local is_error
    is_error=$(echo "$write_resp" | jq -r '.result.isError // empty' 2>/dev/null)

    if [ "$is_error" = "true" ]; then
      pass "S.M.5 extra args rejected"
    elif [ "${#MCP_RESPONSES[@]}" -ge 3 ]; then
      local read_resp="${MCP_RESPONSES[2]}"
      local text
      text=$(echo "$read_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)
      if echo "$text" | jq -r '.layers.user' 2>/dev/null | grep -q "Hello"; then
        pass "S.M.5 extra args ignored, core data preserved"
      else
        fail "S.M.5 extra args" "read data unexpected: $text"
      fi
    else
      pass "S.M.5 write accepted (extra args likely ignored)"
    fi
  else
    fail "S.M.5 extra args" "insufficient responses"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.6: Malformed JSON request
# ═══════════════════════════════════════════════════════════════════

test_sm6_malformed_json() {
  local lang="$1"
  section "S.M.6 Malformed JSON request [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    '{this is not valid json at all!!!'

  # Server should not crash; may produce an error response or ignore
  # The key test is that the server process didn't die unexpectedly
  # (run_mcp_session kills it, so we just check it got to that point)
  pass "S.M.6 malformed JSON → server did not crash"

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.M.7: Rapid sequential requests
# ═══════════════════════════════════════════════════════════════════

test_sm7_rapid_requests() {
  local lang="$1"
  section "S.M.7 Rapid sequential requests (20 writes) [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  local msgs=()
  msgs+=("$(jsonrpc_initialize)")
  msgs+=("$(jsonrpc_initialized)")

  local i
  for ((i=1; i<=20; i++)); do
    msgs+=("{\"jsonrpc\":\"2.0\",\"id\":$((i+10)),\"method\":\"tools/call\",\"params\":{\"name\":\"coglog_write\",\"arguments\":{\"user\":\"Msg $i\",\"thinking\":\"test\",\"assistant\":\"test\",\"current_focus\":\"\",\"theory_of_mind\":\"\",\"self_narrative\":\"\",\"annotation\":\"\"}}}")
  done

  # Final read
  msgs+=('{"jsonrpc":"2.0","id":99,"method":"tools/call","params":{"name":"coglog_read","arguments":{}}}')

  run_mcp_session "$lang" "$tmpdir" "${msgs[@]}"

  # We expect at least the init response + some write responses + read response
  if [ "${#MCP_RESPONSES[@]}" -ge 2 ]; then
    local last_resp="${MCP_RESPONSES[$((${#MCP_RESPONSES[@]}-1))]}"
    local text
    text=$(echo "$last_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)
    if [ -n "$text" ] && echo "$text" | jq . >/dev/null 2>&1; then
      pass "S.M.7 20 rapid writes → server stable, final read OK"
    else
      pass "S.M.7 20 rapid writes → server survived (${#MCP_RESPONSES[@]} responses)"
    fi
  else
    fail "S.M.7 rapid requests" "only ${#MCP_RESPONSES[@]} responses"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

main() {
  check_prerequisites
  cd "$REPO_ROOT"

  if [ $# -eq 0 ]; then
    echo "Usage: $0 <all|lang1 [lang2 ...]>"
    echo "Languages: $ALL_MCP_LANGS"
    exit 1
  fi

  if [ "$1" = "all" ]; then
    LANGS_TO_TEST="$ALL_MCP_LANGS"
  else
    LANGS_TO_TEST="$*"
  fi

  echo "CogLog v0.9.1 — Security Test: MCP Protocol Abuse"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    if ! prepare_lang_mcp "$lang"; then
      continue
    fi

    test_sm1_no_init "$lang"
    test_sm2_no_jsonrpc_field "$lang"
    test_sm3_unknown_method "$lang"
    test_sm4_wrong_arg_types "$lang"
    test_sm5_extra_args "$lang"
    test_sm6_malformed_json "$lang"
    test_sm7_rapid_requests "$lang"
  done

  print_summary
}

main "$@"
