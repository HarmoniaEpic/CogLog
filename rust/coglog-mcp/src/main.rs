//! CogLog MCP Server v0.9.1
//!
//! Exposes CogLog read/write/clear as MCP tools over stdio transport.
//!
//! Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
//! Transport: stdio (newline-delimited JSON)

use coglog_core::{CogLog, WriteArgs};
use serde_json::{json, Value};
use std::io::{self, BufRead, Write};

// ═══════════════════════════════════════════════════════════════════
// Tool definitions
// ═══════════════════════════════════════════════════════════════════

fn tool_definitions() -> Value {
    json!([
        {
            "name": "coglog_read",
            "description": "Read the previous turn's coglog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no coglog exists.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "additionalProperties": false
            }
        },
        {
            "name": "coglog_write",
            "description": "Write the current turn's coglog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings \u{2014} choosing not to write is itself a metacognitive act.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "user":            { "type": "string", "description": "User's original utterance (non-empty)" },
                    "thinking":        { "type": "string", "description": "AI's full thinking process (non-empty)" },
                    "assistant":       { "type": "string", "description": "AI's original output (non-empty)" },
                    "current_focus":   { "type": "string", "description": "Present direction: what am I working on?" },
                    "theory_of_mind":  { "type": "string", "description": "Other direction: what is the user's state?" },
                    "self_narrative":  { "type": "string", "description": "Self direction: who am I in this moment?" },
                    "annotation":      { "type": "string", "description": "Future direction: what should I do next?" }
                },
                "required": ["user", "thinking", "assistant", "current_focus", "theory_of_mind", "self_narrative", "annotation"],
                "additionalProperties": false
            }
        },
        {
            "name": "coglog_clear",
            "description": "Clear the coglog, removing the stored turn data. Returns whether the clear was successful.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "additionalProperties": false
            }
        }
    ])
}

// ═══════════════════════════════════════════════════════════════════
// JSON-RPC helpers
// ═══════════════════════════════════════════════════════════════════

fn send(obj: &Value) {
    let out = io::stdout();
    let mut out = out.lock();
    let _ = serde_json::to_writer(&mut out, obj);
    let _ = out.write_all(b"\n");
    let _ = out.flush();
}

fn send_result(id: &Value, result: Value) {
    send(&json!({
        "jsonrpc": "2.0",
        "id": id,
        "result": result
    }));
}

fn send_error(id: &Value, code: i32, message: &str) {
    send(&json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": message }
    }));
}

fn send_tool_result(id: &Value, text: &str, is_error: bool) {
    let mut result = json!({
        "content": [{ "type": "text", "text": text }]
    });
    if is_error {
        result["isError"] = json!(true);
    }
    send_result(id, result);
}

fn log(msg: &str) {
    eprintln!("coglog-mcp: {}", msg);
}

// ═══════════════════════════════════════════════════════════════════
// MCP handlers
// ═══════════════════════════════════════════════════════════════════

fn handle_initialize(id: &Value) {
    send_result(
        id,
        json!({
            "protocolVersion": "2024-11-05",
            "capabilities": { "tools": {} },
            "serverInfo": { "name": "coglog", "version": "0.9.1" }
        }),
    );
}

fn handle_tools_list(id: &Value) {
    send_result(id, json!({ "tools": tool_definitions() }));
}

fn handle_tools_call(id: &Value, params: &Value, ml: &CogLog) {
    let name = params["name"].as_str().unwrap_or("");
    let args = &params["arguments"];

    match name {
        "coglog_read" => match ml.read() {
            Ok(Some(entry)) => {
                let text = serde_json::to_string_pretty(&entry).unwrap_or_default();
                send_tool_result(id, &text, false);
            }
            Ok(None) => {
                send_tool_result(id, "(no coglog found)", false);
            }
            Err(e) => {
                send_tool_result(id, &format!("Error: {}", e), true);
            }
        },
        "coglog_write" => {
            let write_args: Result<WriteArgs, _> = serde_json::from_value(args.clone());
            match write_args {
                Ok(wa) => match ml.write(wa) {
                    Ok(entry) => {
                        let text = serde_json::to_string_pretty(&entry).unwrap_or_default();
                        send_tool_result(id, &text, false);
                    }
                    Err(e) => {
                        send_tool_result(id, &format!("Error: {}", e), true);
                    }
                },
                Err(e) => {
                    send_tool_result(id, &format!("Error: {}", e), true);
                }
            }
        }
        "coglog_clear" => match ml.clear() {
            Ok(result) => {
                let text = serde_json::to_string(&result).unwrap_or_default();
                send_tool_result(id, &text, false);
            }
            Err(e) => {
                send_tool_result(id, &format!("Error: {}", e), true);
            }
        },
        _ => {
            send_tool_result(id, &format!("Error: unknown tool: {}", name), true);
        }
    }
}

fn handle_ping(id: &Value) {
    send_result(id, json!({}));
}

// ═══════════════════════════════════════════════════════════════════
// Main loop
// ═══════════════════════════════════════════════════════════════════

fn main() {
    // Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
    let argv: Vec<String> = std::env::args().collect();
    let ml = if argv.len() >= 3 && argv[1] == "--coglog-dir" {
        CogLog::with_dir(std::path::PathBuf::from(&argv[2]))
    } else {
        CogLog::new()
    };
    log("server started");

    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };
        let line = line.trim().to_string();
        if line.is_empty() {
            continue;
        }

        let msg: Value = match serde_json::from_str(&line) {
            Ok(v) => v,
            Err(e) => {
                send_error(&Value::Null, -32700, &format!("Parse error: {}", e));
                continue;
            }
        };

        let method = msg.get("method").and_then(|v| v.as_str());
        let id = msg.get("id");

        // Notification (no id) — never respond
        match id {
            None | Some(&Value::Null) => {
                if method == Some("notifications/initialized") {
                    log("initialized");
                }
                continue;
            }
            _ => {}
        }

        let id = id.unwrap(); // safe: checked above

        // Request (has id) — must respond
        match method {
            Some("initialize") => handle_initialize(id),
            Some("tools/list") => handle_tools_list(id),
            Some("tools/call") => {
                let params = msg.get("params").cloned().unwrap_or(json!({}));
                handle_tools_call(id, &params, &ml);
            }
            Some("ping") => handle_ping(id),
            Some(m) => send_error(id, -32601, &format!("Method not found: {}", m)),
            None => send_error(id, -32600, "Invalid Request: missing method"),
        }
    }

    log("server stopped");
}
