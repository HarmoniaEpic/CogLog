// Package coglog provides CogLog — minimal cognitive continuity for LLMs.
//
// A single-window (size 1) log that holds the previous turn's three-layer
// structure (user utterance, thinking process, assistant output) plus a
// four-axis interpretation layer (current_focus, theory_of_mind,
// self_narrative, annotation), making it available at the start of the
// next turn.
package coglog

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// ═══════════════════════════════════════════════════════════════════
// Data types
// ═══════════════════════════════════════════════════════════════════

// FactLayerSchema describes the fact layer in _schema.
type FactLayerSchema struct {
	User      string `json:"user"`
	Thinking  string `json:"thinking"`
	Assistant string `json:"assistant"`
}

// InterpretationLayerSchema describes the interpretation layer in _schema.
type InterpretationLayerSchema struct {
	CurrentFocus  string `json:"current_focus"`
	TheoryOfMind  string `json:"theory_of_mind"`
	SelfNarrative string `json:"self_narrative"`
	Annotation    string `json:"annotation"`
}

// ConstraintsSchema describes constraints in _schema.
type ConstraintsSchema struct {
	WindowSize          string `json:"window_size"`
	InterpretationEmpty string `json:"interpretation_empty"`
}

// Schema is the self-documenting _schema field embedded in each entry.
type Schema struct {
	Version             string                    `json:"version"`
	FactLayer           FactLayerSchema           `json:"fact_layer"`
	InterpretationLayer InterpretationLayerSchema `json:"interpretation_layer"`
	Constraints         ConstraintsSchema         `json:"constraints"`
}

// Layers holds the fact layer: what happened.
type Layers struct {
	User      string `json:"user"`
	Thinking  string `json:"thinking"`
	Assistant string `json:"assistant"`
}

// Entry is a single CogLog turn.
type Entry struct {
	Schema       Schema `json:"_schema"`
	TurnID       int    `json:"turn_id"`
	Timestamp    string `json:"timestamp"`
	Layers       Layers `json:"layers"`
	CurrentFocus  string `json:"current_focus"`
	TheoryOfMind  string `json:"theory_of_mind"`
	SelfNarrative string `json:"self_narrative"`
	Annotation    string `json:"annotation"`
}

// WriteArgs is the input for writing a new entry.
type WriteArgs struct {
	User          string `json:"user"`
	Thinking      string `json:"thinking"`
	Assistant     string `json:"assistant"`
	CurrentFocus  string `json:"current_focus"`
	TheoryOfMind  string `json:"theory_of_mind"`
	SelfNarrative string `json:"self_narrative"`
	Annotation    string `json:"annotation"`
}

// ClearResult is the result of a clear operation.
type ClearResult struct {
	Cleared bool   `json:"cleared"`
	Reason  string `json:"reason,omitempty"`
}

// ═══════════════════════════════════════════════════════════════════
// Schema constant
// ═══════════════════════════════════════════════════════════════════

// MakeSchema returns the CogLog schema.
func MakeSchema() Schema {
	return Schema{
		Version: "0.9.1",  // @coglog-version
		FactLayer: FactLayerSchema{
			User:      "non-empty string required \u2014 user's original utterance",
			Thinking:  "non-empty string required \u2014 AI's full thinking process",
			Assistant: "non-empty string required \u2014 AI's original output",
		},
		InterpretationLayer: InterpretationLayerSchema{
			CurrentFocus:  "string required, empty OK \u2014 present: what am I working on?",
			TheoryOfMind:  "string required, empty OK \u2014 other: what is the user's state?",
			SelfNarrative: "string required, empty OK \u2014 self: who am I in this moment?",
			Annotation:    "string required, empty OK \u2014 future: what should I do next?",
		},
		Constraints: ConstraintsSchema{
			WindowSize:          "1 turn (overwritten each write)",
			InterpretationEmpty: "choosing not to write is itself a metacognitive act",
		},
	}
}

// ═══════════════════════════════════════════════════════════════════
// Validation
// ═══════════════════════════════════════════════════════════════════

// ErrValidation indicates a validation failure.
var ErrValidation = errors.New("validation error")

// Validate checks that WriteArgs satisfy CogLog constraints.
// Fact layer fields must be non-empty strings.
// Interpretation layer fields are strings (empty acceptable).
func (a *WriteArgs) Validate() error {
	if a.User == "" {
		return fmt.Errorf("%w: missing required field: user", ErrValidation)
	}
	if a.Thinking == "" {
		return fmt.Errorf("%w: missing required field: thinking", ErrValidation)
	}
	if a.Assistant == "" {
		return fmt.Errorf("%w: missing required field: assistant", ErrValidation)
	}
	return nil
}

