// CogLog MCP Server v0.9.1
//
// Exposes CogLog read/write/clear as MCP tools over stdio transport.
//
// Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
// Transport: stdio (newline-delimited JSON)
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Encodings.Web;
using CogLogNS;

// ═══════════════════════════════════════════════════════════════════
// Setup
// ═══════════════════════════════════════════════════════════════════

// --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
CogLog cl = args.Length >= 2 && args[0] == "--coglog-dir"
    ? new CogLog(args[1])
    : new CogLog();
var jsonOpts = new JsonSerializerOptions
{
    Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
};

// ═══════════════════════════════════════════════════════════════════
// JSON-RPC helpers
// ═══════════════════════════════════════════════════════════════════

void Send(JsonObject obj)
{
    Console.WriteLine(obj.ToJsonString(jsonOpts));
}

void SendResult(JsonNode? id, JsonNode result)
{
    var resp = new JsonObject
    {
        ["jsonrpc"] = "2.0",
        ["id"] = id?.DeepClone(),
        ["result"] = result
    };
    Send(resp);
}

void SendError(JsonNode? id, int code, string message)
{
    var resp = new JsonObject
    {
        ["jsonrpc"] = "2.0",
        ["id"] = id?.DeepClone(),
        ["error"] = new JsonObject
        {
            ["code"] = code,
            ["message"] = message
        }
    };
    Send(resp);
}

void SendToolResult(JsonNode? id, string text, bool isError = false)
{
    var result = new JsonObject
    {
        ["content"] = new JsonArray
        {
            new JsonObject
            {
                ["type"] = "text",
                ["text"] = text
            }
        }
    };
    if (isError)
        result["isError"] = true;
    SendResult(id, result);
}

void Log(string msg)
{
    Console.Error.WriteLine($"metalog-mcp: {msg}");
}

// ═══════════════════════════════════════════════════════════════════
// Tool definitions
// ═══════════════════════════════════════════════════════════════════

JsonNode ToolDefinitions()
{
    return JsonNode.Parse("""
    [
      {
        "name": "metalog_read",
        "description": "Read the previous turn's metalog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no metalog exists.",
        "inputSchema": {
          "type": "object",
          "properties": {},
          "additionalProperties": false
        }
      },
      {
        "name": "metalog_write",
        "description": "Write the current turn's metalog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings — choosing not to write is itself a metacognitive act.",
        "inputSchema": {
          "type": "object",
          "properties": {
            "user":            {"type": "string", "description": "User's original utterance (non-empty)"},
            "thinking":        {"type": "string", "description": "AI's full thinking process (non-empty)"},
            "assistant":       {"type": "string", "description": "AI's original output (non-empty)"},
            "current_focus":   {"type": "string", "description": "Present direction: what am I working on?"},
            "theory_of_mind":  {"type": "string", "description": "Other direction: what is the user's state?"},
            "self_narrative":  {"type": "string", "description": "Self direction: who am I in this moment?"},
            "annotation":      {"type": "string", "description": "Future direction: what should I do next?"}
          },
          "required": ["user","thinking","assistant","current_focus","theory_of_mind","self_narrative","annotation"],
          "additionalProperties": false
        }
      },
      {
        "name": "metalog_clear",
        "description": "Clear the metalog, removing the stored turn data. Returns whether the clear was successful.",
        "inputSchema": {
          "type": "object",
          "properties": {},
          "additionalProperties": false
        }
      }
    ]
    """)!;
}

// ═══════════════════════════════════════════════════════════════════
// MCP handlers
// ═══════════════════════════════════════════════════════════════════

void HandleInitialize(JsonNode? id)
{
    var result = new JsonObject
    {
        ["protocolVersion"] = "2024-11-05",
        ["capabilities"] = new JsonObject
        {
            ["tools"] = new JsonObject()
        },
        ["serverInfo"] = new JsonObject
        {
            ["name"] = "metalog",
            ["version"] = "0.9.1"
        }
    };
    SendResult(id, result);
}

void HandleToolsList(JsonNode? id)
{
    var result = new JsonObject
    {
        ["tools"] = ToolDefinitions()
    };
    SendResult(id, result);
}

void HandleToolsCall(JsonNode? id, JsonObject? prms)
{
    if (prms == null)
    {
        SendToolResult(id, "Error: missing params", true);
        return;
    }

    var toolName = prms["name"]?.GetValue<string>() ?? "";
    var arguments = prms["arguments"]?.AsObject();

    try
    {
        switch (toolName)
        {
            case "metalog_read":
            {
                var entry = cl.Read();
                if (entry == null)
                    SendToolResult(id, "(no metalog found)");
                else
                    SendToolResult(id, entry.ToJsonString(new JsonSerializerOptions
                    {
                        WriteIndented = true,
                        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                    }));
                break;
            }
            case "metalog_write":
            {
                if (arguments == null)
                {
                    SendToolResult(id, "Error: missing arguments", true);
                    return;
                }
                var writeArgs = new Dictionary<string, string>();
                foreach (var key in new[] { "user", "thinking", "assistant",
                    "current_focus", "theory_of_mind", "self_narrative", "annotation" })
                {
                    writeArgs[key] = arguments[key]?.GetValue<string>() ?? "";
                }
                var written = cl.Write(writeArgs);
                SendToolResult(id, $"metalog: turn {written["turn_id"]} written");
                break;
            }
            case "metalog_clear":
            {
                var result = cl.Clear();
                if (result["cleared"]!.GetValue<bool>())
                    SendToolResult(id, "metalog: cleared");
                else
                    SendToolResult(id, $"metalog: {result["reason"]}");
                break;
            }
            default:
                SendToolResult(id, $"Error: unknown tool '{toolName}'", true);
                break;
        }
    }
    catch (ArgumentException e)
    {
        SendToolResult(id, $"Error: {e.Message}", true);
    }
    catch (Exception e)
    {
        SendToolResult(id, $"Error: {e.Message}", true);
    }
}

// ═══════════════════════════════════════════════════════════════════
// Main loop — read JSON-RPC messages from stdin
// ═══════════════════════════════════════════════════════════════════

Log("starting on stdio");

string? line;
while ((line = Console.ReadLine()) != null)
{
    line = line.Trim();
    if (string.IsNullOrEmpty(line))
        continue;

    JsonObject? msg;
    try
    {
        msg = JsonNode.Parse(line)?.AsObject();
    }
    catch
    {
        Log($"parse error: {(line.Length > 80 ? line[..80] + "..." : line)}");
        continue;
    }

    if (msg == null) continue;

    var method = msg["method"]?.GetValue<string>() ?? "";
    var id = msg["id"];
    var prms = msg["params"]?.AsObject();

    switch (method)
    {
        case "initialize":
            HandleInitialize(id);
            break;
        case "initialized":
        case "notifications/initialized":
            // acknowledgement — no response needed
            break;
        case "tools/list":
            HandleToolsList(id);
            break;
        case "tools/call":
            HandleToolsCall(id, prms);
            break;
        default:
            if (id != null)
                SendError(id, -32601, $"Method not found: {method}");
            break;
    }
}

Log("stdin closed, exiting");
