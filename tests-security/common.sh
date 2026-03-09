#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test Common Utilities
#
# Shared functions for all security test harnesses.
# Extracted from tests/harness.sh to avoid code duplication.
#
# Usage (from other harness scripts):
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   source "$SCRIPT_DIR/common.sh"
# ═══════════════════════════════════════════════════════════════════

SECURITY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SECURITY_DIR/.." && pwd)"
FIXTURES_SECURITY="$SECURITY_DIR/fixtures-security"
FIXTURES="$REPO_ROOT/tests/fixtures"

# ── Counters ──
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ── All supported languages ──
ALL_LANGS="rust python node go ruby java csharp haskell cl cpp bash"

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
# CLI runner (from tests/harness.sh)
# ═══════════════════════════════════════════════════════════════════

run_cli() {
  local lang="$1"; shift
  local tmpout; tmpout=$(mktemp)
  local tmperr; tmperr=$(mktemp)

  CLI_EXIT=0
  case "$lang" in
    rust)
      cargo run --manifest-path "$REPO_ROOT/rust/Cargo.toml" -p coglog -q -- "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    python)
      PYTHONPATH="$REPO_ROOT/python/coglog/src" python3 -m coglog "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    node)
      node "$REPO_ROOT/node/coglog/index.mjs" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    go)
      (cd "$REPO_ROOT/go" && go run ./cmd/coglog-cli "$@") \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    ruby)
      ruby -I"$REPO_ROOT/ruby/coglog/lib" "$REPO_ROOT/ruby/coglog/bin/coglog-cli" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    java)
      java -jar "$REPO_ROOT/java/coglog/target/coglog-cli.jar" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    csharp)
      dotnet run --project "$REPO_ROOT/csharp/coglog" -- "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    haskell)
      (cd "$REPO_ROOT/haskell/coglog" && cabal -v0 run coglog -- "$@") \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    cl)
      sbcl --script "$REPO_ROOT/common-lisp/coglog/adapter.lisp" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    cpp)
      "$REPO_ROOT/cpp-coglog-cli" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    bash)
      bash "$REPO_ROOT/bash/coglog/coglog-cli.sh" "$@" \
        >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
  esac

  CLI_STDOUT=$(cat "$tmpout")
  CLI_STDERR=$(cat "$tmperr")
  rm -f "$tmpout" "$tmperr"
}

run_cli_stdin() {
  local lang="$1"; shift
  local input_file="$1"; shift
  local tmpout; tmpout=$(mktemp)
  local tmperr; tmperr=$(mktemp)

  CLI_EXIT=0
  case "$lang" in
    rust)
      cargo run --manifest-path "$REPO_ROOT/rust/Cargo.toml" -p coglog -q -- "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    python)
      PYTHONPATH="$REPO_ROOT/python/coglog/src" python3 -m coglog "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    node)
      node "$REPO_ROOT/node/coglog/index.mjs" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    go)
      (cd "$REPO_ROOT/go" && go run ./cmd/coglog-cli "$@") \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    ruby)
      ruby -I"$REPO_ROOT/ruby/coglog/lib" "$REPO_ROOT/ruby/coglog/bin/coglog-cli" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    java)
      java -jar "$REPO_ROOT/java/coglog/target/coglog-cli.jar" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    csharp)
      dotnet run --project "$REPO_ROOT/csharp/coglog" -- "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    haskell)
      (cd "$REPO_ROOT/haskell/coglog" && cabal -v0 run coglog -- "$@") \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    cl)
      sbcl --script "$REPO_ROOT/common-lisp/coglog/adapter.lisp" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    cpp)
      "$REPO_ROOT/cpp-coglog-cli" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
    bash)
      bash "$REPO_ROOT/bash/coglog/coglog-cli.sh" "$@" \
        <"$input_file" >"$tmpout" 2>"$tmperr" || CLI_EXIT=$?
      ;;
  esac

  CLI_STDOUT=$(cat "$tmpout")
  CLI_STDERR=$(cat "$tmperr")
  rm -f "$tmpout" "$tmperr"
}

# Run CLI with stdin from a string (not a file).
# Usage: run_cli_string <lang> <string> <args...>
run_cli_string() {
  local lang="$1"; shift
  local input_string="$1"; shift
  local tmpfile; tmpfile=$(mktemp)
  printf '%s' "$input_string" > "$tmpfile"
  run_cli_stdin "$lang" "$tmpfile" "$@"
  rm -f "$tmpfile"
}

setup_tmpdir() {
  TEST_TMPDIR=$(mktemp -d)
  export COGLOG_DIR="$TEST_TMPDIR"
}

