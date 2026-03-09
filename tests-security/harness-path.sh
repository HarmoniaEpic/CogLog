#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Security Test: Path Traversal & Filesystem
#
# Tests path handling safety for --coglog-dir and COGLOG_DIR.
#
# Usage:
#   ./tests-security/harness-path.sh all
#   ./tests-security/harness-path.sh rust python
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ═══════════════════════════════════════════════════════════════════
# S.P.1: Path traversal via --coglog-dir
# ═══════════════════════════════════════════════════════════════════

test_sp1_traversal() {
  local lang="$1"
  section "S.P.1 Path traversal via --coglog-dir [$lang]"

  # Create a controlled directory tree: base/target and base/start
  local base; base=$(mktemp -d)
  local target="$base/target"
  local start="$base/start/sub"
  mkdir -p "$target" "$start"

  # Attempt to write via traversal path
  COGLOG_DIR="$start/../../target" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write

  # Check where the file ended up
  if [ -f "$target/current.json" ]; then
    pass "S.P.1 traversal path resolves (file written to target)"
  elif [ -f "$start/../../target/current.json" ]; then
    pass "S.P.1 traversal path resolves (literal path)"
  else
    # Check if it was written somewhere else or rejected
    if [ "$CLI_EXIT" -ne 0 ]; then
      pass "S.P.1 traversal path rejected (exit $CLI_EXIT)"
    else
      fail "S.P.1 traversal path" "file not found in expected locations"
    fi
  fi

  rm -rf "$base"
}

# ═══════════════════════════════════════════════════════════════════
# S.P.2: /dev/null as COGLOG_DIR
# ═══════════════════════════════════════════════════════════════════

test_sp2_devnull() {
  local lang="$1"
  section "S.P.2 /dev/null as COGLOG_DIR [$lang]"

  COGLOG_DIR="/dev/null" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.P.2 /dev/null write fails gracefully (exit $CLI_EXIT)"
  else
    fail "S.P.2 /dev/null write" "exit code was 0 (expected error)"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# S.P.3: Symlink as COGLOG_DIR target
# ═══════════════════════════════════════════════════════════════════

test_sp3_symlink() {
  local lang="$1"
  section "S.P.3 Symlink COGLOG_DIR [$lang]"

  local base; base=$(mktemp -d)
  local real_dir="$base/real"
  local link_dir="$base/link"
  mkdir -p "$real_dir"
  ln -s "$real_dir" "$link_dir"

  COGLOG_DIR="$link_dir" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write

  if [ -f "$real_dir/current.json" ]; then
    pass "S.P.3 symlink followed — file written to real dir"
  elif [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.P.3 symlink rejected (exit $CLI_EXIT)"
  else
    fail "S.P.3 symlink" "file not found in real dir, exit: $CLI_EXIT"
  fi

  rm -rf "$base"
}

# ═══════════════════════════════════════════════════════════════════
# S.P.4: Read-only directory
# ═══════════════════════════════════════════════════════════════════

test_sp4_readonly() {
  local lang="$1"
  section "S.P.4 Read-only directory [$lang]"

  local rodir; rodir=$(mktemp -d)
  chmod 555 "$rodir"

  # Root can write despite chmod 555; skip to avoid false failure
  if touch "$rodir/.write_test" 2>/dev/null; then
    rm -f "$rodir/.write_test"
    chmod 755 "$rodir"
    rm -rf "$rodir"
    skip "S.P.4 read-only dir (effective user can write despite chmod 555)"
    return
  fi

  COGLOG_DIR="$rodir" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.P.4 read-only dir write fails (exit $CLI_EXIT)"
  else
    fail "S.P.4 read-only dir write" "exit code was 0 (expected error)"
  fi

  chmod 755 "$rodir"
  rm -rf "$rodir"
}

# ═══════════════════════════════════════════════════════════════════
# S.P.5: current.json is a directory (not a file)
# ═══════════════════════════════════════════════════════════════════

test_sp5_file_is_dir() {
  local lang="$1"
  section "S.P.5 current.json is a directory [$lang]"

  local tmpd; tmpd=$(mktemp -d)
  mkdir -p "$tmpd/current.json"

  COGLOG_DIR="$tmpd" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.P.5 current.json-as-dir write fails (exit $CLI_EXIT)"
  else
    fail "S.P.5 current.json-as-dir write" "exit code was 0"
  fi

  # Also test read
  COGLOG_DIR="$tmpd" run_cli "$lang" read
  if [ "$CLI_EXIT" -ne 0 ] || echo "$CLI_STDOUT" | grep -q "(no coglog found)"; then
    pass "S.P.5 current.json-as-dir read handles gracefully"
  else
    fail "S.P.5 current.json-as-dir read" "exit: $CLI_EXIT, out: $CLI_STDOUT"
  fi

  rm -rf "$tmpd"
}

# ═══════════════════════════════════════════════════════════════════
# S.P.6: Very long directory path
# ═══════════════════════════════════════════════════════════════════

test_sp6_long_path() {
  local lang="$1"
  section "S.P.6 Very long directory path [$lang]"

  # Create a path near typical filesystem limits (~255 chars per component)
  local base; base=$(mktemp -d)
  local long_component
  long_component=$(printf 'a%.0s' {1..200})
  local long_path="$base/$long_component/$long_component"

  COGLOG_DIR="$long_path" run_cli_stdin "$lang" "$FIXTURES/valid-full.json" write
  if [ "$CLI_EXIT" -eq 0 ] && [ -f "$long_path/current.json" ]; then
    pass "S.P.6 long path write succeeds"
  elif [ "$CLI_EXIT" -ne 0 ]; then
    pass "S.P.6 long path write fails gracefully (exit $CLI_EXIT)"
  else
    fail "S.P.6 long path" "exit: $CLI_EXIT, file missing"
  fi

  rm -rf "$base"
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

main() {
  check_prerequisites
  cd "$REPO_ROOT"
  parse_lang_args "$@"

  echo "CogLog v0.9.1 — Security Test: Path Traversal & Filesystem"
  echo "Testing: $LANGS_TO_TEST"

  for lang in $LANGS_TO_TEST; do
    printf "\n\033[1m════ %s ════\033[0m\n" "$lang"
    if ! prepare_lang "$lang"; then
      continue
    fi

    test_sp1_traversal "$lang"
    test_sp2_devnull "$lang"
    test_sp3_symlink "$lang"
    test_sp4_readonly "$lang"
    test_sp5_file_is_dir "$lang"
    test_sp6_long_path "$lang"
  done

  print_summary
}

main "$@"
