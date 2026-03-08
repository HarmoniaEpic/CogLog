#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Layer 2 MCP Protocol Test Harness
#
# Tests MCP servers for 10 language implementations (Bash excluded).
# Validates JSON-RPC 2.0 over stdio (MCP 2024-11-05).
#
# Usage:
#   ./tests/harness-mcp.sh all          # Run all languages
#   ./tests/harness-mcp.sh rust python  # Run specific languages
#   ./tests/harness-mcp.sh node         # Single language
#
# Prerequisites:
#   - jq
#   - Language toolchains for each language under test
#   - Java JAR and C++ binary must be pre-built
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Counters ──
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ── All supported languages (Bash excluded — no MCP) ──
ALL_LANGS="rust python node go ruby java csharp haskell cl cpp"

# ── Timeout for MCP server responses (seconds) ──
MCP_TIMEOUT=30

# ═══════════════════════════════════════════════════════════════════
# Utility functions
# ═══════════════════════════════════════════════════════════════════

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "  \033[32mPASS\033[0m %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "  \033[31mFAIL\033[0m %s\n" "$1"
  if [ -n "${2:-}" ]; then
    printf "       %s\n" "$2"
  fi
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf "  \033[33mSKIP\033[0m %s\n" "$1"
}

section() {
  printf "\n── %s ──\n" "$1"
}

# ═══════════════════════════════════════════════════════════════════
# MCP server management
# ═══════════════════════════════════════════════════════════════════

# Get the MCP server command for a language.
# Usage: get_mcp_cmd <lang> <coglog_dir>
# Returns the command array to start the server.
start_mcp_server() {
  local lang="$1"
  local coglog_dir="$2"

  case "$lang" in
    rust)
      cargo run --manifest-path "$REPO_ROOT/rust/Cargo.toml" -p coglog-mcp -q -- \
        --coglog-dir "$coglog_dir"
      ;;
    python)
      PYTHONPATH="$REPO_ROOT/python/coglog-mcp/src" python3 -m coglog_mcp \
        --coglog-dir "$coglog_dir"
      ;;
    node)
      node "$REPO_ROOT/node/coglog-mcp/index.mjs" \
        --coglog-dir "$coglog_dir"
      ;;
    go)
      (cd "$REPO_ROOT/go" && go run ./cmd/coglog-mcp \
        --coglog-dir "$coglog_dir")
      ;;
    ruby)
      ruby -I"$REPO_ROOT/ruby/coglog-mcp/lib" \
        -e "require 'coglog_mcp'; CogLogMCP.run" \
        -- --coglog-dir "$coglog_dir"
      ;;
    java)
      java -jar "$REPO_ROOT/java/coglog-mcp/target/coglog-mcp.jar" \
        --coglog-dir "$coglog_dir"
      ;;
    csharp)
      dotnet run --project "$REPO_ROOT/csharp/coglog-mcp" -- \
        --coglog-dir "$coglog_dir"
      ;;
    haskell)
      (cd "$REPO_ROOT/haskell/coglog-mcp" && cabal -v0 run coglog-mcp -- \
        --coglog-dir "$coglog_dir")
      ;;
    cl)
      sbcl --script "$REPO_ROOT/common-lisp/coglog-mcp/mcp-server.lisp" \
        --coglog-dir "$coglog_dir"
      ;;
    cpp)
      "$REPO_ROOT/cpp-coglog-mcp" \
        --coglog-dir "$coglog_dir"
      ;;
  esac
}

# Send JSON-RPC messages to a running MCP server and capture responses.
# Usage: run_mcp_session <lang> <coglog_dir> <<< "json-rpc messages"
# Each message is a separate line. Responses are captured in $MCP_RESPONSES (array).
# The function starts the server, sends all messages, and kills it.
run_mcp_session() {
  local lang="$1"
  local coglog_dir="$2"
  shift 2

  local fifo_in; fifo_in=$(mktemp -u)
  local resp_file; resp_file=$(mktemp)
  local err_file; err_file=$(mktemp)
  mkfifo "$fifo_in"

  # Start MCP server in background, reading from fifo
  start_mcp_server "$lang" "$coglog_dir" <"$fifo_in" >"$resp_file" 2>"$err_file" &
  local server_pid=$!

  # Open fifo for writing (keep fd open)
  exec 3>"$fifo_in"

  # Send all messages passed as arguments
  for msg in "$@"; do
    echo "$msg" >&3
    # Small delay to let server process each message
    sleep 0.1
  done

  # Wait for responses (with timeout in real seconds)
  # Count only JSON-RPC requests (messages with "id":) — notifications have no response.
  local start_time=$SECONDS
  local expected_count=0
  for msg in "$@"; do
    case "$msg" in *'"id"'*) expected_count=$((expected_count + 1)) ;; esac
  done
  while [ $((SECONDS - start_time)) -lt "$MCP_TIMEOUT" ]; do
    local line_count
    line_count=$(wc -l < "$resp_file" 2>/dev/null || echo 0)
    if [ "$line_count" -ge "$expected_count" ]; then
      break
    fi
    sleep 0.2
  done

  # Close fifo and kill server
  exec 3>&-
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
  rm -f "$fifo_in"

  MCP_RESPONSES=()
  while IFS= read -r line; do
    [ -n "$line" ] && MCP_RESPONSES+=("$line")
  done < "$resp_file"

  MCP_STDERR=$(cat "$err_file")
  rm -f "$resp_file" "$err_file"
}

