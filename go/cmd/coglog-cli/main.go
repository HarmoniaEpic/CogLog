// CogLog CLI
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
  interpretation layer (current_focus, theory_of_mind,
    self_narrative, annotation): string required, empty string acceptable
`)
}

func run() error {
	// Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
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
			fmt.Println("(no coglog found)")
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
		args, err := coglog.ParseWriteArgs(input)
		if err != nil {
			return err
		}
		entry, err := cl.Write(args)
		if err != nil {
			return err
		}
		fmt.Printf("coglog: turn %d written\n", entry.TurnID)

	case "clear":
		result := cl.Clear()
		if result.Cleared {
			fmt.Println("coglog: cleared")
		} else {
			fmt.Printf("coglog: %s\n", result.Reason)
		}

	default:
		printUsage()
		os.Exit(1)
	}

	return nil
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "coglog error: %v\n", err)
		os.Exit(1)
	}
}
