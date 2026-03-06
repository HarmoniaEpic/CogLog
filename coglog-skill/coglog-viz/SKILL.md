---
name: coglog-viz
description: "Provide cognitive continuity across conversation turns with per-turn visualization. Use this skill whenever maintaining context between turns matters and you want a visual artifact of each turn's cognitive state. Includes all CogLog functionality (read/write/clear) plus automatic React viewer generation on every write. Also use when the user mentions 'coglog', 'cog-log', 'coglog-viz', 'metalog', 'meta-log', 'self-narrative', 'current_focus', 'turn memory', or asks the AI to reflect on its own reasoning process across turns."
---

# CogLog Viz v0.9.1

Cognitive continuity for LLMs with per-turn visualization. A single-window (size 1) log that records the previous turn's three-layer structure and four-axis interpretation, making it available at the start of the next turn. Every write generates a React viewer artifact with color-coded structure and dark/light/system theme switching.

This is a standalone package. It includes all CogLog functionality and does not depend on the base coglog-skill.

## Core Concept

Current LLM architecture resets cognitive state every turn. The conversation history contains what was said, but **the distinction between "what I thought but didn't say" and "what I said" is lost**. CogLog preserves this distinction by recording three layers (user input, thinking process, assistant output) plus four axes of interpretation (current_focus, theory of mind, self-narrative, annotation).

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

The `_schema` field is auto-generated on every write. It makes the JSON file self-documenting: the data itself describes how to read and write it. Like a door handle that says "grip and turn", `_schema` tells the reader what each field expects.

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
coglog-viz read   ← Load previous turn's _schema + three layers + four axes
    │                (_schema acts as a per-turn anchor against drift)
    ▼
Normal processing ← Generate response with coglog as context
    │
    ▼
coglog-viz write  ← Save current turn + render viewer artifact
    │                (_schema auto-generated; previous overwritten;
    │                 viewer .jsx written to /mnt/user-data/outputs/)
    ▼
present_files     ← AI presents the generated .jsx artifact to user
```

Note: `coglog-viz.py write` generates the `.jsx` file. Presenting the artifact to the user (via `present_files`) is the AI's responsibility in its response flow, not the script's.

## Usage

```bash
# Read previous turn
python3 /mnt/skills/user/coglog-viz/scripts/coglog-viz.py read

# Write current turn + generate viewer artifact
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' \
  | python3 /mnt/skills/user/coglog-viz/scripts/coglog-viz.py write

# Clear
python3 /mnt/skills/user/coglog-viz/scripts/coglog-viz.py clear
```

The `write` command always generates a React viewer artifact at `/mnt/user-data/outputs/coglog-turn-{turn_id}.jsx`. This artifact renders the three layers and four axes with color-coded structure and supports dark/light/system theme switching.

## Visualization

The viewer displays each turn as a structured card:

- **Fact Layer** — user (warm amber), thinking (warm olive), assistant (warm sienna), distinguished by left border color
- **Interpretation Layer** — four axes in a 2×2 grid: current_focus (amber, present), theory_of_mind (teal, other), self_narrative (purple, self), annotation (green, future), distinguished by top border color
- **`_schema`** — collapsible; always present but hidden by default
- **Theme** — dark / light / system toggle in the header; defaults to system (OS preference via `matchMedia`)

## When to use CogLog Viz

- **Multi-turn collaboration**: Track evolving understanding across turns
- **Character / roleplay**: Maintain self-narrative as a character that grows through interaction
- **TRPG / game mastering**: Record world state, player intent, and GM's narrative stance — viewer serves as GM's window into NPC internals
- **Iterative coding**: Remember what was tried, what failed, and why — current_focus prevents "what was I doing?" drift
- **Tutoring**: Model the learner's understanding and adapt approach
- **Any conversation where visual turn-by-turn cognitive state adds value**

## Design principles

- **Window size 1**: Only the previous turn is retained. Overwritten each turn. Irreversibility = time's arrow
- **Four axes**: Present (current_focus) → Other (theory_of_mind) → Self (self_narrative) → Future (annotation)
- **Self-documenting**: `_schema` makes every entry carry its own reading instructions
- **All fields required**: The act of filling each field — or deliberately leaving it empty — is the metacognitive act
- **Free-form text**: Interpretation fields are unstructured. What to write is part of the judgment
- **Write = Visualize**: Every write produces a viewer artifact. Visualization is not optional — it is part of the protocol
- **Zero dependencies**: Pure Python stdlib (json, os, re, sys, datetime, pathlib). No external packages
- **Sandbox-native**: Runs inside the host's sandbox. No authentication, encryption, or network access. Security is the sandbox's responsibility

For full design rationale, see [DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md).