# ═══════════════════════════════════════════════════════════════════
# JSON-RPC message builders
# ═══════════════════════════════════════════════════════════════════

jsonrpc_initialize() {
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"coglog-test","version":"0.9.1"}}}'
}

jsonrpc_initialized() {
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
}

jsonrpc_tools_list() {
  echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
}

jsonrpc_tools_call_read() {
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"coglog_read","arguments":{}}}'
}

jsonrpc_tools_call_write() {
  cat <<'JSONEOF'
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"coglog_write","arguments":{"user":"Hello","thinking":"User greeted me","assistant":"Hi there!","current_focus":"greeting","theory_of_mind":"friendly","self_narrative":"conversational partner","annotation":"follow up on tone"}}}
JSONEOF
}

jsonrpc_tools_call_clear() {
  echo '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"coglog_clear","arguments":{}}}'
}

jsonrpc_tools_call_write_invalid() {
  echo '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"coglog_write","arguments":{"user":"","thinking":"test","assistant":"test","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}}}'
}

# ═══════════════════════════════════════════════════════════════════
# Test group 13: MCP Protocol
# ═══════════════════════════════════════════════════════════════════

test_13_mcp() {
  local lang="$1"
  section "13. MCP Protocol [$lang]"

  # ── 13.1 Initialize handshake ──
  local tmpdir; tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    "$(jsonrpc_tools_list)"

  # 13.1 — initialize response
  if [ "${#MCP_RESPONSES[@]}" -lt 1 ]; then
    fail "13.1 initialize handshake" "no response received"
    rm -rf "$tmpdir"
    return
  fi

  local init_resp="${MCP_RESPONSES[0]}"
  local has_pv; has_pv=$(echo "$init_resp" | jq -r '.result.protocolVersion // empty' 2>/dev/null)
  local has_tools; has_tools=$(echo "$init_resp" | jq -r '.result.capabilities.tools // empty' 2>/dev/null)
  local has_si; has_si=$(echo "$init_resp" | jq -r '.result.serverInfo.name // empty' 2>/dev/null)

  if [ -n "$has_pv" ] && [ -n "$has_si" ]; then
    pass "13.1 initialize → protocolVersion, serverInfo"
  else
    fail "13.1 initialize handshake" "response: $init_resp"
  fi
  rm -rf "$tmpdir"

  # ── 13.2 tools/list ──
  # The tools/list response is the 2nd response (notifications/initialized has no response)
  if [ "${#MCP_RESPONSES[@]}" -lt 2 ]; then
    fail "13.2 tools/list" "no response received"
    return
  fi

  local list_resp="${MCP_RESPONSES[1]}"
  local tool_names; tool_names=$(echo "$list_resp" | jq -r '[.result.tools[].name] | sort | join(",")' 2>/dev/null)

  if echo "$tool_names" | grep -q "coglog_clear" && \
     echo "$tool_names" | grep -q "coglog_read" && \
     echo "$tool_names" | grep -q "coglog_write"; then
    pass "13.2 tools/list → coglog_read, coglog_write, coglog_clear"
  else
    fail "13.2 tools/list" "got tools: $tool_names"
  fi

  # ── 13.3 coglog_read initial state ──
  tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    "$(jsonrpc_tools_call_read)"

  if [ "${#MCP_RESPONSES[@]}" -lt 2 ]; then
    fail "13.3 coglog_read initial" "no response received"
    rm -rf "$tmpdir"
    return
  fi

  local read_resp="${MCP_RESPONSES[1]}"
  local read_text; read_text=$(echo "$read_resp" | jq -r '.result.content[0].text // empty' 2>/dev/null)

  if echo "$read_text" | grep -q "(no coglog found)"; then
    pass "13.3 coglog_read initial → '(no coglog found)'"
  else
    fail "13.3 coglog_read initial" "got: $read_text"
  fi
  rm -rf "$tmpdir"

  # ── 13.4 coglog_write → coglog_read ──
  tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    "$(jsonrpc_tools_call_write)" \
    "$(jsonrpc_tools_call_read)"

  if [ "${#MCP_RESPONSES[@]}" -lt 3 ]; then
    fail "13.4 write → read" "insufficient responses: ${#MCP_RESPONSES[@]}"
    rm -rf "$tmpdir"
    return
  fi

  # Response 0: initialize, Response 1: write, Response 2: read
  local write_resp="${MCP_RESPONSES[1]}"
  local read_after_write="${MCP_RESPONSES[2]}"
  local rat; rat=$(echo "$read_after_write" | jq -r '.result.content[0].text // empty' 2>/dev/null)

  if [ -n "$rat" ] && echo "$rat" | jq -r '.layers.user' 2>/dev/null | grep -q "Hello"; then
    pass "13.4 coglog_write → coglog_read round-trip"
  else
    fail "13.4 write → read" "read text: $rat"
  fi
  rm -rf "$tmpdir"

  # ── 13.5 coglog_clear → coglog_read ──
  tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    "$(jsonrpc_tools_call_write)" \
    "$(jsonrpc_tools_call_clear)" \
    "$(jsonrpc_tools_call_read)"

  if [ "${#MCP_RESPONSES[@]}" -lt 4 ]; then
    fail "13.5 clear → read" "insufficient responses: ${#MCP_RESPONSES[@]}"
    rm -rf "$tmpdir"
    return
  fi

  # Response 0: initialize, 1: write, 2: clear, 3: read
  local read_after_clear="${MCP_RESPONSES[3]}"
  local rac; rac=$(echo "$read_after_clear" | jq -r '.result.content[0].text // empty' 2>/dev/null)

  if echo "$rac" | grep -q "(no coglog found)"; then
    pass "13.5 coglog_clear → coglog_read → '(no coglog found)'"
  else
    fail "13.5 clear → read" "got: $rac"
  fi
  rm -rf "$tmpdir"

  # ── 13.6 coglog_write with invalid arguments ──
  tmpdir=$(mktemp -d)

  run_mcp_session "$lang" "$tmpdir" \
    "$(jsonrpc_initialize)" \
    "$(jsonrpc_initialized)" \
    "$(jsonrpc_tools_call_write_invalid)"

  if [ "${#MCP_RESPONSES[@]}" -lt 2 ]; then
    fail "13.6 invalid write" "no response received"
    rm -rf "$tmpdir"
    return
  fi

  local inv_resp="${MCP_RESPONSES[1]}"
  local is_error; is_error=$(echo "$inv_resp" | jq -r '.result.isError // empty' 2>/dev/null)
  local has_error; has_error=$(echo "$inv_resp" | jq -r '.error // empty' 2>/dev/null)

  if [ "$is_error" = "true" ] || [ -n "$has_error" ]; then
    pass "13.6 invalid write → isError: true"
  else
    fail "13.6 invalid write → isError" "response: $inv_resp"
  fi
  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

check_prerequisites() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed." >&2
    exit 1
  fi
}

main() {
  check_prerequisites

  cd "$REPO_ROOT"

  if [ $# -eq 0 ]; then
    echo "Usage: $0 <all|lang1 [lang2 ...]>"
    echo "Languages: $ALL_LANGS"
    exit 1
  fi

  if [ "$1" = "all" ]; then
    LANGS_TO_TEST="$ALL_LANGS"
  else
    LANGS_TO_TEST="$*"
  fi

  echo "CogLog v0.9.1 — Layer 2 MCP Protocol Test Harness"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    test_13_mcp "$lang"
  done

  # Summary
  printf "\n\033[1m════ Summary ════\033[0m\n"
  printf "  \033[32mPASS: %d\033[0m\n" "$PASS_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "  \033[31mFAIL: %d\033[0m\n" "$FAIL_COUNT"
  else
    printf "  FAIL: 0\n"
  fi
  if [ "$SKIP_COUNT" -gt 0 ]; then
    printf "  \033[33mSKIP: %d\033[0m\n" "$SKIP_COUNT"
  fi

  if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
  fi
}

main "$@"
