package io.github.harmoniaepic.coglog.mcp;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * CogLog MCP Server v0.9.1
 *
 * Exposes CogLog read/write/clear as MCP tools over stdio transport.
 * Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
 */
public class McpServer {

    private static CogLog cl = new CogLog();

    private static void send(String json) {
        System.out.println(json);
        System.out.flush();
    }

    private static void sendResult(Object id, String resultJson) {
        send("{\"jsonrpc\":\"2.0\",\"id\":" + formatId(id) + ",\"result\":" + resultJson + "}");
    }

    private static void sendError(Object id, int code, String message) {
        send("{\"jsonrpc\":\"2.0\",\"id\":" + formatId(id) + ",\"error\":{\"code\":" + code
                + ",\"message\":" + CogLog.toCompactJson(message) + "}}");
    }

    private static void sendToolResult(Object id, String text, boolean isError) {
        String errField = isError ? ",\"isError\":true" : "";
        sendResult(id, "{\"content\":[{\"type\":\"text\",\"text\":" + CogLog.toCompactJson(text) + "}]" + errField + "}");
    }

    private static void log(String msg) {
        System.err.println("coglog-mcp: " + msg);
        System.err.flush();
    }

    private static String formatId(Object id) {
        if (id == null) return "null";
        if (id instanceof Number) return id.toString();
        return CogLog.toCompactJson(id);
    }

    private static final String TOOLS_JSON = "["
        + "{\"name\":\"coglog_read\",\"description\":\"Read the previous turn's coglog.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},"
        + "{\"name\":\"coglog_write\",\"description\":\"Write the current turn's coglog.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"user\":{\"type\":\"string\"},\"thinking\":{\"type\":\"string\"},\"assistant\":{\"type\":\"string\"},\"current_focus\":{\"type\":\"string\"},\"theory_of_mind\":{\"type\":\"string\"},\"self_narrative\":{\"type\":\"string\"},\"annotation\":{\"type\":\"string\"}},\"required\":[\"user\",\"thinking\",\"assistant\",\"current_focus\",\"theory_of_mind\",\"self_narrative\",\"annotation\"],\"additionalProperties\":false}},"
        + "{\"name\":\"coglog_clear\",\"description\":\"Clear the coglog.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}}"
        + "]";

    @SuppressWarnings("unchecked")
    private static void handleToolsCall(Object id, Map<String, Object> params) {
        String name = (String) params.get("name");
        Map<String, Object> args = params.containsKey("arguments")
                ? (Map<String, Object>) params.get("arguments") : Map.of();
        try {
            if ("coglog_read".equals(name)) {
                Map<String, Object> entry = cl.read();
                if (entry == null) sendToolResult(id, "(no coglog found)", false);
                else sendToolResult(id, CogLog.toJson(entry, 0), false);
            } else if ("coglog_write".equals(name)) {
                Map<String, String> wa = new LinkedHashMap<>();
                for (String key : new String[]{"user", "thinking", "assistant",
                        "current_focus", "theory_of_mind", "self_narrative", "annotation"}) {
                    Object val = args.get(key);
                    wa.put(key, val != null ? val.toString() : null);
                }
                Map<String, Object> entry = cl.write(wa);
                sendToolResult(id, CogLog.toJson(entry, 0), false);
            } else if ("coglog_clear".equals(name)) {
                Map<String, Object> result = cl.clear();
                sendToolResult(id, CogLog.toCompactJson(result), false);
            } else {
                sendToolResult(id, "Error: unknown tool: " + name, true);
            }
        } catch (Exception e) {
            sendToolResult(id, "Error: " + e.getMessage(), true);
        }
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) {
        // --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
        if (args.length >= 2 && args[0].equals("--coglog-dir")) {
            cl = new CogLog(java.nio.file.Path.of(args[1]));
        }
        @SuppressWarnings("unused") String[] argsUnused = args;
        log("server started");
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                Map<String, Object> msg;
                try {
                    msg = CogLog.parseJson(line);
                } catch (Exception e) {
                    sendError(null, -32700, "Parse error: " + e.getMessage());
                    continue;
                }
                String method = (String) msg.get("method");
                Object id = msg.get("id");
                Map<String, Object> params = msg.containsKey("params")
                        ? (Map<String, Object>) msg.get("params") : Map.of();
                if (!msg.containsKey("id") || id == null) {
                    if ("notifications/initialized".equals(method)) log("initialized");
                    continue;
                }
                if ("initialize".equals(method)) {
                    sendResult(id, "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"coglog\",\"version\":\"0.9.1\"}}");
                } else if ("tools/list".equals(method)) {
                    sendResult(id, "{\"tools\":" + TOOLS_JSON + "}");
                } else if ("tools/call".equals(method)) {
                    handleToolsCall(id, params);
                } else if ("ping".equals(method)) {
                    sendResult(id, "{}");
                } else {
                    sendError(id, -32601, "Method not found: " + method);
                }
            }
        } catch (IOException e) {
            log("fatal: " + e.getMessage());
            System.exit(1);
        }
        log("server stopped");
    }
}
