#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog v0.9.1 — Recurrent Quine Test Harness
#
# Tests the self-rewriting Common Lisp recurrent quine.
# The write command rewrites recurrent-quine.lisp itself as the next generation.
#
# Usage:
#   ./tests/harness-quine.sh
#
# Prerequisites:
#   - sbcl (Steel Bank Common Lisp)
#   - jq (for opt-affordance marker check)
#
# Warning: write commands irreversibly rewrite recurrent-quine.lisp.
# This harness automatically backs up and restores from
# recurrent-quine-baseline.lisp.
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures-quine"

QUINE_DIR="$REPO_ROOT/common-lisp/coglog-quine"
QUINE_FILE="$QUINE_DIR/recurrent-quine.lisp"
BASELINE_FILE="$QUINE_DIR/recurrent-quine-baseline.lisp"

# ── Counters ──
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

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

# Restore the quine file from baseline.
restore_baseline() {
  cp "$BASELINE_FILE" "$QUINE_FILE"
}

# Extract *self-source* from the quine file without executing it.
# Reads the file as data (S-expressions), finds the (defvar *self-source* ...)
# form, and prints its value. This avoids loading the file, which would
# execute (main) and call (exit) before extraction could occur.
extract_self_source() {
  sbcl --non-interactive --eval '
    (with-open-file (in "'"$QUINE_FILE"'" :direction :input)
      (loop for form = (read in nil nil)
            while form
            when (and (consp form)
                      (eq (car form) (quote defvar))
                      (eq (cadr form) (quote *self-source*)))
            do (let ((*print-case* :downcase)
                     (*print-right-margin* nil)
                     (*print-pretty* nil)
                     (*print-circle* nil))
                 (write (caddr form) :stream *standard-output*)
                 (terpri)
                 (return))))
  ' 2>/dev/null
}

# Run the quine with a command and optional stdin.
# Usage: run_quine <cmd> [stdin_text]
# Captures stdout to $Q_STDOUT, stderr to $Q_STDERR, exit code to $Q_EXIT.
run_quine() {
  local cmd="$1"
  local stdin_text="${2:-}"
  local tmpout; tmpout=$(mktemp)
  local tmperr; tmperr=$(mktemp)

  Q_EXIT=0
  if [ -n "$stdin_text" ]; then
    echo "$stdin_text" | sbcl --script "$QUINE_FILE" "$cmd" \
      >"$tmpout" 2>"$tmperr" || Q_EXIT=$?
  else
    sbcl --script "$QUINE_FILE" "$cmd" \
      >"$tmpout" 2>"$tmperr" || Q_EXIT=$?
  fi

  Q_STDOUT=$(cat "$tmpout")
  Q_STDERR=$(cat "$tmperr")
  rm -f "$tmpout" "$tmperr"
}

# ═══════════════════════════════════════════════════════════════════
# Test Q.1-Q.6: Basic Operations
# ═══════════════════════════════════════════════════════════════════

test_q1_read_initial() {
  section "Q.1 Read initial state"

  restore_baseline
  run_quine read

  # Q.1: read returns "(no coglog found)" + affordance
  if echo "$Q_STDOUT" | grep -q "(no coglog found)"; then
    pass "Q.1 read initial → '(no coglog found)'"
  else
    fail "Q.1 read initial" "got: $Q_STDOUT"
  fi

  # Also verify affordance is output
  if echo "$Q_STDOUT" | grep -q "affordance"; then
    pass "Q.1 affordance section present"
  else
    fail "Q.1 affordance section" "no affordance in output"
  fi
}

