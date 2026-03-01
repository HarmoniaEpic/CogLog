/**
 * MetaLog MCP Server v0.9.1 — QuickJS edition
 *
 * Functionally identical to the Python/Node versions.
 * Uses QuickJS std/os modules instead of Node.js APIs.
 * Zero external dependencies. Designed for qjsc compilation.
 */
import * as std from "std";
import * as os from "os";

// ─── Schema ───
const SCHEMA = {
  _schema: {
    version: "0.9.1",
    fact_layer: {
      user: "non-empty string required",
      thinking: "non-empty string required",
      assistant: "non-empty string required",
    },
    interpretation_layer: {
      current_focus: "string required, empty OK",
      theory_of_mind: "string required, empty OK",
      self_narrative: "string required, empty OK",
      annotation: "string required, empty OK",
    },
    constraints: {
      window_size: "1 turn (overwritten each write)",
      interpretation_empty: "choosing not to write is itself a metacognitive act",
    },
  },
};

// ─── Path helpers (no node:path) ───
function pathJoin(...parts) {
  return parts.join("/").replace(/\/+/g, "/");
}

function scriptDir() {
  // QuickJS: use current working directory
  return ".";
}

const DATA_DIR = pathJoin(scriptDir(), ".metalog");
const CURRENT_FILE = pathJoin(DATA_DIR, "current.json");

// ─── File system helpers ───
function fileExists(path) {
  const st = os.stat(path);
  return st[1] === 0; // st = [stat_obj, errno]; errno 0 = success
}

function ensureDir(path) {
  if (!fileExists(path)) {
    os.mkdir(path, 0o755);
  }
}

function readJSON(path) {
  const content = std.loadFile(path);
  if (content === null) return null;
  return JSON.parse(content);
}

function writeJSON(path, data) {
  const f = std.open(path, "w");
  if (!f) throw new Error("cannot open " + path + " for writing");
  f.puts(JSON.stringify(data, null, 2));
  f.close();
}

// ─── MetaLog core ───
function metalogRead() {
  if (!fileExists(CURRENT_FILE)) return null;
  return readJSON(CURRENT_FILE);
}

function metalogWrite(args) {
  // Validate fact layer (non-empty)
  for (const key of ["user", "thinking", "assistant"]) {
    if (typeof args[key] !== "string" || args[key].length === 0) {
      throw new Error("missing required field: " + key + " (non-empty string required)");
    }
  }
  // Validate interpretation layer (string, empty OK)
  for (const key of ["current_focus", "theory_of_mind", "self_narrative", "annotation"]) {
    if (typeof args[key] !== "string") {
      throw new Error("missing required field: " + key + " (empty string is acceptable)");
    }
  }

  ensureDir(DATA_DIR);
  const prev = metalogRead();
  const turn_id = prev ? prev.turn_id + 1 : 1;

  const entry = Object.assign({}, SCHEMA, {
    turn_id: turn_id,
    timestamp: new Date().toISOString(),
    layers: {
      user: args.user,
      thinking: args.thinking,
      assistant: args.assistant,
    },
    current_focus: args.current_focus,
    theory_of_mind: args.theory_of_mind,
    self_narrative: args.self_narrative,
    annotation: args.annotation,
  });

  writeJSON(CURRENT_FILE, entry);
  return entry;
}

function metalogClear() {
  if (!fileExists(CURRENT_FILE)) {
    return { cleared: false, reason: "no existing metalog" };
  }
  os.remove(CURRENT_FILE);
  return { cleared: true };
}

// ─── JSON-RPC / MCP protocol ───
function jsonrpcResponse(id, result) {
  return { jsonrpc: "2.0", id: id, result: result };
}

function jsonrpcError(id, code, message) {
  return { jsonrpc: "2.0", id: id, error: { code: code, message: message } };
}

function toolResult(id, text, isError) {
  const result = { content: [{ type: "text", text: text }] };
  if (isError) result.isError = true;
  return jsonrpcResponse(id, result);
}

// ─── Tool definitions ───
const TOOLS = [
  {
    name: "metalog_read",
    description: "Read the previous turn's metalog.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "metalog_write",
    description: "Write the current turn's metalog, overwriting the previous one.",
    inputSchema: {
      type: "object",
      properties: {
        user: { type: "string" },
        thinking: { type: "string" },
        assistant: { type: "string" },
        current_focus: { type: "string" },
        theory_of_mind: { type: "string" },
        self_narrative: { type: "string" },
        annotation: { type: "string" },
      },
      required: ["user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"],
    },
  },
  {
    name: "metalog_clear",
    description: "Clear the metalog.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
];

// ─── Request dispatch ───
function handleRequest(msg) {
  const id = msg.id;
  const method = msg.method;

  // Notifications (no id) — no response
  if (id === undefined) return null;

  switch (method) {
    case "initialize":
      return jsonrpcResponse(id, {
        protocolVersion: "2024-11-05",
        capabilities: { tools: {} },
        serverInfo: { name: "metalog", version: "0.9.1" },
      });

    case "ping":
      return jsonrpcResponse(id, {});

    case "tools/list":
      return jsonrpcResponse(id, { tools: TOOLS });

    case "tools/call": {
      const name = msg.params && msg.params.name;
      const args = (msg.params && msg.params.arguments) || {};

      if (name === "metalog_read") {
        const entry = metalogRead();
        if (!entry) return toolResult(id, "(no metalog found)", false);
        return toolResult(id, JSON.stringify(entry, null, 2), false);
      }

      if (name === "metalog_write") {
        try {
          const entry = metalogWrite(args);
          return toolResult(id, JSON.stringify(entry, null, 2), false);
        } catch (e) {
          return toolResult(id, "Error: " + e.message, true);
        }
      }

      if (name === "metalog_clear") {
        const result = metalogClear();
        return toolResult(id, JSON.stringify(result), false);
      }

      return toolResult(id, "Error: unknown tool: " + name, true);
    }

    default:
      return jsonrpcError(id, -32601, "Method not found: " + method);
  }
}

// ─── Main: read stdin line by line ───
function main() {
  std.err.puts("metalog-mcp: server started\n");

  for (;;) {
    const line = std.in.getline();
    if (line === null) break; // EOF

    const trimmed = line.trim();
    if (trimmed.length === 0) continue;

    let msg;
    try {
      msg = JSON.parse(trimmed);
    } catch (e) {
      const err = jsonrpcError(null, -32700, "Parse error");
      std.out.puts(JSON.stringify(err) + "\n");
      std.out.flush();
      continue;
    }

    const response = handleRequest(msg);
    if (response !== null) {
      std.out.puts(JSON.stringify(response) + "\n");
      std.out.flush();
    }
  }

  std.err.puts("metalog-mcp: server stopped\n");
}

main();
