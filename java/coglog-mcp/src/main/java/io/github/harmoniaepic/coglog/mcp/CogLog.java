package io.github.harmoniaepic.coglog.mcp;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * CogLog v0.9.1 — Minimal cognitive continuity for LLMs.
 *
 * <p>A single-window (size 1) log that holds the previous turn's three-layer
 * structure plus a four-axis interpretation layer.</p>
 */
public class CogLog {
    public static final String VERSION = "0.9.1";

    private final Path dataDir;
    private final Path currentFile;

    public CogLog() {
        this.dataDir = defaultCoglogDir();
        this.currentFile = dataDir.resolve("current.json");
    }

    private static Path defaultCoglogDir() {
        // 優先順位: COGLOG_DIR env > user.home/.coglog > ./.coglog（最終フォールバック）
        String env = System.getenv("COGLOG_DIR");
        if (env != null && !env.isEmpty()) return Path.of(env);
        return Path.of(System.getProperty("user.home", ".")).resolve(".coglog");
    }

    public CogLog(Path dataDir) {
        this.dataDir = dataDir;
        this.currentFile = dataDir.resolve("current.json");
    }

    // ═══════════════════════════════════════════════════════════════
    // Validation
    // ═══════════════════════════════════════════════════════════════

    public static void validate(Map<String, String> args) {
        for (String key : new String[]{"user", "thinking", "assistant"}) {
            String val = args.get(key);
            if (val == null || val.isEmpty()) {
                throw new IllegalArgumentException("missing required field: " + key);
            }
        }
        for (String key : new String[]{"current_focus", "theory_of_mind", "self_narrative", "annotation"}) {
            String val = args.get(key);
            if (val == null) {
                throw new IllegalArgumentException("missing required field: " + key + " (empty string is acceptable)");
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // Read / Write / Clear
    // ═══════════════════════════════════════════════════════════════

    public Map<String, Object> read() throws IOException {
        if (!Files.exists(currentFile)) {
            return null;
        }
        String content = Files.readString(currentFile, StandardCharsets.UTF_8);
        return parseJson(content);
    }

    public Map<String, Object> write(Map<String, String> args) throws IOException {
        validate(args);
        Files.createDirectories(dataDir);

        Map<String, Object> prev = read();
        int turnId = 1;
        if (prev != null) {
            turnId = ((Number) prev.get("turn_id")).intValue() + 1;
        }

        String timestamp = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'Z'")
                .withZone(ZoneOffset.UTC)
                .format(Instant.now());

        Map<String, Object> entry = new LinkedHashMap<>();
        entry.put("_schema", makeSchema());
        entry.put("turn_id", turnId);
        entry.put("timestamp", timestamp);

        Map<String, Object> layers = new LinkedHashMap<>();
        layers.put("user", args.get("user"));
        layers.put("thinking", args.get("thinking"));
        layers.put("assistant", args.get("assistant"));
        entry.put("layers", layers);

        entry.put("current_focus", args.get("current_focus"));
        entry.put("theory_of_mind", args.get("theory_of_mind"));
        entry.put("self_narrative", args.get("self_narrative"));
        entry.put("annotation", args.get("annotation"));

        String json = toJson(entry, 0) + "\n";
        Files.writeString(currentFile, json, StandardCharsets.UTF_8);

        return entry;
    }

    public Map<String, Object> clear() throws IOException {
        Map<String, Object> result = new LinkedHashMap<>();
        if (Files.exists(currentFile)) {
            Files.delete(currentFile);
            result.put("cleared", true);
        } else {
            result.put("cleared", false);
            result.put("reason", "no existing metalog");
        }
        return result;
    }

    // ═══════════════════════════════════════════════════════════════
    // Schema
    // ═══════════════════════════════════════════════════════════════

    @SuppressWarnings("unchecked")
    public static Map<String, Object> makeSchema() {
        Map<String, Object> schema = new LinkedHashMap<>();
        schema.put("version", VERSION);

        Map<String, Object> factLayer = new LinkedHashMap<>();
        factLayer.put("user", "non-empty string required \u2014 user's original utterance");
        factLayer.put("thinking", "non-empty string required \u2014 AI's full thinking process");
        factLayer.put("assistant", "non-empty string required \u2014 AI's original output");
        schema.put("fact_layer", factLayer);

        Map<String, Object> interpLayer = new LinkedHashMap<>();
        interpLayer.put("current_focus", "string required, empty OK \u2014 present: what am I working on?");
        interpLayer.put("theory_of_mind", "string required, empty OK \u2014 other: what is the user's state?");
        interpLayer.put("self_narrative", "string required, empty OK \u2014 self: who am I in this moment?");
        interpLayer.put("annotation", "string required, empty OK \u2014 future: what should I do next?");
        schema.put("interpretation_layer", interpLayer);

        Map<String, Object> constraints = new LinkedHashMap<>();
        constraints.put("window_size", "1 turn (overwritten each write)");
        constraints.put("interpretation_empty", "choosing not to write is itself a metacognitive act");
        schema.put("constraints", constraints);

        return schema;
    }

    // ═══════════════════════════════════════════════════════════════
    // JSON serialization (hand-written)
    // ═══════════════════════════════════════════════════════════════

    @SuppressWarnings("unchecked")
    public static String toJson(Object value, int depth) {
        if (value == null) return "null";
        if (value instanceof Boolean) return value.toString();
        if (value instanceof Number) return value.toString();
        if (value instanceof String) return jsonString((String) value);
        if (value instanceof Map) {
            Map<String, Object> map = (Map<String, Object>) value;
            StringBuilder sb = new StringBuilder();
            String indent = "  ".repeat(depth + 1);
            String outerIndent = "  ".repeat(depth);
            sb.append("{\n");
            int i = 0;
            for (Map.Entry<String, Object> e : map.entrySet()) {
                sb.append(indent).append(jsonString(e.getKey())).append(": ");
                sb.append(toJson(e.getValue(), depth + 1));
                if (++i < map.size()) sb.append(",");
                sb.append("\n");
            }
            sb.append(outerIndent).append("}");
            return sb.toString();
        }
        return "null";
    }

    public static String toCompactJson(Object value) {
        if (value == null) return "null";
        if (value instanceof Boolean) return value.toString();
        if (value instanceof Number) return value.toString();
        if (value instanceof String) return jsonString((String) value);
        if (value instanceof Map) {
            @SuppressWarnings("unchecked")
            Map<String, Object> map = (Map<String, Object>) value;
            StringBuilder sb = new StringBuilder("{");
            int i = 0;
            for (Map.Entry<String, Object> e : map.entrySet()) {
                if (i++ > 0) sb.append(",");
                sb.append(jsonString(e.getKey())).append(":").append(toCompactJson(e.getValue()));
            }
            sb.append("}");
            return sb.toString();
        }
        if (value instanceof List) {
            @SuppressWarnings("unchecked")
            List<Object> list = (List<Object>) value;
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < list.size(); i++) {
                if (i > 0) sb.append(",");
                sb.append(toCompactJson(list.get(i)));
            }
            sb.append("]");
            return sb.toString();
        }
        return "null";
    }

    private static String jsonString(String s) {
        StringBuilder sb = new StringBuilder("\"");
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
            }
        }
        sb.append("\"");
        return sb.toString();
    }

