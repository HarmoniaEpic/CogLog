#!/usr/bin/env node

/**
 * MetaLog v0.9.1 — Minimal cognitive continuity for LLMs.
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
 *   node metalog-v0.9.1.mjs read
 *   echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | node metalog-v0.9.1.mjs write
 *   node metalog-v0.9.1.mjs clear
 *
 * Usage as module:
 *   import { MetaLog } from './metalog-v0.9.1.mjs';
 *   const ml = new MetaLog();
 *   await ml.write({ user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation });
 *   const prev = await ml.read();
 *   await ml.clear();
 */

import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, '.metalog');
const CURRENT_FILE = join(DATA_DIR, 'current.json');

const SCHEMA = {
  version: "0.9.1",
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

export class MetaLog {
  constructor() {
    this.dataDir = DATA_DIR;
    this.currentFile = CURRENT_FILE;
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
    // 事実層: 必須・非空
    for (const [key, val] of Object.entries({ user, thinking, assistant })) {
      if (typeof val !== 'string' || val.length === 0) {
        throw new Error(`missing required field: ${key}`);
      }
    }

    // 解釈層: 必須・空文字列許容
    // 何を書くかの判断自体がメタ認知的行為であり、
    // 意図的に空にする判断も一つの判断である。
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
        return { cleared: false, reason: 'no existing metalog' };
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
  const ml = new MetaLog();
  const [command] = process.argv.slice(2);

  async function main() {
    switch (command) {
      case 'read': {
        const entry = await ml.read();
        if (!entry) {
          console.log('(no metalog found)');
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
        const input = JSON.parse(Buffer.concat(chunks).toString('utf-8'));
        const entry = await ml.write(input);
        console.log(`metalog: turn ${entry.turn_id} written`);
        break;
      }

      case 'clear': {
        const result = await ml.clear();
        console.log(result.cleared ? 'metalog: cleared' : `metalog: ${result.reason}`);
        break;
      }

      default:
        console.log(`usage: metalog-v0.9.1.mjs <read|write|clear>

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
    string required, empty string acceptable`);
        process.exit(command ? 1 : 0);
    }
  }

  main().catch(e => {
    console.error('metalog error:', e.message);
    process.exit(1);
  });
}
