// CogLog MCP Server v0.9.1
//
// Exposes CogLog read/write/clear as MCP tools over stdio transport.
//
// Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
// Transport: stdio (newline-delimited JSON)
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	coglog "github.com/HarmoniaEpic/coglog/go"
)

// ═══════════════════════════════════════════════════════════════════
// JSON-RPC types
// ═══════════════════════════════════════════════════════════════════

type rpcMessage struct {
	JSONRPC string           `json:"jsonrpc"`
	ID      *json.RawMessage `json:"id,omitempty"`
	Method  string           `json:"method,omitempty"`
	Params  json.RawMessage  `json:"params,omitempty"`
}

type toolsCallParams struct {
	Name      string          `json:"name"`
	Arguments json.RawMessage `json:"arguments"`
}

// ═══════════════════════════════════════════════════════════════════
// JSON-RPC helpers
// ═══════════════════════════════════════════════════════════════════

func send(v interface{}) {
	data, _ := json.Marshal(v)
	fmt.Println(string(data))
}

func sendResult(id *json.RawMessage, result interface{}) {
	send(map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"result":  result,
	})
}

func sendError(id *json.RawMessage, code int, message string) {
	send(map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      id,
		"error": map[string]interface{}{
			"code":    code,
			"message": message,
		},
	})
}

func sendToolResult(id *json.RawMessage, text string, isError bool) {
	result := map[string]interface{}{
		"content": []map[string]string{
			{"type": "text", "text": text},
		},
	}
	if isError {
		result["isError"] = true
	}
	sendResult(id, result)
}

func log(msg string) {
	fmt.Fprintf(os.Stderr, "coglog-mcp: %s\n", msg)
}

// ═══════════════════════════════════════════════════════════════════
// Tool definitions
// ═══════════════════════════════════════════════════════════════════

var toolDefinitions = []map[string]interface{}{
	{
		"name":        "coglog_read",
		"description": "Read the previous turn's coglog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no coglog exists.",
		"inputSchema": map[string]interface{}{
			"type":                 "object",
			"properties":           map[string]interface{}{},
			"additionalProperties": false,
		},
	},
	{
		"name":        "coglog_write",
		"description": "Write the current turn's coglog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings \u2014 choosing not to write is itself a metacognitive act.",
		"inputSchema": map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"user":            map[string]string{"type": "string", "description": "User's original utterance (non-empty)"},
				"thinking":        map[string]string{"type": "string", "description": "AI's full thinking process (non-empty)"},
				"assistant":       map[string]string{"type": "string", "description": "AI's original output (non-empty)"},
				"current_focus":   map[string]string{"type": "string", "description": "Present direction: what am I working on?"},
				"theory_of_mind":  map[string]string{"type": "string", "description": "Other direction: what is the user's state?"},
				"self_narrative":  map[string]string{"type": "string", "description": "Self direction: who am I in this moment?"},
				"annotation":      map[string]string{"type": "string", "description": "Future direction: what should I do next?"},
			},
			"required":             []string{"user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"},
			"additionalProperties": false,
		},
	},
	{
		"name":        "coglog_clear",
		"description": "Clear the coglog, removing the stored turn data. Returns whether the clear was successful.",
		"inputSchema": map[string]interface{}{
			"type":                 "object",
			"properties":           map[string]interface{}{},
			"additionalProperties": false,
		},
	},
}

// ═══════════════════════════════════════════════════════════════════
// MCP handlers
// ═══════════════════════════════════════════════════════════════════

func handleInitialize(id *json.RawMessage) {
	sendResult(id, map[string]interface{}{
		"protocolVersion": "2024-11-05",
		"capabilities":    map[string]interface{}{"tools": map[string]interface{}{}},
		"serverInfo":      map[string]interface{}{"name": "coglog", "version": "0.9.1"},
	})
}

func handleToolsList(id *json.RawMessage) {
	sendResult(id, map[string]interface{}{"tools": toolDefinitions})
}

func handleToolsCall(id *json.RawMessage, params json.RawMessage, cl *coglog.CogLog) {
	var p toolsCallParams
	if err := json.Unmarshal(params, &p); err != nil {
		sendToolResult(id, fmt.Sprintf("Error: %v", err), true)
		return
	}

	switch p.Name {
	case "coglog_read":
		entry, err := cl.Read()
		if err != nil {
			sendToolResult(id, fmt.Sprintf("Error: %v", err), true)
			return
		}
		if entry == nil {
			sendToolResult(id, "(no coglog found)", false)
			return
		}
		data, _ := json.MarshalIndent(entry, "", "  ")
		sendToolResult(id, string(data), false)

	case "coglog_write":
		var args coglog.WriteArgs
		if err := json.Unmarshal(p.Arguments, &args); err != nil {
			sendToolResult(id, fmt.Sprintf("Error: %v", err), true)
			return
		}
		entry, err := cl.Write(args)
		if err != nil {
			sendToolResult(id, fmt.Sprintf("Error: %v", err), true)
			return
		}
		data, _ := json.MarshalIndent(entry, "", "  ")
		sendToolResult(id, string(data), false)

	case "coglog_clear":
		result := cl.Clear()
		data, _ := json.Marshal(result)
		sendToolResult(id, string(data), false)

	default:
		sendToolResult(id, fmt.Sprintf("Error: unknown tool: %s", p.Name), true)
	}
}

func handlePing(id *json.RawMessage) {
	sendResult(id, map[string]interface{}{})
}

// ═══════════════════════════════════════════════════════════════════
// Main loop
// ═══════════════════════════════════════════════════════════════════

func main() {
	// --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
	var cl *coglog.CogLog
	if len(os.Args) >= 3 && os.Args[1] == "--coglog-dir" {
		cl = coglog.NewWithDir(os.Args[2])
	} else {
		cl = coglog.New()
	}
	log("server started")

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var msg rpcMessage
		if err := json.Unmarshal([]byte(line), &msg); err != nil {
			sendError(nil, -32700, fmt.Sprintf("Parse error: %v", err))
			continue
		}

		// Notification (no id) — never respond
		if msg.ID == nil {
			if msg.Method == "notifications/initialized" {
				log("initialized")
			}
			continue
		}

		// Check for null id
		if string(*msg.ID) == "null" {
			if msg.Method == "notifications/initialized" {
				log("initialized")
			}
			continue
		}

		// Request (has id) — must respond
		switch msg.Method {
		case "initialize":
			handleInitialize(msg.ID)
		case "tools/list":
			handleToolsList(msg.ID)
		case "tools/call":
			handleToolsCall(msg.ID, msg.Params, cl)
		case "ping":
			handlePing(msg.ID)
		default:
			sendError(msg.ID, -32601, fmt.Sprintf("Method not found: %s", msg.Method))
		}
	}

	log("server stopped")
}