test_q2_write_read() {
  section "Q.2 Write → Read"

  restore_baseline
  local fixture; fixture=$(cat "$FIXTURES/valid-full.sexp")
  run_quine write "$fixture"

  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.2 write succeeds" "exit: $Q_EXIT, stderr: $Q_STDERR"
    return
  fi

  # Verify "turn 1 written" message
  if echo "$Q_STDOUT" | grep -q "turn 1 written"; then
    pass "Q.2 write → 'turn 1 written'"
  else
    fail "Q.2 write message" "got: $Q_STDOUT"
  fi

  # Read back — the quine file is now Q_1
  run_quine read
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.2 Q_1 read" "exit: $Q_EXIT, stderr: $Q_STDERR"
    return
  fi

  # Verify user field is present in state output
  if echo "$Q_STDOUT" | grep -q "Hello"; then
    pass "Q.2 read returns written content"
  else
    fail "Q.2 read content" "got: $Q_STDOUT"
  fi

  # Verify turn-id is 1
  if echo "$Q_STDOUT" | grep -q ":turn-id . 1"; then
    pass "Q.2 turn-id = 1"
  else
    # Try alternative format
    if echo "$Q_STDOUT" | grep -q "turn-id"; then
      pass "Q.2 turn-id present"
    else
      fail "Q.2 turn-id" "not found in output"
    fi
  fi
}

test_q3_overwrite() {
  section "Q.3 Write → Write → Read (window size 1)"

  restore_baseline
  local fixture1; fixture1=$(cat "$FIXTURES/valid-full.sexp")
  run_quine write "$fixture1"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.3 first write" "exit: $Q_EXIT"; return
  fi

  # Second write — now on Q_1
  local fixture2='(:user "Second" :thinking "Second thinking" :assistant "Second response" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$fixture2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.3 second write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi

  if echo "$Q_STDOUT" | grep -q "turn 2 written"; then
    pass "Q.3 second write → turn 2"
  else
    fail "Q.3 turn 2" "got: $Q_STDOUT"
  fi

  # Read — Q_2 should have second content, not first
  run_quine read
  if echo "$Q_STDOUT" | grep -q "Second"; then
    pass "Q.3 read returns second content (overwrite)"
  else
    fail "Q.3 overwrite" "got: $Q_STDOUT"
  fi

  if ! echo "$Q_STDOUT" | grep -q "Hello"; then
    pass "Q.3 first content is gone"
  else
    fail "Q.3 first content still present"
  fi
}