    // ═══════════════════════════════════════════════════════════════
    // JSON parsing (hand-written, recursive descent)
    // ═══════════════════════════════════════════════════════════════

    @SuppressWarnings("unchecked")
    public static Map<String, Object> parseJson(String src) {
        int[] pos = {0};
        Object result = parseValue(src, pos);
        if (result instanceof Map) {
            return (Map<String, Object>) result;
        }
        throw new RuntimeException("Expected JSON object at top level");
    }

    private static Object parseValue(String src, int[] pos) {
        skipWS(src, pos);
        if (pos[0] >= src.length()) throw new RuntimeException("Unexpected end of input");
        char c = src.charAt(pos[0]);
        if (c == '"') return parseString(src, pos);
        if (c == '{') return parseObject(src, pos);
        if (c == '[') return parseArray(src, pos);
        if (c == 't' || c == 'f') return parseBool(src, pos);
        if (c == 'n') { pos[0] += 4; return null; }
        if (c == '-' || Character.isDigit(c)) return parseNumber(src, pos);
        throw new RuntimeException("Unexpected char '" + c + "' at " + pos[0]);
    }

    private static String parseString(String src, int[] pos) {
        pos[0]++; // skip opening "
        StringBuilder sb = new StringBuilder();
        while (pos[0] < src.length()) {
            char c = src.charAt(pos[0]++);
            if (c == '"') return sb.toString();
            if (c == '\\') {
                char esc = src.charAt(pos[0]++);
                switch (esc) {
                    case '"': sb.append('"'); break;
                    case '\\': sb.append('\\'); break;
                    case '/': sb.append('/'); break;
                    case 'n': sb.append('\n'); break;
                    case 'r': sb.append('\r'); break;
                    case 't': sb.append('\t'); break;
                    case 'u':
                        String hex = src.substring(pos[0], pos[0] + 4);
                        pos[0] += 4;
                        sb.append((char) Integer.parseInt(hex, 16));
                        break;
                    default: sb.append(esc);
                }
            } else {
                sb.append(c);
            }
        }
        throw new RuntimeException("Unterminated string");
    }

