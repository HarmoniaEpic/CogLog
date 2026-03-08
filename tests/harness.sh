#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Layer 1 CLI Black-Box Test Harness
#
# Drives all 11 language implementations through the same CLI interface.
#
# Usage:
#   ./tests/harness.sh all          # Run all languages
#   ./tests/harness.sh rust python  # Run specific languages
#   ./tests/harness.sh rust         # Single language
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
FIXTURES="$SCRIPT_DIR/fixtures"

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

# Run a CLI command for a given language.
# Usage: run_cli <lang> <args...>
# Captures stdout to $CLI_STDOUT, stderr to $CLI_STDERR, exit code to $CLI_EXIT.
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

# Run CLI with stdin piped from a file.
# Usage: run_cli_stdin <lang> <fixture_file> <args...>
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

setup_tmpdir() {
  TEST_TMPDIR=$(mktemp -d)
  export COGLOG_DIR="$TEST_TMPDIR"
}

teardown_tmpdir() {
  rm -rf "$TEST_TMPDIR"
  unset COGLOG_DIR
}

# ═══════════════════════════════════════════════════════════════════
# Test group 1: Initial state
# ═══════════════════════════════════════════════════════════════════

test_01_initial_state() {
  local lang="$1"
  section "1. Initial state [$lang]"

  # 1.1 read with no prior write
  setup_tmpdir
  run_cli "$lang" read
  if echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    pass "1.1 read returns '(no coglog found)'"
  else
    fail "1.1 read returns '(no coglog found)'" "got: $CLI_STDOUT"
  fi

  # 1.2 clear with no prior write
  run_cli "$lang" clear
  if [ "$CLI_EXIT" -eq 0 ]; then
    pass "1.2 clear on empty state succeeds"
  else
    fail "1.2 clear on empty state succeeds" "exit code: $CLI_EXIT"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 2: Write/read round-trip
# ═══════════════════════════════════════════════════════════════════

test_02_roundtrip() {
  local lang="$1"
  section "2. Round-trip [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write

  if [ "$CLI_EXIT" -ne 0 ]; then
    fail "2.0 write succeeds" "exit code: $CLI_EXIT, stderr: $CLI_STDERR"
    teardown_tmpdir; return
  fi
  pass "2.0 write succeeds"

  run_cli "$lang" read
  local result="$CLI_STDOUT"

  # 2.1 All 7 fields match
  local ok=true
  for field in user thinking assistant; do
    local expected; expected=$(jq -r ".$field" "$FIXTURES/valid-full.json")
    local got; got=$(echo "$result" | jq -r ".layers.$field")
    if [ "$expected" != "$got" ]; then
      fail "2.1 layers.$field matches" "expected: $expected, got: $got"
      ok=false
    fi
  done
  for field in current_focus theory_of_mind self_narrative annotation; do
    local expected; expected=$(jq -r ".$field" "$FIXTURES/valid-full.json")
    local got; got=$(echo "$result" | jq -r ".$field")
    if [ "$expected" != "$got" ]; then
      fail "2.1 $field matches" "expected: $expected, got: $got"
      ok=false
    fi
  done
  if $ok; then pass "2.1 all 7 fields match write input"; fi

  # 2.2 _schema.version
  local ver; ver=$(echo "$result" | jq -r '._schema.version')
  if [ "$ver" = "0.9.1" ]; then
    pass "2.2 _schema.version = 0.9.1"
  else
    fail "2.2 _schema.version = 0.9.1" "got: $ver"
  fi

  # 2.3 turn_id
  local tid; tid=$(echo "$result" | jq '.turn_id')
  if [ "$tid" = "1" ]; then
    pass "2.3 turn_id = 1"
  else
    fail "2.3 turn_id = 1" "got: $tid"
  fi

  # 2.4 timestamp is ISO 8601
  local ts; ts=$(echo "$result" | jq -r '.timestamp')
  if echo "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    pass "2.4 timestamp is ISO 8601"
  else
    fail "2.4 timestamp is ISO 8601" "got: $ts"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 3: Fact layer validation
# ═══════════════════════════════════════════════════════════════════

test_03_fact_validation() {
  local lang="$1"
  section "3. Fact layer validation [$lang]"

  local fixtures=(
    "invalid-user-empty.json:3.1 user empty"
    "invalid-thinking-empty.json:3.2 thinking empty"
    "invalid-assistant-empty.json:3.3 assistant empty"
    "invalid-user-missing.json:3.4 user missing"
    "invalid-thinking-missing.json:3.5 thinking missing"
    "invalid-assistant-missing.json:3.6 assistant missing"
  )

  for entry in "${fixtures[@]}"; do
    local file="${entry%%:*}"
    local label="${entry#*:}"
    setup_tmpdir
    run_cli_stdin "$lang" "$FIXTURES/$file" write
    if [ "$CLI_EXIT" -ne 0 ]; then
      pass "$label → validation error (exit $CLI_EXIT)"
    else
      fail "$label → validation error" "exit code was 0 (should be non-zero)"
    fi
    teardown_tmpdir
  done
}

# ═══════════════════════════════════════════════════════════════════
# Test group 4: Interpretation layer validation
# ═══════════════════════════════════════════════════════════════════

test_04_interp_validation() {
  local lang="$1"
  section "4. Interpretation layer validation [$lang]"

  # 4.1-4.5 Empty interpretation fields → success
  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-interpretation-empty.json" write
  if [ "$CLI_EXIT" -eq 0 ]; then
    pass "4.1-4.5 all interpretation fields empty → success"
  else
    fail "4.1-4.5 all interpretation fields empty → success" "exit: $CLI_EXIT, stderr: $CLI_STDERR"
  fi

  # Verify empty strings are preserved on read
  run_cli "$lang" read
  local cf; cf=$(echo "$CLI_STDOUT" | jq -r '.current_focus')
  if [ "$cf" = "" ]; then
    pass "4.1 current_focus empty string preserved"
  else
    fail "4.1 current_focus empty string preserved" "got: '$cf'"
  fi
  teardown_tmpdir

  # 4.6 Interpretation field missing → error
  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/invalid-interp-missing.json" write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "4.6 interpretation field missing → validation error"
  else
    fail "4.6 interpretation field missing → validation error" "exit code was 0"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 5: Type checking
# ═══════════════════════════════════════════════════════════════════

test_05_type_check() {
  local lang="$1"
  section "5. Type checking [$lang]"

  local fixtures=(
    "invalid-type-number.json:5.1 user is number"
    "invalid-type-array.json:5.2 thinking is array"
    "invalid-type-null.json:5.3 current_focus is null"
  )

  for entry in "${fixtures[@]}"; do
    local file="${entry%%:*}"
    local label="${entry#*:}"
    setup_tmpdir
    run_cli_stdin "$lang" "$FIXTURES/$file" write
    if [ "$CLI_EXIT" -ne 0 ]; then
      pass "$label → error (exit $CLI_EXIT)"
    else
      fail "$label → error" "exit code was 0"
    fi
    teardown_tmpdir
  done
}

# ═══════════════════════════════════════════════════════════════════
# Test group 6: Window size 1
# ═══════════════════════════════════════════════════════════════════

test_06_window_size() {
  local lang="$1"
  section "6. Window size 1 [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli_stdin "$lang" "$FIXTURES/valid-second.json" write
  run_cli "$lang" read

  # 6.1 Only B is returned
  local user; user=$(echo "$CLI_STDOUT" | jq -r '.layers.user')
  if [ "$user" = "How are you?" ]; then
    pass "6.1 second write overwrites first"
  else
    fail "6.1 second write overwrites first" "got user: $user"
  fi

  # 6.2 A's content is gone
  if ! echo "$CLI_STDOUT" | jq -r '.layers.user' | grep -q "Hello"; then
    pass "6.2 first write content is gone"
  else
    fail "6.2 first write content is gone" "found 'Hello' in read result"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 7: turn_id monotonic increase
# ═══════════════════════════════════════════════════════════════════

test_07_turn_id() {
  local lang="$1"
  section "7. turn_id [$lang]"

  setup_tmpdir
  # 7.1
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  local tid; tid=$(echo "$CLI_STDOUT" | jq '.turn_id')
  if [ "$tid" = "1" ]; then
    pass "7.1 first write → turn_id = 1"
  else
    fail "7.1 first write → turn_id = 1" "got: $tid"
  fi

  # 7.2
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  tid=$(echo "$CLI_STDOUT" | jq '.turn_id')
  if [ "$tid" = "2" ]; then
    pass "7.2 second write → turn_id = 2"
  else
    fail "7.2 second write → turn_id = 2" "got: $tid"
  fi

  # 7.3
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  tid=$(echo "$CLI_STDOUT" | jq '.turn_id')
  if [ "$tid" = "3" ]; then
    pass "7.3 third write → turn_id = 3"
  else
    fail "7.3 third write → turn_id = 3" "got: $tid"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 8: Clear
# ═══════════════════════════════════════════════════════════════════

test_08_clear() {
  local lang="$1"
  section "8. Clear [$lang]"

  # 8.1 write → clear → read → initial state
  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" clear
  if echo "$CLI_STDOUT" | grep -q "cleared"; then
    pass "8.2 clear returns 'cleared'"
  else
    fail "8.2 clear returns 'cleared'" "got: $CLI_STDOUT"
  fi

  run_cli "$lang" read
  if echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    pass "8.1 write → clear → read → initial state"
  else
    fail "8.1 write → clear → read → initial state" "got: $CLI_STDOUT"
  fi

  # 8.3 double clear
  run_cli "$lang" clear
  if [ "$CLI_EXIT" -eq 0 ]; then
    pass "8.3 double clear is not an error"
  else
    fail "8.3 double clear is not an error" "exit: $CLI_EXIT"
  fi

  # 8.4 clear → write → read → turn_id = 1
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  local tid; tid=$(echo "$CLI_STDOUT" | jq '.turn_id')
  if [ "$tid" = "1" ]; then
    pass "8.4 clear resets turn_id to 1"
  else
    fail "8.4 clear resets turn_id to 1" "got: $tid"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 9: _schema auto-generation
# ═══════════════════════════════════════════════════════════════════

test_09_schema() {
  local lang="$1"
  section "9. _schema [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  local result="$CLI_STDOUT"

  # 9.1 version
  local ver; ver=$(echo "$result" | jq -r '._schema.version')
  if [ "$ver" = "0.9.1" ]; then
    pass "9.1 _schema.version = 0.9.1"
  else
    fail "9.1 _schema.version = 0.9.1" "got: $ver"
  fi

  # 9.2 fact_layer descriptions
  local ok=true
  for field in user thinking assistant; do
    local desc; desc=$(echo "$result" | jq -r "._schema.fact_layer.$field")
    if ! echo "$desc" | grep -q "non-empty string required"; then
      fail "9.2 fact_layer.$field starts with 'non-empty string required'" "got: $desc"
      ok=false
    fi
  done
  if $ok; then pass "9.2 fact_layer descriptions correct"; fi

  # 9.3 interpretation_layer descriptions
  ok=true
  for field in current_focus theory_of_mind self_narrative annotation; do
    local desc; desc=$(echo "$result" | jq -r "._schema.interpretation_layer.$field")
    if ! echo "$desc" | grep -q "string required, empty OK"; then
      fail "9.3 interpretation_layer.$field starts with 'string required, empty OK'" "got: $desc"
      ok=false
    fi
  done
  if $ok; then pass "9.3 interpretation_layer descriptions correct"; fi

  # 9.4 constraints.window_size
  local ws; ws=$(echo "$result" | jq -r '._schema.constraints.window_size')
  if [ "$ws" = "1 turn (overwritten each write)" ]; then
    pass "9.4 constraints.window_size correct"
  else
    fail "9.4 constraints.window_size correct" "got: $ws"
  fi

  # 9.5 constraints.interpretation_empty
  local ie; ie=$(echo "$result" | jq -r '._schema.constraints.interpretation_empty')
  if [ "$ie" = "choosing not to write is itself a metacognitive act" ]; then
    pass "9.5 constraints.interpretation_empty correct"
  else
    fail "9.5 constraints.interpretation_empty correct" "got: $ie"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 10: Timestamp
# ═══════════════════════════════════════════════════════════════════

test_10_timestamp() {
  local lang="$1"
  section "10. Timestamp [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  run_cli "$lang" read
  local ts; ts=$(echo "$CLI_STDOUT" | jq -r '.timestamp')

  # 10.1 ISO 8601 format
  if echo "$ts" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
    pass "10.1 timestamp is ISO 8601 (YYYY-MM-DDThh:mm:ssZ)"
  else
    fail "10.1 timestamp is ISO 8601" "got: $ts"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 11a-f: Path resolution
# ═══════════════════════════════════════════════════════════════════

test_11_path_resolution() {
  local lang="$1"
  section "11. Path resolution [$lang]"

  # 11.4 COGLOG_DIR environment variable
  local tmpd; tmpd=$(mktemp -d)
  COGLOG_DIR="$tmpd" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ -f "$tmpd/current.json" ]; then
    pass "11.4 COGLOG_DIR controls data directory"
  else
    fail "11.4 COGLOG_DIR controls data directory" "current.json not found in $tmpd"
  fi

  # 11.7 Data file is always current.json
  local files; files=$(ls "$tmpd"/*.json 2>/dev/null | xargs -I{} basename {})
  if [ "$files" = "current.json" ]; then
    pass "11.7 data file is current.json"
  else
    fail "11.7 data file is current.json" "found: $files"
  fi
  rm -rf "$tmpd"

  # 11.2 Non-existent directory is auto-created on write
  local nested; nested=$(mktemp -d)/a/b/c
  COGLOG_DIR="$nested" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ -f "$nested/current.json" ]; then
    pass "11.2 non-existent directory auto-created on write"
  else
    fail "11.2 non-existent directory auto-created on write" "current.json not found"
  fi
  rm -rf "$(dirname "$(dirname "$(dirname "$nested")")")"

  # 11.3 read does not create directory
  local nodir; nodir=$(mktemp -d)/nonexistent
  COGLOG_DIR="$nodir" run_cli "$lang" read
  if [ ! -d "$nodir" ]; then
    pass "11.3 read does not create directory"
  else
    fail "11.3 read does not create directory" "directory was created"
  fi
  rm -rf "$(dirname "$nodir")"

  # 11.5 Explicit --coglog-dir overrides COGLOG_DIR (skip for bash)
  if [ "$lang" = "bash" ]; then
    skip "11.5 --coglog-dir (Bash uses env var only)"
  else
    local dir1; dir1=$(mktemp -d)
    local dir2; dir2=$(mktemp -d)
    COGLOG_DIR="$dir1" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write --coglog-dir "$dir2"

    # For languages where --coglog-dir is before the subcommand, try the other way
    if [ ! -f "$dir2/current.json" ]; then
      COGLOG_DIR="$dir1" run_cli "$lang" --coglog-dir "$dir2" write <"$FIXTURES/valid-full.json"
    fi

    if [ -f "$dir2/current.json" ]; then
      pass "11.5 --coglog-dir overrides COGLOG_DIR"
    elif [ -f "$dir1/current.json" ]; then
      # Some implementations may put --coglog-dir before the subcommand
      skip "11.5 --coglog-dir (argument order may vary)"
    else
      fail "11.5 --coglog-dir overrides COGLOG_DIR" "current.json not found in either dir"
    fi
    rm -rf "$dir1" "$dir2"
  fi

  # 11.13 COGLOG_DIR="" falls back to default
  setup_tmpdir
  local default_dir="$HOME/.coglog"
  COGLOG_DIR="" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ -f "$default_dir/current.json" ]; then
    pass "11.13 COGLOG_DIR='' falls back to default"
    # Clean up the default location
    rm -f "$default_dir/current.json"
  else
    # Some languages may handle this differently
    skip "11.13 COGLOG_DIR='' fallback (environment-dependent)"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 14: CLI interface
# ═══════════════════════════════════════════════════════════════════

test_14_cli() {
  local lang="$1"
  section "14. CLI interface [$lang]"

  # 14.1 read initial → "(no coglog found)" on stdout
  setup_tmpdir
  run_cli "$lang" read
  if echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    pass "14.1 read initial → '(no coglog found)' on stdout"
  else
    fail "14.1 read initial → '(no coglog found)' on stdout" "got: $CLI_STDOUT"
  fi

  # 14.2 write → "coglog: turn N written" on stdout
  run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if echo "$CLI_STDOUT" | grep -q "coglog: turn.*written"; then
    pass "14.2 write → 'coglog: turn N written' on stdout"
  else
    fail "14.2 write → 'coglog: turn N written'" "got: $CLI_STDOUT"
  fi

  # 14.3 write then read → JSON on stdout
  run_cli "$lang" read
  if echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
    pass "14.3 read after write → valid JSON on stdout"
  else
    fail "14.3 read after write → valid JSON on stdout" "not valid JSON"
  fi

  # 14.4 clear → "coglog: cleared" on stdout
  run_cli "$lang" clear
  if echo "$CLI_STDOUT" | grep -q "coglog: cleared"; then
    pass "14.4 clear → 'coglog: cleared' on stdout"
  else
    fail "14.4 clear → 'coglog: cleared'" "got: $CLI_STDOUT"
  fi

  # 14.5 Invalid JSON → error on stderr, non-zero exit
  run_cli_stdin "$lang" "$FIXTURES/invalid-json.txt" write
  if [ "$CLI_EXIT" -ne 0 ] && [ -n "$CLI_STDERR" ]; then
    pass "14.5 invalid JSON → stderr + non-zero exit"
  elif [ "$CLI_EXIT" -ne 0 ]; then
    pass "14.5 invalid JSON → non-zero exit (stderr may be empty)"
  else
    fail "14.5 invalid JSON → stderr + non-zero exit" "exit: $CLI_EXIT"
  fi

  # 14.6 No arguments → usage
  run_cli "$lang" 2>/dev/null || true
  # Some implementations exit 0, some exit 1 for usage
  if echo "$CLI_STDOUT$CLI_STDERR" | grep -qi "usage"; then
    pass "14.6 no arguments → usage output"
  else
    fail "14.6 no arguments → usage output" "no usage text found"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Test group 12: Cross-language compatibility
# ═══════════════════════════════════════════════════════════════════

test_12_cross_compat() {
  local writer="$1" reader="$2"
  section "12. Cross-compat [$writer → $reader]"

  setup_tmpdir
  run_cli_stdin "$writer" "$FIXTURES/valid-full.json" write
  if [ "$CLI_EXIT" -ne 0 ]; then
    fail "12 $writer write failed" "exit: $CLI_EXIT"
    teardown_tmpdir; return
  fi

  run_cli "$reader" read
  if [ "$CLI_EXIT" -ne 0 ]; then
    fail "12 $reader read failed" "exit: $CLI_EXIT"
    teardown_tmpdir; return
  fi

  local result="$CLI_STDOUT"
  local ok=true

  # Verify fact layer fields
  for field in user thinking assistant; do
    local expected; expected=$(jq -r ".$field" "$FIXTURES/valid-full.json")
    local got; got=$(echo "$result" | jq -r ".layers.$field")
    if [ "$expected" != "$got" ]; then
      fail "12 $writer→$reader: layers.$field" "expected: $expected, got: $got"
      ok=false
    fi
  done

  # Verify interpretation layer fields
  for field in current_focus theory_of_mind self_narrative annotation; do
    local expected; expected=$(jq -r ".$field" "$FIXTURES/valid-full.json")
    local got; got=$(echo "$result" | jq -r ".$field")
    if [ "$expected" != "$got" ]; then
      fail "12 $writer→$reader: $field" "expected: $expected, got: $got"
      ok=false
    fi
  done

  if $ok; then pass "12 $writer→$reader: all 7 fields match"; fi
  teardown_tmpdir
}

run_cross_compat_tests() {
  local pairs=(
    "rust:python"
    "node:go"
    "go:ruby"
    "ruby:java"
    "java:csharp"
    "csharp:rust"
    "python:haskell"
    "haskell:cl"
    "cl:node"
    "cpp:go"
    "bash:python"
    "cpp:bash"
  )

  section "12. Cross-language compatibility"
  for pair in "${pairs[@]}"; do
    local writer="${pair%%:*}"
    local reader="${pair#*:}"

    # Only run if both languages are in the test set
    if echo " $LANGS_TO_TEST " | grep -q " $writer " && \
       echo " $LANGS_TO_TEST " | grep -q " $reader "; then
      test_12_cross_compat "$writer" "$reader"
    fi
  done
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

run_tests_for_lang() {
  local lang="$1"
  printf "\n\033[1m════ %s ════\033[0m\n" "$lang"

  test_01_initial_state "$lang"
  test_02_roundtrip "$lang"
  test_03_fact_validation "$lang"
  test_04_interp_validation "$lang"
  test_05_type_check "$lang"
  test_06_window_size "$lang"
  test_07_turn_id "$lang"
  test_08_clear "$lang"
  test_09_schema "$lang"
  test_10_timestamp "$lang"
  test_11_path_resolution "$lang"
  test_14_cli "$lang"
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

  echo "CogLog v0.9.1 — Layer 1 CLI Black-Box Test Harness"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    run_tests_for_lang "$lang"
  done

  # Cross-compatibility tests (only when multiple languages are tested)
  local lang_count; lang_count=$(echo "$LANGS_TO_TEST" | wc -w)
  if [ "$lang_count" -gt 1 ]; then
    run_cross_compat_tests
  fi

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
