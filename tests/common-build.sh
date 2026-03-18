#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# CogLog — shared toolchain check & auto-build helpers
# ═══════════════════════════════════════════════════════════════════
# Sourced by harness.sh, harness-mcp.sh, and tests-security/common.sh.
# Requires: REPO_ROOT (set by caller), skip() function (from caller).
# ═══════════════════════════════════════════════════════════════════

# Check that a command exists; print warning and return 1 if missing.
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