    private static Map<String, Object> parseObject(String src, int[] pos) {
        pos[0]++; // skip {
        Map<String, Object> map = new LinkedHashMap<>();
        skipWS(src, pos);
        if (src.charAt(pos[0]) == '}') { pos[0]++; return map; }
        while (true) {
            skipWS(src, pos);
            String key = parseString(src, pos);
            skipWS(src, pos);
            expect(src, pos, ':');
            Object val = parseValue(src, pos);
            map.put(key, val);
            skipWS(src, pos);
            if (src.charAt(pos[0]) == ',') { pos[0]++; }
            else if (src.charAt(pos[0]) == '}') { pos[0]++; return map; }
            else throw new RuntimeException("Expected ',' or '}' at " + pos[0]);
        }
    }

    private static List<Object> parseArray(String src, int[] pos) {
        pos[0]++; // skip [
        List<Object> list = new ArrayList<>();
        skipWS(src, pos);
        if (src.charAt(pos[0]) == ']') { pos[0]++; return list; }
        while (true) {
            list.add(parseValue(src, pos));
            skipWS(src, pos);
            if (src.charAt(pos[0]) == ',') { pos[0]++; }
            else if (src.charAt(pos[0]) == ']') { pos[0]++; return list; }
            else throw new RuntimeException("Expected ',' or ']' at " + pos[0]);
        }
    }

    private static Number parseNumber(String src, int[] pos) {
        int start = pos[0];
        if (src.charAt(pos[0]) == '-') pos[0]++;
        while (pos[0] < src.length() && Character.isDigit(src.charAt(pos[0]))) pos[0]++;
        // Support decimal for parsing, but CogLog only uses integers
        if (pos[0] < src.length() && src.charAt(pos[0]) == '.') {
            pos[0]++;
            while (pos[0] < src.length() && Character.isDigit(src.charAt(pos[0]))) pos[0]++;
            return Double.parseDouble(src.substring(start, pos[0]));
        }
        return Integer.parseInt(src.substring(start, pos[0]));
    }

    private static Boolean parseBool(String src, int[] pos) {
        if (src.startsWith("true", pos[0])) { pos[0] += 4; return true; }
        if (src.startsWith("false", pos[0])) { pos[0] += 5; return false; }
        throw new RuntimeException("Expected boolean at " + pos[0]);
    }

    private static void skipWS(String src, int[] pos) {
        while (pos[0] < src.length() && Character.isWhitespace(src.charAt(pos[0]))) pos[0]++;
    }

    private static void expect(String src, int[] pos, char c) {
        skipWS(src, pos);
        if (src.charAt(pos[0]) != c) throw new RuntimeException("Expected '" + c + "' at " + pos[0]);
        pos[0]++;
    }
}
