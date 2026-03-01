#!/usr/bin/env qjs --std

/**
 * MetaLog v0.9.1 — Minimal cognitive continuity for LLMs.
 * QuickJS edition.
 *
 * Functionally identical to the Node.js CLI version.
 * Uses QuickJS std/os modules instead of Node.js APIs.
 * Zero external dependencies. Designed for qjsc compilation.
 *
 * Usage as CLI:
 *   qjs --std metalog-v0_9_1_qjs.js read
 *   echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | qjs --std metalog-v0_9_1_qjs.js write
 *   qjs --std metalog-v0_9_1_qjs.js clear
 *
 * Compile to native binary:
 *   qjsc -e -o metalog.c metalog-v0_9_1_qjs.js
 *   cosmocc -Os -flto -I./quickjs -o metalog metalog.c quickjs/*.c -lm
 */

import * as std from "std";
import * as os from "os";

// ─── Schema ───
const SCHEMA = {
  version: "0.9.1",
  fact_layer: {
    user: "non-empty string required — user's original utterance",
    thinking: "non-empty string required — AI's full thinking process",
    assistant: "non-empty string required — AI's original output",
  },
  interpretation_layer: {
    current_focus: "string required, empty OK — present: what am I working on?",
    theory_of_mind: "string required, empty OK — other: what is the user's state?",
    self_narrative: "string required, empty OK — self: who am I in this moment?",
    annotation: "string required, empty OK — future: what should I do next?",
  },
  constraints: {
    window_size: "1 turn (overwritten each write)",
    interpretation_empty: "choosing not to write is itself a metacognitive act",
  },
};

// ─── Path helpers ───
function fileExists(path) {
  const st = os.stat(path);
  return st[1] === 0;
}

const DATA_DIR = "./.metalog";
const CURRENT_FILE = DATA_DIR + "/current.json";

// ─── MetaLog core ───
class MetaLog {
  constructor() {
    this.dataDir = DATA_DIR;
    this.currentFile = CURRENT_FILE;
  }

  _ensureDir() {
    if (!fileExists(this.dataDir)) {
      os.mkdir(this.dataDir, 0o755);
    }
  }

  read() {
    const content = std.loadFile(this.currentFile);
    if (content === null) return null;
    return JSON.parse(content);
  }

  write({ user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation }) {
    // 事実層: 必須・非空
    for (const [key, val] of Object.entries({ user, thinking, assistant })) {
      if (typeof val !== "string" || val.length === 0) {
        throw new Error("missing required field: " + key);
      }
    }

    // 解釈層: 必須・空文字列許容
    // 何を書くかの判断自体がメタ認知的行為であり、
    // 意図的に空にする判断も一つの判断である。
    for (const [key, val] of Object.entries({ current_focus, theory_of_mind, self_narrative, annotation })) {
      if (typeof val !== "string") {
        throw new Error("missing required field: " + key + " (empty string is acceptable)");
      }
    }

    this._ensureDir();

    const prev = this.read();
    const turn_id = prev ? prev.turn_id + 1 : 1;

    const entry = {
      _schema: SCHEMA,
      turn_id,
      timestamp: new Date().toISOString(),
      layers: {
        user,
        thinking,
        assistant,
      },
      current_focus,
      theory_of_mind,
      self_narrative,
      annotation,
    };

    const f = std.open(this.currentFile, "w");
    if (!f) throw new Error("cannot open " + this.currentFile + " for writing");
    f.puts(JSON.stringify(entry, null, 2));
    f.close();
    return entry;
  }

  clear() {
    if (!fileExists(this.currentFile)) {
      return { cleared: false, reason: "no existing metalog" };
    }
    os.remove(this.currentFile);
    return { cleared: true };
  }
}

// ─── CLI ───
const ml = new MetaLog();
const command = scriptArgs[1]; // scriptArgs[0] is the script path

switch (command) {
  case "read": {
    const entry = ml.read();
    if (!entry) {
      std.out.puts("(no metalog found)\n");
      std.exit(0);
    }
    std.out.puts(JSON.stringify(entry, null, 2) + "\n");
    break;
  }

  case "write": {
    // Read JSON from stdin
    const lines = [];
    for (;;) {
      const line = std.in.getline();
      if (line === null) break;
      lines.push(line);
    }
    const raw = lines.join("\n");
    if (raw.trim().length === 0) {
      std.err.puts("metalog error: no input on stdin\n");
      std.exit(1);
    }
    try {
      const input = JSON.parse(raw);
      const entry = ml.write(input);
      std.out.puts("metalog: turn " + entry.turn_id + " written\n");
    } catch (e) {
      std.err.puts("metalog error: " + e.message + "\n");
      std.exit(1);
    }
    break;
  }

  case "clear": {
    const result = ml.clear();
    std.out.puts(result.cleared ? "metalog: cleared\n" : "metalog: " + result.reason + "\n");
    break;
  }

  default:
    std.out.puts(`usage: metalog <read|write|clear>

  read    — display the previous turn's metalog
  write   — save current turn (reads JSON from stdin)
  clear   — reset metalog

write expects JSON on stdin (all fields required):
  {
    "user": "user's message",
    "thinking": "AI thinking process",
    "assistant": "AI output",
    "current_focus": "what is happening right now",
    "theory_of_mind": "user intent/state inference",
    "self_narrative": "improvised self-story at this moment",
    "annotation": "note to future self"
  }

  fact layer (user, thinking, assistant): non-empty string required
  interpretation layer (current_focus, theory_of_mind, self_narrative, annotation):
    string required, empty string acceptable
`);
    std.exit(command !== undefined ? 1 : 0);
}
