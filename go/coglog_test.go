package coglog

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func tempCogLog(t *testing.T) *CogLog {
	t.Helper()
	dir := t.TempDir()
	return NewWithDir(dir)
}

func sampleArgs() WriteArgs {
	return WriteArgs{
		User:          "Hello",
		Thinking:      "User greeted me",
		Assistant:     "Hi there!",
		CurrentFocus:  "greeting",
		TheoryOfMind:  "friendly",
		SelfNarrative: "conversational partner",
		Annotation:    "",
	}
}

func TestReadEmpty(t *testing.T) {
	cl := tempCogLog(t)
	entry, err := cl.Read()
	if err != nil {
		t.Fatal(err)
	}
	if entry != nil {
		t.Fatal("expected nil for empty read")
	}
}

func TestWriteReadRoundtrip(t *testing.T) {
	cl := tempCogLog(t)
	written, err := cl.Write(sampleArgs())
	if err != nil {
		t.Fatal(err)
	}
	read, err := cl.Read()
	if err != nil {
		t.Fatal(err)
	}
	if read == nil {
		t.Fatal("expected non-nil read")
	}
	if written.TurnID != read.TurnID {
		t.Errorf("turn_id: %d != %d", written.TurnID, read.TurnID)
	}
	if written.Layers.User != read.Layers.User {
		t.Errorf("user: %q != %q", written.Layers.User, read.Layers.User)
	}
}

func TestTurnIDIncrement(t *testing.T) {
	cl := tempCogLog(t)
	e1, _ := cl.Write(sampleArgs())
	e2, _ := cl.Write(sampleArgs())
	if e1.TurnID != 1 {
		t.Errorf("first turn_id: %d, want 1", e1.TurnID)
	}
	if e2.TurnID != 2 {
		t.Errorf("second turn_id: %d, want 2", e2.TurnID)
	}
}

func TestClear(t *testing.T) {
	cl := tempCogLog(t)
	cl.Write(sampleArgs())
	result := cl.Clear()
	if !result.Cleared {
		t.Fatal("expected cleared=true")
	}
	entry, _ := cl.Read()
	if entry != nil {
		t.Fatal("expected nil after clear")
	}
}

func TestDoubleClear(t *testing.T) {
	cl := tempCogLog(t)
	result := cl.Clear()
	if result.Cleared {
		t.Fatal("expected cleared=false for empty clear")
	}
	if result.Reason != "no existing metalog" {
		t.Errorf("reason: %q", result.Reason)
	}
}

func TestValidationEmptyUser(t *testing.T) {
	cl := tempCogLog(t)
	args := sampleArgs()
	args.User = ""
	_, err := cl.Write(args)
	if err == nil {
		t.Fatal("expected validation error")
	}
}

func TestInterpretationEmptyOK(t *testing.T) {
	cl := tempCogLog(t)
	args := WriteArgs{
		User: "test", Thinking: "t", Assistant: "a",
		CurrentFocus: "", TheoryOfMind: "", SelfNarrative: "", Annotation: "",
	}
	entry, err := cl.Write(args)
	if err != nil {
		t.Fatal(err)
	}
	if entry.CurrentFocus != "" {
		t.Errorf("expected empty current_focus")
	}
}

func TestUTF8Japanese(t *testing.T) {
	cl := tempCogLog(t)
	args := WriteArgs{
		User: "日本語テスト", Thinking: "メタ認知ログ", Assistant: "こんにちは",
		CurrentFocus: "多言語対応", TheoryOfMind: "", SelfNarrative: "", Annotation: "",
	}
	cl.Write(args)
	read, _ := cl.Read()
	if read.Layers.User != "日本語テスト" {
		t.Errorf("user: %q", read.Layers.User)
	}
}

func TestSchemaPresent(t *testing.T) {
	cl := tempCogLog(t)
	entry, _ := cl.Write(sampleArgs())
	if entry.Schema.Version != "0.9.1" {
		t.Errorf("schema version: %q", entry.Schema.Version)
	}
}

func TestAdvancePure(t *testing.T) {
	now := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	args := sampleArgs()
	e1 := Advance(nil, args, now)
	if e1.TurnID != 1 {
		t.Errorf("turn_id: %d", e1.TurnID)
	}
	e2 := Advance(&e1, args, now)
	if e2.TurnID != 2 {
		t.Errorf("turn_id: %d", e2.TurnID)
	}
}

func TestJsonCompat(t *testing.T) {
	cl := tempCogLog(t)
	cl.Write(sampleArgs())
	data, err := os.ReadFile(filepath.Join(cl.DataDir, "current.json"))
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]interface{}
	if err := json.Unmarshal(data, &m); err != nil {
		t.Fatal(err)
	}
	if m["turn_id"].(float64) != 1 {
		t.Errorf("turn_id in JSON: %v", m["turn_id"])
	}
}
