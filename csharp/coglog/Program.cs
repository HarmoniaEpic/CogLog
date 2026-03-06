// CogLog CLI v0.9.1
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Encodings.Web;
using CogLogNS;

var prettyOptions = new JsonSerializerOptions
{
    WriteIndented = true,
    Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
};

// --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
var cmdArgs = args;
CogLog cl;
if (cmdArgs.Length >= 2 && cmdArgs[0] == "--coglog-dir")
{
    cl = new CogLog(cmdArgs[1]);
    cmdArgs = cmdArgs[2..];
}
else
{
    cl = new CogLog();
}

if (cmdArgs.Length < 1)
{
    PrintUsage();
    return;
}

try
{
    switch (cmdArgs[0])
    {
        case "read":
            var entry = cl.Read();
            if (entry == null)
                Console.WriteLine("(no coglog found)");
            else
                Console.WriteLine(entry.ToJsonString(prettyOptions));
            break;

        case "write":
            var input = Console.In.ReadToEnd();
            var data = JsonNode.Parse(input)!.AsObject();
            var writeArgs = new Dictionary<string, string>();
            foreach (var key in new[] { "user", "thinking", "assistant",
                "current_focus", "theory_of_mind", "self_narrative", "annotation" })
            {
                writeArgs[key] = data[key]?.GetValue<string>() ?? "";
            }
            var written = cl.Write(writeArgs);
            Console.WriteLine($"coglog: turn {written["turn_id"]} written");
            break;

        case "clear":
            var result = cl.Clear();
            if (result["cleared"]!.GetValue<bool>())
                Console.WriteLine("coglog: cleared");
            else
                Console.WriteLine($"coglog: {result["reason"]}");
            break;

        default:
            PrintUsage();
            Environment.Exit(1);
            break;
    }
}
catch (ArgumentException e)
{
    Console.Error.WriteLine($"coglog error: {e.Message}");
    Environment.Exit(1);
}
catch (Exception e)
{
    Console.Error.WriteLine($"coglog error: {e.Message}");
    Environment.Exit(1);
}

static void PrintUsage()
{
    Console.Write("""
        usage: coglog-cli <read|write|clear>

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

        """);
}
