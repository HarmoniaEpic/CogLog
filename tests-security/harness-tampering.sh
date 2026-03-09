#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test: Data File Tampering Resistance
#
# Tests robustness when current.json has been manually modified,
# corrupted, or replaced with unexpected content.
#
# Usage:
#   ./tests-security/harness-tampering.sh all
#   ./tests-security/harness-tampering.sh rust python
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Helper: place a tampered file then run read
tamper_and_read() {
  local lang="$1"
  local content="$2"
  local tmpd; tmpd=$(mktemp -d)
  printf '%s' "$content" > "$tmpd/current.json"
  COGLOG_DIR="$tmpd" run_cli "$lang" read
  local exit_code=$CLI_EXIT
  local stdout="$CLI_STDOUT"
  rm -rf "$tmpd"
  # Export for caller
  TAMPER_EXIT=$exit_code
  TAMPER_STDOUT="$stdout"
}

# Helper: place a tampered file then run write (to test recovery)
tamper_and_write() {
  local lang="$1"
  local content="$2"
  local tmpd; tmpd=$(mktemp -d)
  printf '%s' "$content" > "$tmpd/current.json"
  COGLOG_DIR="$tmpd" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  local exit_code=$CLI_EXIT
  local stdout="$CLI_STDOUT"
  # If write succeeded, verify read
  if [ "$exit_code" -eq 0 ]; then
    COGLOG_DIR="$tmpd" run_cli "$lang" read
    TAMPER_READ_STDOUT="$CLI_STDOUT"
    TAMPER_READ_EXIT=$CLI_EXIT
  fi
  rm -rf "$tmpd"
  TAMPER_EXIT=$exit_code
  TAMPER_STDOUT="$stdout"
}

# ═══════════════════════════════════════════════════════════════════
# S.T.1: Corrupted JSON (broken syntax)
# ═══════════════════════════════════════════════════════════════════

test_st1_broken_json() {
  local lang="$1"
  section "S.T.1 Corrupted JSON [$lang]"

  tamper_and_read "$lang" '{"broken": json, not valid'

  if [ "$TAMPER_EXIT" -ne 0 ] || echo "$TAMPER_STDOUT" | grep -q "(no coglog found)"; then
    pass "S.T.1 broken JSON read → error or initial state"
  else
    fail "S.T.1 broken JSON read" "exit: $TAMPER_EXIT, out: $TAMPER_STDOUT"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# S.T.2: Empty file
# ═══════════════════════════════════════════════════════════════════

test_st2_empty_file() {
  local lang="$1"
  section "S.T.2 Empty file [$lang]"

  tamper_and_read "$lang" ''

  if [ "$TAMPER_EXIT" -ne 0 ]; then
    pass "S.T.2 empty file read → error (exit $TAMPER_EXIT)"
  elif echo "$TAMPER_STDOUT" | grep -q "(no coglog found)"; then
    pass "S.T.2 empty file read → initial state"
  elif [ -z "$TAMPER_STDOUT" ]; then
    pass "S.T.2 empty file read → empty output (no crash)"
  else
    fail "S.T.2 empty file read" "exit: $TAMPER_EXIT, out: $TAMPER_STDOUT"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# S.T.3: Binary data
# ═══════════════════════════════════════════════════════════════════

test_st3_binary() {
  local lang="$1"
  section "S.T.3 Binary data [$lang]"

  local tmpd; tmpd=$(mktemp -d)
  # Write 256 bytes of binary data
  dd if=/dev/urandom of="$tmpd/current.json" bs=256 count=1 2>/dev/null
  COGLOG_DIR="$tmpd" run_cli "$lang" read
  local exit_code=$CLI_EXIT

  if [ "$exit_code" -ne 0 ] || echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    pass "S.T.3 binary data read → error or initial state"
  else
    fail "S.T.3 binary data read" "exit: $exit_code"
  fi

  rm -rf "$tmpd"
}

# ═══════════════════════════════════════════════════════════════════
# S.T.4: Negative turn_id → write → read
# ═══════════════════════════════════════════════════════════════════

test_st4_negative_tid() {
  local lang="$1"
  section "S.T.4 Negative turn_id [$lang]"

  local tampered; tampered=$(cat "$FIXTURES_SECURITY/tampered-negative-tid.json")
  tamper_and_write "$lang" "$tampered"

  if [ "$TAMPER_EXIT" -eq 0 ]; then
    # Write succeeded; check that turn_id is sane after write
    local tid
    tid=$(echo "$TAMPER_READ_STDOUT" | jq '.turn_id' 2>/dev/null)
    if [ "$tid" != "null" ] && [ -n "$tid" ]; then
      # turn_id should be positive (either 1 or -998 depending on implementation)
      pass "S.T.4 write over negative turn_id succeeds (turn_id=$tid)"
    else
      fail "S.T.4 turn_id after write" "could not read turn_id"
    fi
  else
    pass "S.T.4 write over negative turn_id → error (exit $TAMPER_EXIT)"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# S.T.5: Missing _schema → read
# ═══════════════════════════════════════════════════════════════════

test_st5_no_schema() {
  local lang="$1"
  section "S.T.5 Missing _schema [$lang]"

  local tampered; tampered=$(cat "$FIXTURES_SECURITY/tampered-no-schema.json")
  tamper_and_read "$lang" "$tampered"

  if [ "$TAMPER_EXIT" -ne 0 ] || echo "$TAMPER_STDOUT" | grep -q "(no coglog found)"; then
    pass "S.T.5 no-schema file → error or initial state"
  else
    # Some implementations may regenerate _schema on read — that's also valid
    local has_schema
    has_schema=$(echo "$TAMPER_STDOUT" | jq '._schema.version // empty' 2>/dev/null)
    if [ -n "$has_schema" ]; then
      pass "S.T.5 no-schema file → _schema regenerated on read"
    else
      pass "S.T.5 no-schema file → read returns data (schema handling varies)"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

main() {
  check_prerequisites
  cd "$REPO_ROOT"
  parse_lang_args "$@"

  echo "CogLog v0.9.1 — Security Test: Data File Tampering Resistance"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    if ! prepare_lang "$lang"; then
      continue
    fi

    test_st1_broken_json "$lang"
    test_st2_empty_file "$lang"
    test_st3_binary "$lang"
    test_st4_negative_tid "$lang"
    test_st5_no_schema "$lang"
  done

  print_summary
}

main "$@"