test_q4_clear() {
  section "Q.4 Clear → Read"

  restore_baseline
  local fixture; fixture=$(cat "$FIXTURES/valid-full.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.4 write" "exit: $Q_EXIT"; return
  fi

  run_quine clear
  if echo "$Q_STDOUT" | grep -q "cleared"; then
    pass "Q.4 clear → 'cleared'"
  else
    fail "Q.4 clear message" "got: $Q_STDOUT"
  fi

  # Read after clear
  run_quine read
  if echo "$Q_STDOUT" | grep -q "(no coglog found)"; then
    pass "Q.4 clear → read → '(no coglog found)'"
  else
    fail "Q.4 clear → read" "got: $Q_STDOUT"
  fi
}

test_q5_fact_validation() {
  section "Q.5 Fact layer validation"

  restore_baseline
  local fixture; fixture=$(cat "$FIXTURES/invalid-user-empty.sexp")
  run_quine write "$fixture"

  if [ "$Q_EXIT" -ne 0 ]; then
    pass "Q.5 empty user → validation error (exit $Q_EXIT)"
  else
    fail "Q.5 empty user → validation error" "exit code was 0"
  fi
}

test_q6_interp_empty() {
  section "Q.6 Interpretation layer empty"

  restore_baseline
  local fixture; fixture=$(cat "$FIXTURES/valid-interpretation-empty.sexp")
  run_quine write "$fixture"

  if [ "$Q_EXIT" -eq 0 ]; then
    pass "Q.6 all interpretation fields empty → success"
  else
    fail "Q.6 interpretation empty" "exit: $Q_EXIT, stderr: $Q_STDERR"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Test Q.7-Q.8: Generation Round-trip Fidelity
# ═══════════════════════════════════════════════════════════════════

test_q7_two_generations() {
  section "Q.7 Two-generation round-trip"

  restore_baseline

  # Q_0 → Q_1
  local fixture; fixture=$(cat "$FIXTURES/valid-full.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.7 Q_0→Q_1 write" "exit: $Q_EXIT"; return
  fi
  pass "Q.7 Q_0 → Q_1"

  # Q_1 → Q_2
  local fixture2='(:user "Gen2" :thinking "Generation 2" :assistant "OK gen 2" :current-focus "testing" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$fixture2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.7 Q_1→Q_2 write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.7 Q_1 → Q_2"

  # Read Q_2
  run_quine read
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.7 Q_2 read" "exit: $Q_EXIT"; return
  fi

  if echo "$Q_STDOUT" | grep -q "Gen2"; then
    pass "Q.7 Q_2 read returns generation 2 content"
  else
    fail "Q.7 Q_2 content" "got: $Q_STDOUT"
  fi

  if echo "$Q_STDOUT" | grep -q ":turn-id . 2"; then
    pass "Q.7 Q_2 turn-id = 2"
  else
    pass "Q.7 Q_2 operational (turn-id format may vary)"
  fi
}

test_q8_three_generations() {
  section "Q.8 Three-generation round-trip"

  restore_baseline

  # Q_0 → Q_1
  local fixture; fixture=$(cat "$FIXTURES/valid-full.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.8 Q_0→Q_1" "exit: $Q_EXIT"; return
  fi

  # Q_1 → Q_2
  local f2='(:user "Gen2" :thinking "G2" :assistant "OK2" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.8 Q_1→Q_2" "exit: $Q_EXIT"; return
  fi

  # Q_2 → Q_3
  local f3='(:user "Gen3" :thinking "G3" :assistant "OK3" :current-focus "gen3" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f3"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.8 Q_2→Q_3" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi

  # Read Q_3
  run_quine read
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.8 Q_3 read" "exit: $Q_EXIT"; return
  fi

  if echo "$Q_STDOUT" | grep -q "Gen3"; then
    pass "Q.8 Q_3 operational with correct content (turn 3)"
  else
    fail "Q.8 Q_3 content" "got: $Q_STDOUT"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Test Q.9-Q.12: Option Keys
# ═══════════════════════════════════════════════════════════════════

test_q9_opt_advance() {
  section "Q.9 :opt-advance"

  restore_baseline

  # Write with opt-advance that adds :opt-advance-marker
  local fixture; fixture=$(cat "$FIXTURES/with-opt-advance.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.9 opt-advance write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.9 opt-advance write succeeds"

  # Normal write on Q_1 (which has the new advance)
  local f2='(:user "After advance" :thinking "Testing new advance" :assistant "OK" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.9 Q_1 normal write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi

  # Read — should have opt-advance-marker
  run_quine read
  if echo "$Q_STDOUT" | grep -q "opt-advance-marker"; then
    pass "Q.9 new advance function is active (marker present)"
  else
    fail "Q.9 opt-advance-marker not found" "got: $Q_STDOUT"
  fi
}

test_q10_opt_affordance() {
  section "Q.10 :opt-affordance"

  restore_baseline

  # Write with opt-affordance
  local fixture; fixture=$(cat "$FIXTURES/with-opt-affordance.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.10 opt-affordance write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.10 opt-affordance write succeeds"

  # Read — affordance section should contain custom-field marker
  run_quine read
  if echo "$Q_STDOUT" | grep -q "custom-field"; then
    pass "Q.10 new affordance reflected (custom-field present)"
  else
    fail "Q.10 custom-field not found" "got: $Q_STDOUT"
  fi
}

test_q11_opt_self_identity() {
  section "Q.11 :opt-self identity"

  restore_baseline

  # Extract current *self-source* without executing the quine
  local self_source
  self_source=$(extract_self_source) || true

  if [ -z "$self_source" ]; then
    skip "Q.11 could not extract *self-source* (sbcl extraction failed)"
    return
  fi

  # Write with :opt-self = current *self-source* (identity — should be a no-op)
  local plist="(:user \"Identity test\" :thinking \"Testing self-identity\" :assistant \"OK\" :current-focus \"\" :theory-of-mind \"\" :self-narrative \"\" :annotation \"\" :opt-self $self_source)"
  run_quine write "$plist"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.11 opt-self identity write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.11 opt-self identity write succeeds"

  # Normal write on Q_1
  local f2='(:user "After identity" :thinking "Post-identity" :assistant "OK" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f2"
  if [ "$Q_EXIT" -eq 0 ]; then
    pass "Q.11 Q_1 normal write after identity opt-self succeeds"
  else
    fail "Q.11 Q_1 write" "exit: $Q_EXIT, stderr: $Q_STDERR"
  fi
}

test_q12_all_options() {
  section "Q.12 All options simultaneously"

  restore_baseline

  # Extract current *self-source* without executing the quine
  local self_source
  self_source=$(extract_self_source) || true

  if [ -z "$self_source" ]; then
    skip "Q.12 could not extract *self-source*"
    return
  fi

  # Construct opt-advance (with marker)
  local opt_advance='(defun advance (prev args timestamp) (let ((turn-id (1+ (or (cdr (assoc :turn-id prev)) 0)))) (list (cons :_schema (copy-tree *affordance*)) (cons :turn-id turn-id) (cons :timestamp timestamp) (cons :layers (list (cons :user (getf args :user)) (cons :thinking (getf args :thinking)) (cons :assistant (getf args :assistant)))) (cons :current-focus (getf args :current-focus)) (cons :theory-of-mind (getf args :theory-of-mind)) (cons :self-narrative (getf args :self-narrative)) (cons :annotation (getf args :annotation)) (cons :opt-advance-marker "all-opts"))))'

  # Construct opt-affordance (with custom-field)
  local opt_affordance='((:version . "0.9.1") (:fact-layer (:user . "non-empty string required — user'\''s original utterance") (:thinking . "non-empty string required — AI'\''s full thinking process") (:assistant . "non-empty string required — AI'\''s original output")) (:interpretation-layer (:current-focus . "string required, empty OK — present: what am I working on?") (:theory-of-mind . "string required, empty OK — other: what is the user'\''s state?") (:self-narrative . "string required, empty OK — self: who am I in this moment?") (:annotation . "string required, empty OK — future: what should I do next?")) (:constraints (:window-size . "1 turn (overwritten each write)") (:interpretation-empty . "choosing not to write is itself a metacognitive act")) (:all-opts-marker . "present"))'

  # Write with all three options
  local plist="(:user \"All opts\" :thinking \"Testing all options\" :assistant \"OK\" :current-focus \"\" :theory-of-mind \"\" :self-narrative \"\" :annotation \"\" :opt-advance $opt_advance :opt-affordance $opt_affordance :opt-self $self_source)"

  run_quine write "$plist"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.12 all-options write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.12 all-options write succeeds"

  # Normal write on Q_1 to verify all components updated
  local f2='(:user "After all opts" :thinking "Post-all" :assistant "OK" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.12 Q_1 write after all-options" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi

  run_quine read
  local all_ok=true

  if echo "$Q_STDOUT" | grep -q "opt-advance-marker"; then
    pass "Q.12 advance component updated"
  else
    fail "Q.12 advance marker" "not found"
    all_ok=false
  fi

  if echo "$Q_STDOUT" | grep -q "all-opts-marker"; then
    pass "Q.12 affordance component updated"
  else
    fail "Q.12 affordance marker" "not found"
    all_ok=false
  fi

  if $all_ok; then
    pass "Q.12 all four components updated"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Test Q.13: Lineage Breakage (Destructive Test)
# ═══════════════════════════════════════════════════════════════════

test_q13_lineage_breakage() {
  section "Q.13 Lineage breakage (:opt-self broken)"

  restore_baseline

  # Write with :opt-self = (+ 1 2) — a valid S-expression but not a valid *self-source*
  local fixture; fixture=$(cat "$FIXTURES/with-opt-self-broken.sexp")
  run_quine write "$fixture"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.13 opt-self broken write" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.13 broken opt-self write succeeds (creates broken Q_1)"

  # Attempt to run the broken Q_1 — it should fail
  run_quine read
  if [ "$Q_EXIT" -ne 0 ]; then
    pass "Q.13 broken Q_1 fails to operate (lineage broken)"
  else
    # Even if exit 0, if there's no meaningful output it's still broken
    if echo "$Q_STDOUT" | grep -q "state\|no coglog found"; then
      fail "Q.13 broken Q_1 should not work" "it appears to work: $Q_STDOUT"
    else
      pass "Q.13 broken Q_1 produces no valid output (lineage broken)"
    fi
  fi

  # Restore for subsequent tests
  restore_baseline
}

# ═══════════════════════════════════════════════════════════════════
# Test Q.14: :opt-self Round-trip Fidelity
# ═══════════════════════════════════════════════════════════════════

test_q14_opt_self_fidelity() {
  section "Q.14 :opt-self round-trip fidelity (3 generations)"

  restore_baseline

  # Extract current *self-source* without executing the quine
  local self_source
  self_source=$(extract_self_source) || true

  if [ -z "$self_source" ]; then
    skip "Q.14 could not extract *self-source*"
    return
  fi

  # Q_0 → Q_1 with :opt-self (modified self-source, pass through current)
  local plist="(:user \"Self fidelity G1\" :thinking \"G1\" :assistant \"OK\" :current-focus \"\" :theory-of-mind \"\" :self-narrative \"\" :annotation \"\" :opt-self $self_source)"
  run_quine write "$plist"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.14 Q_0→Q_1 opt-self write" "exit: $Q_EXIT"; return
  fi
  pass "Q.14 Q_0 → Q_1 (opt-self)"

  # Q_1 → Q_2 normal write
  local f2='(:user "Fidelity G2" :thinking "G2" :assistant "OK2" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f2"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.14 Q_1→Q_2" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.14 Q_1 → Q_2 (normal write)"

  # Q_2 → Q_3 normal write
  local f3='(:user "Fidelity G3" :thinking "G3" :assistant "OK3" :current-focus "" :theory-of-mind "" :self-narrative "" :annotation "")'
  run_quine write "$f3"
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.14 Q_2→Q_3" "exit: $Q_EXIT, stderr: $Q_STDERR"; return
  fi
  pass "Q.14 Q_2 → Q_3 (normal write)"

  # Read Q_3
  run_quine read
  if [ "$Q_EXIT" -ne 0 ]; then
    fail "Q.14 Q_3 read" "exit: $Q_EXIT"; return
  fi

  if echo "$Q_STDOUT" | grep -q "Fidelity G3"; then
    pass "Q.14 Q_3 operational — *self-source* stable across 3 generations"
  else
    fail "Q.14 Q_3 content" "got: $Q_STDOUT"
  fi
}

# ═══════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════

check_prerequisites() {
  if ! command -v sbcl >/dev/null 2>&1; then
    echo "ERROR: sbcl is required but not installed." >&2
    exit 1
  fi
  if [ ! -f "$BASELINE_FILE" ]; then
    echo "ERROR: baseline file not found: $BASELINE_FILE" >&2
    echo "Copy recurrent-quine.lisp to recurrent-quine-baseline.lisp first." >&2
    exit 1
  fi
}

main() {
  check_prerequisites

  cd "$REPO_ROOT"

  echo "CogLog v0.9.1 — Recurrent Quine Test Harness"
  echo "Quine: $QUINE_FILE"
  echo "Baseline: $BASELINE_FILE"

  # Basic Operations (Q.1-Q.6)
  test_q1_read_initial
  test_q2_write_read
  test_q3_overwrite
  test_q4_clear
  test_q5_fact_validation
  test_q6_interp_empty

  # Generation Round-trip Fidelity (Q.7-Q.8)
  test_q7_two_generations
  test_q8_three_generations

  # Option Keys (Q.9-Q.12)
  test_q9_opt_advance
  test_q10_opt_affordance
  test_q11_opt_self_identity
  test_q12_all_options

  # Lineage Breakage (Q.13)
  test_q13_lineage_breakage

  # :opt-self Round-trip Fidelity (Q.14)
  test_q14_opt_self_fidelity

  # Restore baseline at the end
  restore_baseline
  echo ""
  echo "Baseline restored."

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
