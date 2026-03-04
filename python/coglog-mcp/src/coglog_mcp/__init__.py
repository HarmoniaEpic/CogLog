#!/usr/bin/env python3
"""
MetaLog MCP Server v0.9.1

Exposes MetaLog read/write/clear as MCP tools over stdio transport.
Single-file, zero external dependencies. Contains a complete copy of
the MetaLog class for standalone operation.

Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
Transport: stdio (newline-delimited JSON)
"""

import json
import sys
import os
from datetime import datetime, timezone
from pathlib import Path

# ═══════════════════════════════════════════════════════════════
# MetaLog class (copied from metalog-v0.9.1.py)
# ═══════════════════════════════════════════════════════════════

DATA_DIR = Path(os.environ["COGLOG_DIR"]) if "COGLOG_DIR" in os.environ \
           else Path.home() / ".coglog"
CURRENT_FILE = DATA_DIR / "current.json"

SCHEMA = {
    "version": "0.9.1",
    "fact_layer": {
        "user": "non-empty string required — user's original utterance",
        "thinking": "non-empty string required — AI's full thinking process",
        "assistant": "non-empty string required — AI's original output",
    },
    "interpretation_layer": {
        "current_focus": "string required, empty OK — present: what am I working on?",
        "theory_of_mind": "string required, empty OK — other: what is the user's state?",
        "self_narrative": "string required, empty OK — self: who am I in this moment?",
        "annotation": "string required, empty OK — future: what should I do next?",
    },
    "constraints": {
        "window_size": "1 turn (overwritten each write)",
        "interpretation_empty": "choosing not to write is itself a metacognitive act",
    },
}


class MetaLog:
    def __init__(self, data_dir=None):
        self.data_dir = Path(data_dir) if data_dir else DATA_DIR
        self.current_file = self.data_dir / "current.json"


    def read(self):
        try:
            with open(self.current_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return None

    def write(self, *, user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation):
        for key, val in {"user": user, "thinking": thinking, "assistant": assistant}.items():
            if not isinstance(val, str) or len(val) == 0:
                raise ValueError(f"missing required field: {key}")
        for key, val in {"current_focus": current_focus, "theory_of_mind": theory_of_mind, "self_narrative": self_narrative, "annotation": annotation}.items():
            if not isinstance(val, str):
                raise ValueError(f"missing required field: {key} (empty string is acceptable)")
        self.data_dir.mkdir(parents=True, exist_ok=True)
        prev = self.read()
        turn_id = (prev["turn_id"] + 1) if prev else 1
        entry = {
            "_schema": SCHEMA,
            "turn_id": turn_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "layers": {"user": user, "thinking": thinking, "assistant": assistant},
            "current_focus": current_focus,
            "theory_of_mind": theory_of_mind,
            "self_narrative": self_narrative,
            "annotation": annotation,
        }
        with open(self.current_file, "w", encoding="utf-8") as f:
            json.dump(entry, f, ensure_ascii=False, indent=2)
        return entry

    def clear(self):
        try:
            os.remove(self.current_file)
            return {"cleared": True}
        except FileNotFoundError:
            return {"cleared": False, "reason": "no existing metalog"}


# ═══════════════════════════════════════════════════════════════
# MCP tool definitions
# ═══════════════════════════════════════════════════════════════

TOOLS = [
    {
        "name": "metalog_read",
        "description": "Read the previous turn's metalog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no metalog exists.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
    },
    {
        "name": "metalog_write",
        "description": "Write the current turn's metalog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings — choosing not to write is itself a metacognitive act.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "user": {"type": "string", "description": "User's original utterance (non-empty)"},
                "thinking": {"type": "string", "description": "AI's full thinking process (non-empty)"},
                "assistant": {"type": "string", "description": "AI's original output (non-empty)"},
                "current_focus": {"type": "string", "description": "Present direction: what am I working on?"},
                "theory_of_mind": {"type": "string", "description": "Other direction: what is the user's state?"},
                "self_narrative": {"type": "string", "description": "Self direction: who am I in this moment?"},
                "annotation": {"type": "string", "description": "Future direction: what should I do next?"},
            },
            "required": ["user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"],
            "additionalProperties": False,
        },
    },
    {
        "name": "metalog_clear",
        "description": "Clear the metalog, removing the stored turn data. Returns whether the clear was successful.",
        "inputSchema": {
            "type": "object",
            "properties": {},
            "additionalProperties": False,
        },
    },
]


