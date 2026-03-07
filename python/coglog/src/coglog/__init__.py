#!/usr/bin/env python3
"""
CogLog — Minimal cognitive continuity for LLMs.

A single-window (size 1) log that holds the previous turn's three-layer
structure (user utterance, thinking process, assistant output) plus a
four-axis interpretation layer (current_focus, theory_of_mind,
self_narrative, annotation), making it available at the start of the
next turn.

Each entry includes a _schema field that makes the data self-documenting:
the JSON file itself describes how to read and write it.

Usage as CLI:
    python3 coglog.py read
    echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | python3 coglog.py write
    python3 coglog.py clear

Usage as module:
    from coglog import CogLog
    ml = CogLog(data_dir=coglog_dir)
    ml.write(user=..., thinking=..., assistant=..., current_focus=..., theory_of_mind=..., self_narrative=..., annotation=...)
    prev = ml.read()
    ml.clear()
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

DATA_DIR = Path(os.environ["COGLOG_DIR"]) if "COGLOG_DIR" in os.environ \
           else Path.home() / ".coglog"
CURRENT_FILE = DATA_DIR / "current.json"

SCHEMA = {
    "version": "0.9.1",  # @coglog-version
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


class CogLog:
    """Single-window coglog: records one turn, overwrites on next write.

    Data structure:
        _schema:                 Self-documenting schema (auto-generated).

        Fact layer (layers):     What happened. Three-layer record.
            user       — other's input
            thinking   — self's internal process
            assistant  — self's external output

        Interpretation layer:    How it was read. Four-axis free-form.
            current_focus   — present direction (what is happening now)
            theory_of_mind  — other direction (who is the user)
            self_narrative  — self direction (who am I right now)
            annotation      — future direction (what to do next)

    Validation:
        Fact layer:           non-empty string required
        Interpretation layer: string required, empty string acceptable
        (Choosing to write nothing is a valid metacognitive act.)
    """

    def __init__(self, data_dir=None):
        self.data_dir = Path(data_dir) if data_dir else DATA_DIR
        self.current_file = self.data_dir / "current.json"


    def read(self):
        """Read the previous turn's coglog. Returns dict or None."""
        try:
            with open(self.current_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return None

    def write(self, *, user, thinking, assistant, current_focus, theory_of_mind, self_narrative, annotation):
        """Write the current turn's coglog, overwriting the previous one.

        All parameters are keyword-only.

        Args:
            user:           User's utterance (verbatim). Non-empty string required.
            thinking:       AI's thinking process (full text). Non-empty string required.
            assistant:      AI's output (verbatim). Non-empty string required.
            current_focus:  What is happening right now. String required, empty acceptable.
            theory_of_mind: Inference about the user. String required, empty acceptable.
            self_narrative: Improvised self-story. String required, empty acceptable.
            annotation:     Note to future self. String required, empty acceptable.

        Returns:
            dict: The written entry (includes _schema).

        Raises:
            ValueError: If validation fails.
        """
        # Fact layer: required, non-empty
        for key, val in {"user": user, "thinking": thinking, "assistant": assistant}.items():
            if not isinstance(val, str) or len(val) == 0:
                raise ValueError(f"missing required field: {key}")

        # Interpretation layer: required, empty string acceptable
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
            "layers": {
                "user": user,
                "thinking": thinking,
                "assistant": assistant,
            },
            "current_focus": current_focus,
            "theory_of_mind": theory_of_mind,
            "self_narrative": self_narrative,
            "annotation": annotation,
        }

        with open(self.current_file, "w", encoding="utf-8") as f:
            json.dump(entry, f, ensure_ascii=False, indent=2)

        return entry


    def clear(self):
        """Clear the coglog. Returns dict with 'cleared' key."""
        try:
            os.remove(self.current_file)
            return {"cleared": True}
        except FileNotFoundError:
            return {"cleared": False, "reason": "no existing coglog"}


# ── CLI ──────────────────────────────────────────────────────────
def main():
    args = sys.argv[1:]
    # Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
    coglog_dir = None
    if len(args) >= 2 and args[0] == "--coglog-dir":
        coglog_dir = args[1]
        args = args[2:]
    command = args[0] if args else None
    ml = CogLog(data_dir=coglog_dir)

    if command == "read":
        entry = ml.read()
        if entry is None:
            print("(no coglog found)")
        else:
            print(json.dumps(entry, ensure_ascii=False, indent=2))

    elif command == "write":
        data = json.loads(sys.stdin.read())
        try:
            entry = ml.write(
                user=data.get("user"),
                thinking=data.get("thinking"),
                assistant=data.get("assistant"),
                current_focus=data.get("current_focus"),
                theory_of_mind=data.get("theory_of_mind"),
                self_narrative=data.get("self_narrative"),
                annotation=data.get("annotation"),
            )
            print(f"coglog: turn {entry['turn_id']} written")
        except (ValueError, TypeError) as e:
            print(f"coglog error: {e}", file=sys.stderr)
            sys.exit(1)

    elif command == "clear":
        result = ml.clear()
        if result["cleared"]:
            print("coglog: cleared")
        else:
            print(f"coglog: {result['reason']}")

    else:
        print("""usage: coglog.py <read|write|clear>

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
    string required, empty string acceptable""")
        sys.exit(1 if command else 0)



