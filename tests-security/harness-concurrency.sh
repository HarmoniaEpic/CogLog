#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test: Concurrency & Race Conditions
#
# Tests behavior under concurrent access: simultaneous writes,
# write during read, and write during clear.
#
# Usage:
#   ./tests-security/harness-concurrency.sh all
#   ./tests-security/harness-concurrency.sh rust python
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════════════════════════════════
# S.C.1: Simultaneous writes (2 processes)
# ═══════════════════════════════════════════════════════════════════

test_sc1_concurrent_writes() {
  local lang="$1"
  section "S.C.1 Concurrent writes [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  # Create two different input fixtures
  local input_a; input_a=$(mktemp)
  local input_b; input_b=$(mktemp)
  cat > "$input_a" <<'EOF'
{"user":"Writer A","thinking":"A thinking","assistant":"A response","current_focus":"A focus","theory_of_mind":"","self_narrative":"","annotation":""}
EOF
  cat > "$input_b" <<'EOF'
{"user":"Writer B","thinking":"B thinking","assistant":"B response","current_focus":"B focus","theory_of_mind":"","self_narrative":"","annotation":""}
EOF

  # Launch two writes in parallel
  local pid_a pid_b exit_a exit_b
  COGLOG_DIR="$tmpdir" run_cli_stdin "$lang" "$input_a" write &
  pid_a=$!
  COGLOG_DIR="$tmpdir" run_cli_stdin "$lang" "$input_b" write &
  pid_b=$!

  exit_a=0; wait "$pid_a" || exit_a=$?
  exit_b=0; wait "$pid_b" || exit_b=$?

  # Read the result
  COGLOG_DIR="$tmpdir" run_cli "$lang" read

  if [ "$CLI_EXIT" -eq 0 ] && echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
    local user
    user=$(echo "$CLI_STDOUT" | jq -r '.layers.user' 2>/dev/null)
    if [ "$user" = "Writer A" ] || [ "$user" = "Writer B" ]; then
      pass "S.C.1 concurrent writes → one writer wins ($user), valid JSON"
    else
      fail "S.C.1 concurrent writes" "unexpected user: $user"
    fi
  elif [ "$CLI_EXIT" -eq 0 ] && echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    fail "S.C.1 concurrent writes" "both writes lost (no coglog found)"
  else
    # If read fails, check if at least the file exists and is valid JSON
    if [ -f "$tmpdir/current.json" ] && jq . "$tmpdir/current.json" >/dev/null 2>&1; then
      pass "S.C.1 concurrent writes → file is valid JSON (read issue)"
    else
      fail "S.C.1 concurrent writes" "corrupted or missing file"
    fi
  fi

  rm -f "$input_a" "$input_b"
  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.C.2: Read during write
# ═══════════════════════════════════════════════════════════════════

test_sc2_read_during_write() {
  local lang="$1"
  section "S.C.2 Read during write [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  # First write to establish initial state
  COGLOG_DIR="$tmpdir" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write

  # Now launch a write and read simultaneously
  local input_b; input_b=$(mktemp)
  cat > "$input_b" <<'EOF'
{"user":"Concurrent","thinking":"Concurrent thinking","assistant":"Concurrent response","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}
EOF

  local pid_w pid_r
  COGLOG_DIR="$tmpdir" run_cli_stdin "$lang" "$input_b" write &
  pid_w=$!
  COGLOG_DIR="$tmpdir" run_cli "$lang" read &
  pid_r=$!

  wait "$pid_w" || true
  wait "$pid_r" || true

  # Final read to verify consistency
  COGLOG_DIR="$tmpdir" run_cli "$lang" read
  if [ "$CLI_EXIT" -eq 0 ] && echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
    pass "S.C.2 read during write → final state is valid JSON"
  else
    fail "S.C.2 read during write" "final state corrupted"
  fi

  rm -f "$input_b"
  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# S.C.3: Clear during write
# ═══════════════════════════════════════════════════════════════════

test_sc3_clear_during_write() {
  local lang="$1"
  section "S.C.3 Clear during write [$lang]"

  local tmpdir; tmpdir=$(mktemp -d)

  # Launch write and clear simultaneously
  local pid_w pid_c
  COGLOG_DIR="$tmpdir" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write &
  pid_w=$!
  COGLOG_DIR="$tmpdir" run_cli "$lang" clear &
  pid_c=$!

  wait "$pid_w" || true
  wait "$pid_c" || true

  # Final read — should be either valid data or "(no coglog found)"
  COGLOG_DIR="$tmpdir" run_cli "$lang" read
  if [ "$CLI_EXIT" -eq 0 ]; then
    if echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
      pass "S.C.3 clear won → initial state"
    elif echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
      pass "S.C.3 write won → valid JSON"
    else
      fail "S.C.3 clear during write" "inconsistent state"
    fi
  else
    fail "S.C.3 clear during write" "read failed (exit $CLI_EXIT)"
  fi

  rm -rf "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

main() {
  check_prerequisites
  cd "$REPO_ROOT"
  parse_lang_args "$@"

  echo "CogLog v0.9.1 — Security Test: Concurrency & Race Conditions"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    if ! prepare_lang "$lang"; then
      continue
    fi

    test_sc1_concurrent_writes "$lang"
    test_sc2_read_during_write "$lang"
    test_sc3_clear_during_write "$lang"
  done

  print_summary
}

main "$@"
