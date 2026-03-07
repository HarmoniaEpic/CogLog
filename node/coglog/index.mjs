#!/usr/bin/env node

/**
 * CogLog — Minimal cognitive continuity for LLMs.
 *
 * A single-window (size 1) log that holds the previous turn's three-layer
 * structure (user utterance, thinking process, assistant output) plus a
 * four-axis interpretation layer (current_focus, theory_of_mind,
 * self_narrative, annotation), making it available at the start of the
 * next turn.
 *
 * Each entry includes a _schema field that makes the data self-documenting:
 * the JSON file itself describes how to read and write it.
 *
 * Usage as CLI:
 *   node coglog.mjs read
 *   echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | node coglog.mjs write
 *   node coglog.mjs clear
 *
 * Usage as module:
 *   import { CogLog } from './coglog.mjs';
 *   const ml = new CogLog();
 *   await ml.write({ user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation });
 *   const prev = await ml.read();
 *   await ml.clear();
 */

import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const DATA_DIR = process.env.COGLOG_DIR || join(homedir(), '.coglog');
const CURRENT_FILE = join(DATA_DIR, 'current.json');

const SCHEMA = {
  version: "0.9.1",  // @coglog-version
  fact_layer: {
    user: "non-empty string required — user's original utterance",
    thinking: "non-empty string required — AI's full thinking process",
    assistant: "non-empty string required — AI's original output"
  },
  interpretation_layer: {
    current_focus: "string required, empty OK — present: what am I working on?",
    theory_of_mind: "string required, empty OK — other: what is the user's state?",
    self_narrative: "string required, empty OK — self: who am I in this moment?",
    annotation: "string required, empty OK — future: what should I do next?"
  },
  constraints: {
    window_size: "1 turn (overwritten each write)",
    interpretation_empty: "choosing not to write is itself a metacognitive act"
  }
};

export class CogLog {
  constructor(dataDir = null) {
    this.dataDir = dataDir ?? DATA_DIR;
    this.currentFile = join(this.dataDir, 'current.json');
  }

  async _ensureDir() {
    if (!existsSync(this.dataDir)) {
      await mkdir(this.dataDir, { recursive: true });
    }
  }

  async read() {
    try {
      const raw = await readFile(this.currentFile, 'utf-8');
      return JSON.parse(raw);
    } catch (e) {
      if (e.code === 'ENOENT') {
        return null;
      }
      throw e;
    }
  }

  async write({ user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation }) {
    // Fact layer: required, non-empty
    for (const [key, val] of Object.entries({ user, thinking, assistant })) {
      if (typeof val !== 'string' || val.length === 0) {
        throw new Error(`missing required field: ${key}`);
      }
    }

    // Interpretation layer: required, empty string acceptable
    // The decision of what to write is itself a metacognitive act;
    // choosing to leave a field empty is a valid decision.
    for (const [key, val] of Object.entries({ current_focus, theory_of_mind, self_narrative, annotation })) {
      if (typeof val !== 'string') {
        throw new Error(`missing required field: ${key} (empty string is acceptable)`);
      }
    }

    await this._ensureDir();

    const prev = await this.read();
    const turn_id = prev ? prev.turn_id + 1 : 1;

    const entry = {
      _schema: SCHEMA,
      turn_id,
      timestamp: new Date().toISOString(),
      layers: {
        user,
        thinking,
        assistant
      },
      current_focus,
      theory_of_mind,
      self_narrative,
      annotation
    };

    await writeFile(this.currentFile, JSON.stringify(entry, null, 2), 'utf-8');
    return entry;
  }

  async clear() {
    try {
      await rm(this.currentFile);
      return { cleared: true };
    } catch (e) {
      if (e.code === 'ENOENT') {
        return { cleared: false, reason: 'no existing coglog' };
      }
      throw e;
    }
  }
}

// ── CLI ─────────────────────────────────────────────────────────
const isMain = process.argv[1] &&
  new URL(import.meta.url).pathname ===
  new URL('file://' + process.argv[1]).pathname;

if (isMain) {
  // Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
  let cliArgs = process.argv.slice(2);
  let coglogDir = null;
  if (cliArgs[0] === '--coglog-dir' && cliArgs[1]) {
    coglogDir = cliArgs[1];
    cliArgs = cliArgs.slice(2);
  }
  const ml = new CogLog(coglogDir);
  const [command] = cliArgs;

  async function main() {
    switch (command) {
      case 'read': {
        const entry = await ml.read();
        if (!entry) {
          console.log('(no coglog found)');
          process.exit(0);
        }
        console.log(JSON.stringify(entry, null, 2));
        break;
      }

      case 'write': {
        const chunks = [];
        for await (const chunk of process.stdin) {
          chunks.push(chunk);
        }
        try {
          const input = JSON.parse(Buffer.concat(chunks).toString('utf-8'));
          const entry = await ml.write(input);
          console.log(`coglog: turn ${entry.turn_id} written`);
        } catch (e) {
          if (e instanceof SyntaxError) {
            console.error('coglog error: invalid JSON input');
          } else if (e instanceof Error) {
            console.error(`coglog error: ${e.message}`);
          } else {
            console.error('coglog error: unknown write failure');
          }
          process.exit(1);
        }
        break;
      }

      case 'clear': {
        const result = await ml.clear();
        console.log(result.cleared ? 'coglog: cleared' : `coglog: ${result.reason}`);
        break;
      }

      default:
        console.log(`usage: coglog.mjs <read|write|clear>

  read    — display the previous turn's coglog
  write   — save current turn (reads JSON from stdin)
  clear   — reset coglog

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
    string required, empty string acceptable`);
        process.exit(command ? 1 : 0);
    }
  }

  main().catch(e => {
    console.error('coglog error:', e.message);
    process.exit(1);
  });
}
