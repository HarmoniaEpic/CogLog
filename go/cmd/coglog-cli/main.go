// CogLog CLI v0.9.1
//
// Usage:
//
//	coglog-cli read
//	echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | coglog-cli write
//	coglog-cli clear
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"

	coglog "github.com/HarmoniaEpic/coglog/go"
)

func printUsage() {
	fmt.Print(`usage: coglog-cli <read|write|clear>

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
  interpretation layer (current_focus, theory_of_mind,
    self_narrative, annotation): string required, empty string acceptable
`)
}

func run() error {
	// --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
	args := os.Args[1:]
	var cl *coglog.CogLog
	if len(args) >= 2 && args[0] == "--coglog-dir" {
		cl = coglog.NewWithDir(args[1])
		args = args[2:]
	} else {
		cl = coglog.New()
	}

	if len(args) < 1 {
		printUsage()
		return nil
	}

	switch args[0] {
	case "read":
		entry, err := cl.Read()
		if err != nil {
			return err
		}
		if entry == nil {
			fmt.Println("(no metalog found)")
			return nil
		}
		data, err := json.MarshalIndent(entry, "", "  ")
		if err != nil {
			return err
		}
		fmt.Println(string(data))

	case "write":
		input, err := io.ReadAll(os.Stdin)
		if err != nil {
			return err
		}
		var args coglog.WriteArgs
		if err := json.Unmarshal(input, &args); err != nil {
			return fmt.Errorf("invalid JSON: %w", err)
		}
		entry, err := cl.Write(args)
		if err != nil {
			return err
		}
		fmt.Printf("metalog: turn %d written\n", entry.TurnID)

	case "clear":
		result := cl.Clear()
		if result.Cleared {
			fmt.Println("metalog: cleared")
		} else {
			fmt.Printf("metalog: %s\n", result.Reason)
		}

	default:
		printUsage()
		os.Exit(1)
	}

	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "metalog error: %v\n", err)
		os.Exit(1)
	}
}