teardown_tmpdir() {
  rm -rf "$TEST_TMPDIR"
  unset COGLOG_DIR
}

# ═══════════════════════════════════════════════════════════════════
# Toolchain check & auto-build (from tests/harness.sh)
# ═══════════════════════════════════════════════════════════════════

require_cmd() {
  local cmd="$1" lang="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    skip "$lang: '$cmd' not found — skipping"
    return 1
  fi
  return 0
}

build_java_jar() {
  local jar="$1" main_class="$2" src_dir="$3"
  [ -f "$jar" ] && return 0
  echo "  Building $jar ..."
  if command -v mvn >/dev/null 2>&1; then
    local pom; pom="$(dirname "$(dirname "$jar")")/pom.xml"
    if mvn -f "$pom" package -q >/dev/null 2>&1; then
      return 0
    fi
    echo "  mvn failed, falling back to javac ..."
  fi
  local tmp; tmp=$(mktemp -d)
  javac -d "$tmp" "$src_dir"/*.java
  mkdir -p "$(dirname "$jar")"
  jar cfe "$jar" "$main_class" -C "$tmp" .
  rm -rf "$tmp"
}

build_cpp_binary() {
  local bin="$1" src="$2"
  [ -f "$bin" ] && return 0
  echo "  Building $bin ..."
  c++ -std=c++17 -Os -o "$bin" "$src"
}

prepare_lang() {
  local lang="$1"
  case "$lang" in
    rust)     require_cmd cargo "$lang"  || return 1 ;;
    python)   require_cmd python3 "$lang" || return 1 ;;
    node)     require_cmd node "$lang"   || return 1 ;;
    go)       require_cmd go "$lang"     || return 1 ;;
    ruby)     require_cmd ruby "$lang"   || return 1 ;;
    java)
      require_cmd java "$lang"  || return 1
      require_cmd javac "$lang" || return 1
      build_java_jar \
        "$REPO_ROOT/java/coglog/target/coglog-cli.jar" \
        "io.github.harmoniaepic.coglog.Main" \
        "$REPO_ROOT/java/coglog/src/main/java/io/github/harmoniaepic/coglog"
      ;;
    csharp)   require_cmd dotnet "$lang" || return 1 ;;
    haskell)  require_cmd cabal "$lang"  || return 1 ;;
    cl)       require_cmd sbcl "$lang"   || return 1 ;;
    cpp)
      require_cmd c++ "$lang" || return 1
      build_cpp_binary \
        "$REPO_ROOT/cpp-coglog-cli" \
        "$REPO_ROOT/cpp/coglog/coglog-cli.cpp"
      ;;
    bash)     ;; # always available
  esac
}

# ═══════════════════════════════════════════════════════════════════
# MCP server management (from tests/harness-mcp.sh)
# ═══════════════════════════════════════════════════════════════════

MCP_TIMEOUT=30

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

run_mcp_session() {
  local lang="$1"
  local coglog_dir="$2"
  shift 2

  local fifo_in; fifo_in=$(mktemp -u)
  local resp_file; resp_file=$(mktemp)
  local err_file; err_file=$(mktemp)
  mkfifo "$fifo_in"

  start_mcp_server "$lang" "$coglog_dir" <"$fifo_in" >"$resp_file" 2>"$err_file" &
  local server_pid=$!

  exec 3>"$fifo_in"

  for msg in "$@"; do
    echo "$msg" >&3
    sleep 0.1
  done

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

prepare_lang_mcp() {
  local lang="$1"
  case "$lang" in
    bash)
      skip "$lang: no MCP server"
      return 1
      ;;
    java)
      require_cmd java "$lang"  || return 1
      require_cmd javac "$lang" || return 1
      build_java_jar \
        "$REPO_ROOT/java/coglog-mcp/target/coglog-mcp.jar" \
        "io.github.harmoniaepic.coglog.mcp.McpServer" \
        "$REPO_ROOT/java/coglog-mcp/src/main/java/io/github/harmoniaepic/coglog/mcp"
      ;;
    cpp)
      require_cmd c++ "$lang" || return 1
      build_cpp_binary \
        "$REPO_ROOT/cpp-coglog-mcp" \
        "$REPO_ROOT/cpp/coglog-mcp/coglog-mcp.cpp"
      ;;
    *)
      prepare_lang "$lang" || return 1
      ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════
# Common main helpers
# ═══════════════════════════════════════════════════════════════════

check_prerequisites() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required but not installed." >&2
    exit 1
  fi
}

parse_lang_args() {
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
}

print_summary() {
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
    return 1
  fi
}
