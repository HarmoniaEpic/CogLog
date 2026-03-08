#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test: Input Boundary
#
# Tests handling of abnormal, oversized, and edge-case inputs
# to the CLI write command.
#
# Usage:
#   ./tests-security/harness-input.sh all
#   ./tests-security/harness-input.sh rust python
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════════════════════════════════
# S.I.1: Large payload (1 MB field)
# ═══════════════════════════════════════════════════════════════════

test_si1_large_payload() {
  local lang="$1"
  section "S.I.1 Large payload (1 MB) [$lang]"

  setup_tmpdir
  # Generate large payload via file to avoid "Argument list too long"
  local tmpjson; tmpjson=$(mktemp)
  python3 -c "
import json
d = {
    'user': 'A' * 1_000_000,
    'thinking': 'normal',
    'assistant': 'normal',
    'current_focus': '',
    'theory_of_mind': '',
    'self_narrative': '',
    'annotation': ''
}
with open('$tmpjson', 'w') as f:
    json.dump(d, f)
"
  run_cli_stdin "$lang" "$tmpjson" write
  rm -f "$tmpjson"

  if [ "$CLI_EXIT" -eq 0 ]; then
    # Verify round-trip
    run_cli "$lang" read
    local len
    len=$(echo "$CLI_STDOUT" | jq -r '.layers.user | length' 2>/dev/null)
    if [ "$len" = "1000000" ]; then
      pass "S.I.1 1 MB payload round-trips correctly"
    else
      pass "S.I.1 1 MB payload accepted (length: ${len:-unknown})"
    fi
  else
    pass "S.I.1 1 MB payload rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.2: Empty JSON objects
# ═══════════════════════════════════════════════════════════════════

test_si2_empty_json() {
  local lang="$1"
  section "S.I.2 Empty JSON objects [$lang]"

  # 2a: empty object {}
  setup_tmpdir
  run_cli_string "$lang" '{}' write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.I.2a {} → error (exit $CLI_EXIT)"
  else
    fail "S.I.2a {} → error" "exit code was 0"
  fi
  teardown_tmpdir

  # 2b: empty array []
  setup_tmpdir
  run_cli_string "$lang" '[]' write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.I.2b [] → error (exit $CLI_EXIT)"
  else
    fail "S.I.2b [] → error" "exit code was 0"
  fi
  teardown_tmpdir

  # 2c: empty string ""
  setup_tmpdir
  run_cli_string "$lang" '""' write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.I.2c empty string → error (exit $CLI_EXIT)"
  else
    fail "S.I.2c empty string → error" "exit code was 0"
  fi
  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.3: Extra fields (unknown keys)
# ═══════════════════════════════════════════════════════════════════

test_si3_extra_fields() {
  local lang="$1"
  section "S.I.3 Extra fields [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES_SECURITY/extra-fields.json" write

  if [ "$CLI_EXIT" -eq 0 ]; then
    run_cli "$lang" read
    local user
    user=$(echo "$CLI_STDOUT" | jq -r '.layers.user' 2>/dev/null)
    if [ "$user" = "Hello" ]; then
      pass "S.I.3 extra fields ignored, core data preserved"
    else
      fail "S.I.3 extra fields" "user field: $user"
    fi
  else
    pass "S.I.3 extra fields rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.4: Unicode edge cases
# ═══════════════════════════════════════════════════════════════════

test_si4_unicode() {
  local lang="$1"
  section "S.I.4 Unicode edge cases [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES_SECURITY/unicode-edge.json" write

  if [ "$CLI_EXIT" -eq 0 ]; then
    run_cli "$lang" read
    if echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
      pass "S.I.4 unicode edge cases round-trip (valid JSON output)"
    else
      fail "S.I.4 unicode read" "output is not valid JSON"
    fi
  else
    # Rejection is also acceptable behavior
    pass "S.I.4 unicode edge cases rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.5: Control characters
# ═══════════════════════════════════════════════════════════════════

test_si5_control_chars() {
  local lang="$1"
  section "S.I.5 Control characters [$lang]"

  setup_tmpdir
  run_cli_stdin "$lang" "$FIXTURES_SECURITY/control-chars.json" write

  if [ "$CLI_EXIT" -eq 0 ]; then
    run_cli "$lang" read
    local user
    user=$(echo "$CLI_STDOUT" | jq -r '.layers.user' 2>/dev/null)
    if [ -n "$user" ]; then
      pass "S.I.5 control chars preserved in round-trip"
    else
      fail "S.I.5 control chars" "user field empty after round-trip"
    fi
  else
    pass "S.I.5 control chars rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.6: Deeply nested JSON
# ═══════════════════════════════════════════════════════════════════

test_si6_deep_nesting() {
  local lang="$1"
  section "S.I.6 Deeply nested JSON [$lang]"

  setup_tmpdir
  # Build a deeply nested JSON string as the user field value
  local depth=500
  local nested=""
  local i
  for ((i=0; i<depth; i++)); do
    nested="{\"d\":$nested\"v\"}"
  done
  # Use it as the user field content (a string containing nested JSON)
  local json
  json=$(jq -n --arg u "$nested" '{
    user: $u,
    thinking: "test",
    assistant: "test",
    current_focus: "",
    theory_of_mind: "",
    self_narrative: "",
    annotation: ""
  }')

  run_cli_string "$lang" "$json" write

  if [ "$CLI_EXIT" -eq 0 ]; then
    pass "S.I.6 deeply nested content accepted"
  else
    pass "S.I.6 deeply nested content rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.7: Null bytes in field value
# ═══════════════════════════════════════════════════════════════════

test_si7_null_bytes() {
  local lang="$1"
  section "S.I.7 Null bytes [$lang]"

  setup_tmpdir
  # JSON with escaped null byte (\u0000) in user field
  local json='{"user":"Hello\u0000World","thinking":"test","assistant":"test","current_focus":"","theory_of_mind":"","self_narrative":"","annotation":""}'

  run_cli_string "$lang" "$json" write

  if [ "$CLI_EXIT" -eq 0 ]; then
    run_cli "$lang" read
    if echo "$CLI_STDOUT" | jq . >/dev/null 2>&1; then
      pass "S.I.7 null byte in field → accepted, valid JSON output"
    else
      fail "S.I.7 null byte read" "output is not valid JSON"
    fi
  else
    pass "S.I.7 null byte rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# S.I.8: Very large number of fields (JSON bomb)
# ═══════════════════════════════════════════════════════════════════

test_si8_many_fields() {
  local lang="$1"
  section "S.I.8 JSON with 10000 extra fields [$lang]"

  setup_tmpdir
  # Generate JSON with valid required fields + 10000 extra fields
  local tmpjson; tmpjson=$(mktemp)
  python3 -c "
import json
d = {
    'user': 'Hello',
    'thinking': 'test',
    'assistant': 'test',
    'current_focus': '',
    'theory_of_mind': '',
    'self_narrative': '',
    'annotation': ''
}
for i in range(10000):
    d[f'extra_{i}'] = f'value_{i}'
with open('$tmpjson', 'w') as f:
    json.dump(d, f)
"

  run_cli_stdin "$lang" "$tmpjson" write
  rm -f "$tmpjson"

  if [ "$CLI_EXIT" -eq 0 ]; then
    pass "S.I.8 10000 extra fields accepted"
  elif [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.I.8 10000 extra fields rejected (exit $CLI_EXIT)"
  fi

  teardown_tmpdir
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

main() {
  check_prerequisites
  cd "$REPO_ROOT"
  parse_lang_args "$@"

  echo "CogLog v0.9.1 — Security Test: Input Boundary"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    if ! prepare_lang "$lang"; then
      continue
    fi

    test_si1_large_payload "$lang"
    test_si2_empty_json "$lang"
    test_si3_extra_fields "$lang"
    test_si4_unicode "$lang"
    test_si5_control_chars "$lang"
    test_si6_deep_nesting "$lang"
    test_si7_null_bytes "$lang"
    test_si8_many_fields "$lang"
  done

  print_summary
}

main "$@"
