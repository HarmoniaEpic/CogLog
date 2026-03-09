#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog — Repository cleanup script
#
# Removes build artifacts, compiled outputs, and caches across all
# 11 language implementations.  Run manually before or after tests.
#
# Usage:
#   ./tests/clean.sh          # Clean all languages
#   ./tests/clean.sh --dry    # Show what would be removed
#
# Must be run from the repository root directory.
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DRY=false
if [ "${1:-}" = "--dry" ] || [ "${1:-}" = "--dry-run" ]; then
  DRY=true
fi

TOTAL=0

clean() {
  local target="$1"
  local label="${2:-$1}"
  if [ -e "$target" ]; then
    if $DRY; then
      local size
      size=$(du -sh "$target" 2>/dev/null | cut -f1)
      printf "  would remove %-50s %s\n" "$label" "($size)"
    else
      rm -rf "$target"
      printf "  removed %s\n" "$label"
    fi
    TOTAL=$((TOTAL + 1))
  fi
}

echo "CogLog — Repository cleanup"
if $DRY; then
  echo "(dry run — no files will be removed)"
fi
echo

# ── C++ (compiled binaries at repo root) ──
echo "C++:"
clean "$REPO_ROOT/cpp-coglog-cli"  "cpp-coglog-cli"
clean "$REPO_ROOT/cpp-coglog-mcp"  "cpp-coglog-mcp"

# ── Rust ──
echo "Rust:"
clean "$REPO_ROOT/rust/target"     "rust/target/"

# ── Java ──
echo "Java:"
clean "$REPO_ROOT/java/coglog/target"     "java/coglog/target/"
clean "$REPO_ROOT/java/coglog-mcp/target" "java/coglog-mcp/target/"

# ── C# ──
echo "C#:"
clean "$REPO_ROOT/csharp/coglog/bin"       "csharp/coglog/bin/"
clean "$REPO_ROOT/csharp/coglog/obj"       "csharp/coglog/obj/"
clean "$REPO_ROOT/csharp/coglog-mcp/bin"   "csharp/coglog-mcp/bin/"
clean "$REPO_ROOT/csharp/coglog-mcp/obj"   "csharp/coglog-mcp/obj/"

# ── Haskell ──
echo "Haskell:"
clean "$REPO_ROOT/haskell/coglog/dist-newstyle"     "haskell/coglog/dist-newstyle/"
clean "$REPO_ROOT/haskell/coglog-mcp/dist-newstyle" "haskell/coglog-mcp/dist-newstyle/"

# ── Go ──
echo "Go:"
clean "$REPO_ROOT/go/bin" "go/bin/"

# ── Python ──
echo "Python:"
clean "$REPO_ROOT/python/coglog/src/coglog/__pycache__"           "python/coglog/src/coglog/__pycache__/"
clean "$REPO_ROOT/python/coglog-mcp/src/coglog_mcp/__pycache__"   "python/coglog-mcp/src/coglog_mcp/__pycache__/"

# ── Node ──
echo "Node:"
clean "$REPO_ROOT/node/coglog/node_modules"     "node/coglog/node_modules/"
clean "$REPO_ROOT/node/coglog-mcp/node_modules" "node/coglog-mcp/node_modules/"

# ── Common Lisp ──
echo "Common Lisp:"
# FASL files are unlikely but clean known cache locations
clean "$REPO_ROOT/common-lisp/coglog/cache"     "common-lisp/coglog/cache/"
clean "$REPO_ROOT/common-lisp/coglog-mcp/cache" "common-lisp/coglog-mcp/cache/"

# ── Summary ──
echo
if [ "$TOTAL" -eq 0 ]; then
  echo "Nothing to clean."
elif $DRY; then
  printf "%d item(s) would be removed. Run without --dry to clean.\n" "$TOTAL"
else
  printf "%d item(s) removed.\n" "$TOTAL"
fi