# ═══════════════════════════════════════════════════════════════
# JSON-RPC helpers
# ═══════════════════════════════════════════════════════════════

def send(obj):
    """Write a JSON-RPC message to stdout (one line, flushed)."""
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def send_result(msg_id, result):
    send({"jsonrpc": "2.0", "id": msg_id, "result": result})


def send_error(msg_id, code, message):
    send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": code, "message": message}})


def send_tool_result(msg_id, text, is_error=False):
    result = {"content": [{"type": "text", "text": text}]}
    if is_error:
        result["isError"] = True
    send_result(msg_id, result)


def log(msg):
    """Write to stderr (never contaminates stdout)."""
    sys.stderr.write(f"metalog-mcp: {msg}\n")
    sys.stderr.flush()


# ═══════════════════════════════════════════════════════════════
# MCP handlers
# ═══════════════════════════════════════════════════════════════

SERVER_INFO = {
    "name": "metalog",
    "version": "0.9.1",
}


def handle_initialize(msg_id, params):
    send_result(msg_id, {
        "protocolVersion": "2024-11-05",
        "capabilities": {"tools": {}},
        "serverInfo": SERVER_INFO,
    })


def handle_tools_list(msg_id):
    send_result(msg_id, {"tools": TOOLS})


def handle_tools_call(msg_id, params, ml):
    name = params.get("name")
    args = params.get("arguments", {})

    if name == "metalog_read":
        entry = ml.read()
        if entry is None:
            send_tool_result(msg_id, "(no metalog found)")
        else:
            send_tool_result(msg_id, json.dumps(entry, ensure_ascii=False, indent=2))

    elif name == "metalog_write":
        try:
            entry = ml.write(
                user=args.get("user"),
                thinking=args.get("thinking"),
                assistant=args.get("assistant"),
                current_focus=args.get("current_focus"),
                theory_of_mind=args.get("theory_of_mind"),
                self_narrative=args.get("self_narrative"),
                annotation=args.get("annotation"),
            )
            send_tool_result(msg_id, json.dumps(entry, ensure_ascii=False, indent=2))
        except (ValueError, TypeError) as e:
            send_tool_result(msg_id, f"Error: {e}", is_error=True)

    elif name == "metalog_clear":
        result = ml.clear()
        send_tool_result(msg_id, json.dumps(result, ensure_ascii=False))

    else:
        send_tool_result(msg_id, f"Error: unknown tool: {name}", is_error=True)


def handle_ping(msg_id):
    send_result(msg_id, {})


# ═══════════════════════════════════════════════════════════════
# Main loop
# ═══════════════════════════════════════════════════════════════

def main():
    ml = MetaLog(data_dir=coglog_dir)
    log("server started")

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            msg = json.loads(line)
        except json.JSONDecodeError as e:
            send_error(None, -32700, f"Parse error: {e}")
            continue

        method = msg.get("method")
        msg_id = msg.get("id")  # None for notifications
        params = msg.get("params", {})

        # Notification (no id) — never respond
        if msg_id is None:
            if method == "notifications/initialized":
                log("initialized")
            continue

        # Request (has id) — must respond
        if method == "initialize":
            handle_initialize(msg_id, params)
        elif method == "tools/list":
            handle_tools_list(msg_id)
        elif method == "tools/call":
            handle_tools_call(msg_id, params, ml)
        elif method == "ping":
            handle_ping(msg_id)
        else:
            send_error(msg_id, -32601, f"Method not found: {method}")

    log("server stopped")