// ParseWriteArgs parses JSON bytes into WriteArgs, verifying that all
// interpretation layer fields are explicitly present in the input.
// Go's json.Unmarshal silently assigns zero values to missing fields,
// so we first check field presence via map[string]interface{}.
func ParseWriteArgs(data []byte) (WriteArgs, error) {
	var raw map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return WriteArgs{}, fmt.Errorf("invalid JSON: %w", err)
	}
	for _, key := range []string{"current_focus", "theory_of_mind", "self_narrative", "annotation"} {
		val, ok := raw[key]
		if !ok {
			return WriteArgs{}, fmt.Errorf("%w: missing required field: %s (empty string is acceptable)", ErrValidation, key)
		}
		if _, isStr := val.(string); !isStr {
			return WriteArgs{}, fmt.Errorf("%w: field %s must be a string", ErrValidation, key)
		}
	}
	var args WriteArgs
	if err := json.Unmarshal(data, &args); err != nil {
		return WriteArgs{}, fmt.Errorf("invalid JSON: %w", err)
	}
	return args, nil
}

// ═══════════════════════════════════════════════════════════════════
// Advance — pure entry construction
// ═══════════════════════════════════════════════════════════════════

// Advance constructs a new Entry from the previous entry and write arguments.
// This is the core recurrence relation: a_{n+1} = f(a_n, x_n).
func Advance(prev *Entry, args WriteArgs, now time.Time) Entry {
	turnID := 1
	if prev != nil {
		turnID = prev.TurnID + 1
	}
	return Entry{
		Schema:    MakeSchema(),
		TurnID:    turnID,
		Timestamp: now.UTC().Format("2006-01-02T15:04:05Z"),
		Layers: Layers{
			User:      args.User,
			Thinking:  args.Thinking,
			Assistant: args.Assistant,
		},
		CurrentFocus:  args.CurrentFocus,
		TheoryOfMind:  args.TheoryOfMind,
		SelfNarrative: args.SelfNarrative,
		Annotation:    args.Annotation,
	}
}

// ═══════════════════════════════════════════════════════════════════
// CogLog — file I/O layer
// ═══════════════════════════════════════════════════════════════════

// CogLog manages a single-window coglog stored as current.json.
type CogLog struct {
	DataDir     string
	CurrentFile string
}

// defaultCoglogDir returns the default data directory.
// Priority: COGLOG_DIR env > $HOME/.coglog > ./.coglog (final fallback)
func defaultCoglogDir() string {
	if d := os.Getenv("COGLOG_DIR"); d != "" {
		return d
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".coglog"
	}
	return filepath.Join(home, ".coglog")
}

// New creates a CogLog with the default data directory (~/.coglog).
func New() *CogLog {
	dataDir := defaultCoglogDir()
	return &CogLog{
		DataDir:     dataDir,
		CurrentFile: filepath.Join(dataDir, "current.json"),
	}
}

// NewWithDir creates a CogLog with a custom data directory.
func NewWithDir(dir string) *CogLog {
	return &CogLog{
		DataDir:     dir,
		CurrentFile: filepath.Join(dir, "current.json"),
	}
}

// Read returns the previous turn's entry, or nil if none exists.
func (c *CogLog) Read() (*Entry, error) {
	data, err := os.ReadFile(c.CurrentFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	var entry Entry
	if err := json.Unmarshal(data, &entry); err != nil {
		return nil, err
	}
	return &entry, nil
}

// Write validates args, constructs a new entry, and writes it to current.json.
func (c *CogLog) Write(args WriteArgs) (*Entry, error) {
	if err := args.Validate(); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(c.DataDir, 0755); err != nil {
		return nil, err
	}
	prev, err := c.Read()
	if err != nil {
		return nil, err
	}
	entry := Advance(prev, args, time.Now())
	data, err := json.MarshalIndent(entry, "", "  ")
	if err != nil {
		return nil, err
	}
	data = append(data, '\n')
	if err := os.WriteFile(c.CurrentFile, data, 0644); err != nil {
		return nil, err
	}
	return &entry, nil
}

// Clear removes the current.json file.
func (c *CogLog) Clear() ClearResult {
	if err := os.Remove(c.CurrentFile); err != nil {
		if os.IsNotExist(err) {
			return ClearResult{Cleared: false, Reason: "no existing coglog"}
		}
		return ClearResult{Cleared: false, Reason: err.Error()}
	}
	return ClearResult{Cleared: true}
}
