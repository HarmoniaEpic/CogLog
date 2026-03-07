#!/usr/bin/env node

/**
 * CogLog MCP Server
 *
 * Exposes CogLog read/write/clear as MCP tools over stdio transport.
 * Single-file, zero external dependencies. Contains a complete copy of
 * the CogLog class for standalone operation.
 *
 * Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
 * Transport: stdio (newline-delimited JSON)
 */

import { createInterface } from 'node:readline';
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

// ═══════════════════════════════════════════════════════════════
// CogLog class (copied from coglog/index.mjs)
// ═══════════════════════════════════════════════════════════════

const DATA_DIR = process.env.COGLOG_DIR ?? join(homedir(), '.coglog');
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

class CogLog {
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
      if (e.code === 'ENOENT') return null;
      throw e;
    }
  }

  async write({ user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation }) {
    for (const [key, val] of Object.entries({ user, thinking, assistant })) {
      if (typeof val !== 'string' || val.length === 0) {
        throw new Error(`missing required field: ${key}`);
      }
    }
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
      layers: { user, thinking, assistant },
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
      if (e.code === 'ENOENT') return { cleared: false, reason: 'no existing coglog' };
      throw e;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// MCP tool definitions
// ═══════════════════════════════════════════════════════════════

const TOOLS = [
  {
    name: "coglog_read",
    description: "Read the previous turn's coglog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no coglog exists.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
  {
    name: "coglog_write",
    description: "Write the current turn's coglog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings — choosing not to write is itself a metacognitive act.",
    inputSchema: {
      type: "object",
      properties: {
        user: { type: "string", description: "User's original utterance (non-empty)" },
        thinking: { type: "string", description: "AI's full thinking process (non-empty)" },
        assistant: { type: "string", description: "AI's original output (non-empty)" },
        current_focus: { type: "string", description: "Present direction: what am I working on?" },
        theory_of_mind: { type: "string", description: "Other direction: what is the user's state?" },
        self_narrative: { type: "string", description: "Self direction: who am I in this moment?" },
        annotation: { type: "string", description: "Future direction: what should I do next?" },
      },
      required: ["user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"],
      additionalProperties: false,
    },
  },
  {
    name: "coglog_clear",
    description: "Clear the coglog, removing the stored turn data. Returns whether the clear was successful.",
    inputSchema: {
      type: "object",
      properties: {},
      additionalProperties: false,
    },
  },
];

// ═══════════════════════════════════════════════════════════════
// JSON-RPC helpers
// ═══════════════════════════════════════════════════════════════

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function sendResult(msgId, result) {
  send({ jsonrpc: "2.0", id: msgId, result });
}

function sendError(msgId, code, message) {
  send({ jsonrpc: "2.0", id: msgId, error: { code, message } });
}

function sendToolResult(msgId, text, isError = false) {
  const result = { content: [{ type: "text", text }] };
  if (isError) result.isError = true;
  sendResult(msgId, result);
}

function log(msg) {
  process.stderr.write(`coglog-mcp: ${msg}\n`);
}

// ═══════════════════════════════════════════════════════════════
// MCP handlers
// ═══════════════════════════════════════════════════════════════

const SERVER_INFO = { name: "coglog", version: "0.9.1" };  // @coglog-version

function handleInitialize(msgId, params) {
  sendResult(msgId, {
    protocolVersion: "2024-11-05",
    capabilities: { tools: {} },
    serverInfo: SERVER_INFO,
  });
}

function handleToolsList(msgId) {
  sendResult(msgId, { tools: TOOLS });
}

async function handleToolsCall(msgId, params, ml) {
  const name = params?.name;
  const args = params?.arguments || {};

  if (name === "coglog_read") {
    const entry = await ml.read();
    if (entry === null) {
      sendToolResult(msgId, "(no coglog found)");
    } else {
      sendToolResult(msgId, JSON.stringify(entry, null, 2));
    }

  } else if (name === "coglog_write") {
    try {
      const entry = await ml.write({
        user: args.user,
        thinking: args.thinking,
        assistant: args.assistant,
        current_focus: args.current_focus,
        theory_of_mind: args.theory_of_mind,
        self_narrative: args.self_narrative,
        annotation: args.annotation,
      });
      sendToolResult(msgId, JSON.stringify(entry, null, 2));
    } catch (e) {
      sendToolResult(msgId, `Error: ${e.message}`, true);
    }

  } else if (name === "coglog_clear") {
    const result = await ml.clear();
    sendToolResult(msgId, JSON.stringify(result));

  } else {
    sendToolResult(msgId, `Error: unknown tool: ${name}`, true);
  }
}

function handlePing(msgId) {
  sendResult(msgId, {});
}

// ═══════════════════════════════════════════════════════════════
// Main loop (serialized: each message fully processed before next)
// ═══════════════════════════════════════════════════════════════

// --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
{
  const argv = process.argv.slice(2);
  if (argv[0] === '--coglog-dir' && argv[1]) {
    process.env.COGLOG_DIR = argv[1];
  }
}
const ml = new CogLog(process.env.COGLOG_DIR ?? null);
const rl = createInterface({ input: process.stdin, terminal: false });

// Queue + drain loop to serialize async handlers.
// readline fires 'line' events synchronously; without serialization,
// a subsequent read can execute before a preceding write completes.
const queue = [];
let processing = false;

async function drain() {
  if (processing) return;
  processing = true;
  while (queue.length > 0) {
    const line = queue.shift();
    await processMessage(line);
  }
  processing = false;
}

async function processMessage(line) {
  line = line.trim();
  if (!line) return;

  let msg;
  try {
    msg = JSON.parse(line);
  } catch (e) {
    sendError(null, -32700, `Parse error: ${e.message}`);
    return;
  }

  const method = msg.method;
  const msgId = msg.id;       // undefined for notifications
  const params = msg.params || {};

  // Notification (no id) — never respond
  if (msgId === undefined || msgId === null) {
    if (method === "notifications/initialized") {
      log("initialized");
    }
    return;
  }

  // Request (has id) — must respond
  if (method === "initialize") {
    handleInitialize(msgId, params);
  } else if (method === "tools/list") {
    handleToolsList(msgId);
  } else if (method === "tools/call") {
    await handleToolsCall(msgId, params, ml);
  } else if (method === "ping") {
    handlePing(msgId);
  } else {
    sendError(msgId, -32601, `Method not found: ${method}`);
  }
}

log("server started");

rl.on('line', (line) => {
  queue.push(line);
  drain();
});

rl.on('close', () => {
  log("server stopped");
});
