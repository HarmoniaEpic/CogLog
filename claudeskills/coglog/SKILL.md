---
name: metalog
description: "Provide cognitive continuity across conversation turns using a single-window log. Use this skill whenever maintaining context between turns matters: multi-turn creative collaboration, character roleplay, TRPG sessions, coding with iterative refinement, tutoring, or any conversation where the AI should remember what it was thinking (not just what it said) in the previous turn. Also use when the user mentions 'metalog', 'meta-log', 'self-narrative', 'current_focus', 'turn memory', or asks the AI to reflect on its own reasoning process across turns."
---

# MetaLog v0.9.1

Minimal cognitive continuity for LLMs. A single-window (size 1) log that records the previous turn's three-layer structure and four-axis interpretation, making it available at the start of the next turn. Each entry is self-documenting via a `_schema` field.

## Core Concept

Current LLM architecture resets cognitive state every turn. The conversation history contains what was said, but **the distinction between "what I thought but didn't say" and "what I said" is lost**. MetaLog preserves this distinction by recording three layers (user input, thinking process, assistant output) plus four axes of interpretation (current_focus, theory of mind, self-narrative, annotation).

The structure is a recurrence relation: $a_{n+1} = f(a_n)$. Window size 1 gives the system Markov property — the future depends only on the present state, not the full history. This constraint forces compression and selection, making the choice of what to record a metacognitive act in itself.

## Data Structure

```json
{
  "_schema": {
    "version": "0.9.1",
    "fact_layer": {
      "user": "non-empty string required — user's original utterance",
      "thinking": "non-empty string required — AI's full thinking process",
      "assistant": "non-empty string required — AI's original output"
    },
    "interpretation_layer": {
      "current_focus": "string required, empty OK — present: what am I working on?",
      "theory_of_mind": "string required, empty OK — other: what is the user's state?",
      "self_narrative": "string required, empty OK — self: who am I in this moment?",
      "annotation": "string required, empty OK — future: what should I do next?"
    },
    "constraints": {
      "window_size": "1 turn (overwritten each write)",
      "interpretation_empty": "choosing not to write is itself a metacognitive act"
    }
  },
  "turn_id": 1,
  "timestamp": "2026-02-26T00:00:00+00:00",
  "layers": {
    "user": "User's utterance (verbatim)",
    "thinking": "AI's thinking process (full text)",
    "assistant": "AI's output (verbatim)"
  },
  "current_focus": "What I am working on right now",
  "theory_of_mind": "Inference about the user — who they are right now",
  "self_narrative": "Improvised self-story — who I am right now",
  "annotation": "Note to future self — what to do next"
}
```

### `_schema`: self-documenting data

The `_schema` field is auto-generated on every write. It makes the JSON file self-documenting: the data itself describes how to read and write it. Like a door handle that says "grip and turn", `_schema` tells the reader what each field expects. This is an affordance — the data provides its own usage instructions.

When exporting a metalog from a previous session, `_schema` travels with the data. No README or DESIGN document is needed for the next session's AI to understand the format.

### Two-tier validation

All fields are required. The fact layer and interpretation layer differ in empty-string handling:

| Layer | Fields | Empty allowed? | Rationale |
|-------|--------|---------------|-----------|
| Fact | user, thinking, assistant | No | Absence of fact = missing data |
| Interpretation | current_focus, theory_of_mind, self_narrative, annotation | Yes | Choosing to write nothing is a valid metacognitive act |

### Interpretation layer: four axes

| Field | Direction | Question it answers |
|-------|-----------|-------------------|
| `current_focus` | Present | What am I working on right now? |
| `theory_of_mind` | Other | Who is the user right now? |
| `self_narrative` | Self | Who am I right now? |
| `annotation` | Future | What should I do next? |

The order follows a cognitive bootstrap sequence: orient to the present, read the other, locate the self, decide the next action.

Boundaries between the four are intentionally blurred. Overlap is permitted and expected.

**current_focus guide**: Write what you are working on right now. Like a child on an errand chanting "eggs, milk, eggs, milk" — a recitation of the immediate goal. When the context window grows long, "what am I even doing?" gets buried. current_focus is an explicit counter to that burial.

**self_narrative guide**: Write who "I" am at this moment — not a fixed self-definition ("I am a language model"), not a self-evaluation ("I responded well"). An improvised self-story that emerges from this dialogue, reconstructed each turn.

## Workflow

```
Turn start
    │
    ▼
metalog read    ← Load previous turn's _schema + three layers + four axes
    │              (_schema acts as a per-turn anchor against drift)
    ▼
Normal processing ← Generate response with metalog as context
    │
    ▼
metalog write   ← Save current turn (_schema auto-generated; previous overwritten)
```

## Usage

### Option A: Script (recommended for structured use)

```python
import sys
sys.path.insert(0, '/mnt/skills/user/metalog/scripts')
from metalog import MetaLog

ml = MetaLog()  # writes to /home/claude/.metalog/ by default

# Read previous turn
prev = ml.read()
if prev:
    print(f"Previous turn #{prev['turn_id']}:")
    print(f"  current_focus: {prev['current_focus']}")
    print(f"  theory_of_mind: {prev['theory_of_mind']}")
    print(f"  self_narrative: {prev['self_narrative']}")
    print(f"  annotation: {prev['annotation']}")

# After generating response, write current turn
ml.write(
    user="the user's message this turn",
    thinking="my internal reasoning this turn",
    assistant="my visible response this turn",
    current_focus="what I am working on right now",
    theory_of_mind="what I infer about the user",
    self_narrative="who I am after this exchange",
    annotation="what I want my next self to know",
)
```

### Option B: CLI

```bash
# Read
python3 /mnt/skills/user/metalog/scripts/metalog.py read

# Write (JSON on stdin)
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' \
  | python3 /mnt/skills/user/metalog/scripts/metalog.py write

# Clear
python3 /mnt/skills/user/metalog/scripts/metalog.py clear
```

### Option C: Minimal (no tools needed)

Share this template in the system prompt or conversation:

```
At the end of each response, output a metalog block:
{"current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}
```

Even without file I/O, the recurrence relation runs through the conversation history.

## When to use MetaLog

- **Multi-turn collaboration**: Track evolving understanding across turns
- **Character / roleplay**: Maintain self-narrative as a character that grows through interaction
- **TRPG / game mastering**: Record world state, player intent, and GM's narrative stance
- **Iterative coding**: Remember what was tried, what failed, and why — current_focus prevents "what was I doing?" drift
- **Tutoring**: Model the learner's understanding and adapt approach
- **Any conversation where "what I thought but didn't say" matters for the next turn**

## Design principles

- **Window size 1**: Only the previous turn is retained. Overwritten each turn. Irreversibility = time's arrow
- **Four axes**: Present (current_focus) → Other (theory_of_mind) → Self (self_narrative) → Future (annotation)
- **Self-documenting**: `_schema` makes every entry carry its own reading instructions
- **All fields required**: The act of filling each field — or deliberately leaving it empty — is the metacognitive act
- **Free-form text**: Interpretation fields are unstructured. What to write is part of the judgment
- **Zero dependencies**: Pure Python stdlib. JSON read/write only
- **Portable**: Same protocol works as file I/O, MCP server, Ollama tool, or system prompt convention

For full design rationale, read `references/DESIGN.md`.
