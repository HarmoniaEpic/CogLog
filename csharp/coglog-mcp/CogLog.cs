// CogLog v0.9.1 — Minimal cognitive continuity for LLMs.
// C# implementation using System.Text.Json (no external dependencies).

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Encodings.Web;

namespace CogLogNS
{
    public class CogLog
    {
        public const string Version = "0.9.1";
        public string DataDir { get; }
        public string CurrentFile { get; }

        public CogLog()
        {
            DataDir = DefaultCoglogDir();
            CurrentFile = Path.Combine(DataDir, "current.json");
        }

        private static string DefaultCoglogDir()
        {
            // 優先順位: COGLOG_DIR env > UserProfile/.coglog > ./.coglog（最終フォールバック）
            var env = Environment.GetEnvironmentVariable("COGLOG_DIR");
            if (!string.IsNullOrEmpty(env)) return env;
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                ".coglog");
        }

        public CogLog(string dataDir)
        {
            DataDir = dataDir;
            CurrentFile = Path.Combine(dataDir, "current.json");
        }

        // ═══════════════════════════════════════════════════════════════
        // Schema
        // ═══════════════════════════════════════════════════════════════

        public static JsonObject MakeSchema()
        {
            return new JsonObject
            {
                ["version"] = Version,
                ["fact_layer"] = new JsonObject
                {
                    ["user"] = "non-empty string required \u2014 user's original utterance",
                    ["thinking"] = "non-empty string required \u2014 AI's full thinking process",
                    ["assistant"] = "non-empty string required \u2014 AI's original output"
                },
                ["interpretation_layer"] = new JsonObject
                {
                    ["current_focus"] = "string required, empty OK \u2014 present: what am I working on?",
                    ["theory_of_mind"] = "string required, empty OK \u2014 other: what is the user's state?",
                    ["self_narrative"] = "string required, empty OK \u2014 self: who am I in this moment?",
                    ["annotation"] = "string required, empty OK \u2014 future: what should I do next?"
                },
                ["constraints"] = new JsonObject
                {
                    ["window_size"] = "1 turn (overwritten each write)",
                    ["interpretation_empty"] = "choosing not to write is itself a metacognitive act"
                }
            };
        }

        // ═══════════════════════════════════════════════════════════════
        // Validation
        // ═══════════════════════════════════════════════════════════════

        public static void Validate(Dictionary<string, string> args)
        {
            foreach (var key in new[] { "user", "thinking", "assistant" })
            {
                if (!args.TryGetValue(key, out var val) || string.IsNullOrEmpty(val))
                    throw new ArgumentException($"missing required field: {key}");
            }
            foreach (var key in new[] { "current_focus", "theory_of_mind", "self_narrative", "annotation" })
            {
                if (!args.ContainsKey(key) || args[key] == null)
                    throw new ArgumentException($"missing required field: {key} (empty string is acceptable)");
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Read / Write / Clear
        // ═══════════════════════════════════════════════════════════════

        private static readonly JsonSerializerOptions PrettyOptions = new()
        {
            WriteIndented = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            PropertyNamingPolicy = null
        };

        public JsonObject? Read()
        {
            if (!File.Exists(CurrentFile)) return null;
            var content = File.ReadAllText(CurrentFile, new UTF8Encoding(false));
            return JsonNode.Parse(content)?.AsObject();
        }

        public JsonObject Write(Dictionary<string, string> args)
        {
            Validate(args);
            Directory.CreateDirectory(DataDir);

            var prev = Read();
            int turnId = 1;
            if (prev != null && prev.TryGetPropertyValue("turn_id", out var tid))
                turnId = tid!.GetValue<int>() + 1;

            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ");

            var entry = new JsonObject
            {
                ["_schema"] = MakeSchema(),
                ["turn_id"] = turnId,
                ["timestamp"] = timestamp,
                ["layers"] = new JsonObject
                {
                    ["user"] = args["user"],
                    ["thinking"] = args["thinking"],
                    ["assistant"] = args["assistant"]
                },
                ["current_focus"] = args["current_focus"],
                ["theory_of_mind"] = args["theory_of_mind"],
                ["self_narrative"] = args["self_narrative"],
                ["annotation"] = args["annotation"]
            };

            var json = entry.ToJsonString(PrettyOptions) + "\n";
            File.WriteAllText(CurrentFile, json, new UTF8Encoding(false));
            return entry;
        }

        public JsonObject Clear()
        {
            if (File.Exists(CurrentFile))
            {
                File.Delete(CurrentFile);
                return new JsonObject { ["cleared"] = true };
            }
            return new JsonObject { ["cleared"] = false, ["reason"] = "no existing coglog" };
        }
    }
}
