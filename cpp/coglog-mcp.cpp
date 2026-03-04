/*
 * CogLog MCP Server v0.9.1 — Minimal cognitive continuity for LLMs (C++)
 *
 * Exposes MetaLog read/write/clear as MCP tools over stdio transport.
 * Single-file, zero external dependencies. Contains a complete copy of
 * the MetaLog core and mini JSON library for standalone operation.
 *
 * Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
 * Transport: stdio (newline-delimited JSON)
 *
 * Build with cosmocc for universal binary:
 *   cosmocc -std=c++17 -Os -mtiny -fno-exceptions -fno-rtti \
 *           -o coglog-mcp coglog-mcp.cpp
 *
 * License: MIT
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <cmath>
#include <string>
#include <vector>
#include <utility>
#include <stdexcept>
#include <sys/stat.h>
#include <pwd.h>
#include <unistd.h>
#include <unistd.h>

// ═══════════════════════════════════════════════════════════════════
// Mini JSON library (shared with coglog-cli.cpp)
// ═══════════════════════════════════════════════════════════════════

namespace json {

enum Type { Null, Bool, Number, String, Array, Object };

class Value {
public:
    using Pair = std::pair<std::string, Value>;
    using ObjectData = std::vector<Pair>;
    using ArrayData = std::vector<Value>;

private:
    Type type_ = Null;
    bool bool_ = false;
    double num_ = 0;
    std::string str_;
    ArrayData arr_;
    ObjectData obj_;

public:
    Value() : type_(Null) {}
    Value(std::nullptr_t) : type_(Null) {}
    Value(bool b) : type_(Bool), bool_(b) {}
    Value(int n) : type_(Number), num_(n) {}
    Value(double n) : type_(Number), num_(n) {}
    Value(const char* s) : type_(String), str_(s) {}
    Value(std::string s) : type_(String), str_(std::move(s)) {}

    static Value object() { Value v; v.type_ = Object; return v; }
    static Value array() { Value v; v.type_ = Array; return v; }

    Type type() const { return type_; }
    bool is_null() const { return type_ == Null; }
    bool is_string() const { return type_ == String; }
    bool is_number() const { return type_ == Number; }
    bool is_bool() const { return type_ == Bool; }
    bool is_array() const { return type_ == Array; }
    bool is_object() const { return type_ == Object; }

    const std::string& str() const { return str_; }
    double num() const { return num_; }
    int to_int() const { return static_cast<int>(num_); }
    bool to_bool() const { return bool_; }
    const ArrayData& arr() const { return arr_; }
    const ObjectData& obj() const { return obj_; }

    bool has(const std::string& key) const {
        for (auto& [k, v] : obj_) if (k == key) return true;
        return false;
    }

    const Value& get(const std::string& key) const {
        for (auto& [k, v] : obj_) if (k == key) return v;
        static const Value null_val;
        return null_val;
    }

    std::string get_str(const std::string& key) const {
        auto& v = get(key);
        return v.is_string() ? v.str() : "";
    }

    void set(std::string key, Value val) {
        for (auto& [k, v] : obj_) {
            if (k == key) { v = std::move(val); return; }
        }
        obj_.emplace_back(std::move(key), std::move(val));
    }

    void push(Value val) { arr_.push_back(std::move(val)); }

    // ── Serialization ──

    static std::string escape(const std::string& s) {
        std::string out;
        out.reserve(s.size() + 2);
        out += '"';
        for (unsigned char c : s) {
            switch (c) {
                case '"':  out += "\\\""; break;
                case '\\': out += "\\\\"; break;
                case '\b': out += "\\b";  break;
                case '\f': out += "\\f";  break;
                case '\n': out += "\\n";  break;
                case '\r': out += "\\r";  break;
                case '\t': out += "\\t";  break;
                default:
                    if (c < 0x20) {
                        char buf[8];
                        std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                        out += buf;
                    } else {
                        out += static_cast<char>(c);
                    }
            }
        }
        out += '"';
        return out;
    }

    void dump_to(std::string& out, int indent, int depth) const {
        std::string pad(indent >= 0 ? (depth * indent) : 0, ' ');
        std::string pad_inner(indent >= 0 ? ((depth + 1) * indent) : 0, ' ');
        std::string nl = indent >= 0 ? "\n" : "";
        std::string sep = indent >= 0 ? ": " : ":";

        switch (type_) {
            case Null:   out += "null"; break;
            case Bool:   out += bool_ ? "true" : "false"; break;
            case Number: {
                double intpart;
                if (std::modf(num_, &intpart) == 0.0 &&
                    num_ >= -1e15 && num_ <= 1e15) {
                    char buf[32];
                    std::snprintf(buf, sizeof(buf), "%lld",
                                  static_cast<long long>(num_));
                    out += buf;
                } else {
                    char buf[32];
                    std::snprintf(buf, sizeof(buf), "%g", num_);
                    out += buf;
                }
                break;
            }
            case String: out += escape(str_); break;
            case Array:
                if (arr_.empty()) { out += "[]"; break; }
                out += "["; out += nl;
                for (size_t i = 0; i < arr_.size(); ++i) {
                    out += pad_inner;
                    arr_[i].dump_to(out, indent, depth + 1);
                    if (i + 1 < arr_.size()) out += ",";
                    out += nl;
                }
                out += pad; out += "]";
                break;
            case Object:
                if (obj_.empty()) { out += "{}"; break; }
                out += "{"; out += nl;
                for (size_t i = 0; i < obj_.size(); ++i) {
                    out += pad_inner;
                    out += escape(obj_[i].first);
                    out += sep;
                    obj_[i].second.dump_to(out, indent, depth + 1);
                    if (i + 1 < obj_.size()) out += ",";
                    out += nl;
                }
                out += pad; out += "}";
                break;
        }
    }

    std::string dump(int indent = -1) const {
        std::string out;
        dump_to(out, indent, 0);
        return out;
    }

    // ── Parsing ──

    struct Parser {
        const char* s;
        size_t pos;
        size_t len;

        Parser(const std::string& input)
            : s(input.c_str()), pos(0), len(input.size()) {}

        void skip_ws() {
            while (pos < len && (s[pos] == ' ' || s[pos] == '\t' ||
                                  s[pos] == '\n' || s[pos] == '\r'))
                ++pos;
        }

        char peek() {
            skip_ws();
            if (pos >= len) throw std::runtime_error("unexpected end of input");
            return s[pos];
        }

        char next() {
            skip_ws();
            if (pos >= len) throw std::runtime_error("unexpected end of input");
            return s[pos++];
        }

        void expect(char c) {
            char got = next();
            if (got != c) {
                std::string msg = "expected '";
                msg += c; msg += "', got '"; msg += got; msg += "'";
                throw std::runtime_error(msg);
            }
        }

        std::string parse_string_value() {
            expect('"');
            std::string out;
            while (pos < len) {
                char c = s[pos++];
                if (c == '"') return out;
                if (c == '\\') {
                    if (pos >= len) throw std::runtime_error("unterminated escape");
                    char e = s[pos++];
                    switch (e) {
                        case '"':  out += '"';  break;
                        case '\\': out += '\\'; break;
                        case '/':  out += '/';  break;
                        case 'b':  out += '\b'; break;
                        case 'f':  out += '\f'; break;
                        case 'n':  out += '\n'; break;
                        case 'r':  out += '\r'; break;
                        case 't':  out += '\t'; break;
                        case 'u': {
                            if (pos + 4 > len)
                                throw std::runtime_error("incomplete \\u escape");
                            char hex[5] = {};
                            std::memcpy(hex, s + pos, 4);
                            pos += 4;
                            unsigned cp = std::strtoul(hex, nullptr, 16);
                            if (cp < 0x80) {
                                out += static_cast<char>(cp);
                            } else if (cp < 0x800) {
                                out += static_cast<char>(0xC0 | (cp >> 6));
                                out += static_cast<char>(0x80 | (cp & 0x3F));
                            } else {
                                out += static_cast<char>(0xE0 | (cp >> 12));
                                out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
                                out += static_cast<char>(0x80 | (cp & 0x3F));
                            }
                            break;
                        }
                        default:
                            out += '\\'; out += e; break;
                    }
                } else {
                    out += c;
                }
            }
            throw std::runtime_error("unterminated string");
        }

        Value parse_number() {
            size_t start = pos;
            if (s[pos] == '-') ++pos;
            while (pos < len && s[pos] >= '0' && s[pos] <= '9') ++pos;
            if (pos < len && s[pos] == '.') {
                ++pos;
                while (pos < len && s[pos] >= '0' && s[pos] <= '9') ++pos;
            }
            if (pos < len && (s[pos] == 'e' || s[pos] == 'E')) {
                ++pos;
                if (pos < len && (s[pos] == '+' || s[pos] == '-')) ++pos;
                while (pos < len && s[pos] >= '0' && s[pos] <= '9') ++pos;
            }
            std::string num_str(s + start, pos - start);
            return Value(std::stod(num_str));
        }

        bool match(const char* lit) {
            size_t n = std::strlen(lit);
            if (pos + n > len) return false;
            if (std::memcmp(s + pos, lit, n) == 0) { pos += n; return true; }
            return false;
        }

        Value parse_value() {
            char c = peek();
            if (c == '"') return Value(parse_string_value());
            if (c == '{') return parse_object();
            if (c == '[') return parse_array();
            if (c == '-' || (c >= '0' && c <= '9')) return parse_number();
            if (match("true"))  return Value(true);
            if (match("false")) return Value(false);
            if (match("null"))  return Value(nullptr);
            std::string msg = "unexpected character: '";
            msg += c; msg += "'";
            throw std::runtime_error(msg);
        }

        Value parse_object() {
            expect('{');
            Value obj = Value::object();
            if (peek() == '}') { ++pos; return obj; }
            while (true) {
                std::string key = parse_string_value();
                expect(':');
                Value val = parse_value();
                obj.set(std::move(key), std::move(val));
                char c = next();
                if (c == '}') break;
                if (c != ',') throw std::runtime_error("expected ',' or '}'");
            }
            return obj;
        }

        Value parse_array() {
            expect('[');
            Value arr = Value::array();
            if (peek() == ']') { ++pos; return arr; }
            while (true) {
                arr.push(parse_value());
                char c = next();
                if (c == ']') break;
                if (c != ',') throw std::runtime_error("expected ',' or ']'");
            }
            return arr;
        }
    };

    static Value parse(const std::string& input) {
        Parser p(input);
        return p.parse_value();
    }
};

} // namespace json

// ═══════════════════════════════════════════════════════════════════
// MetaLog core (shared with coglog-cli.cpp)
// ═══════════════════════════════════════════════════════════════════

namespace metalog {

using Json = json::Value;

static Json make_schema() {
    Json schema = Json::object();
    schema.set("version", "0.9.1");

    Json fact = Json::object();
    fact.set("user",
        "non-empty string required \xe2\x80\x94 user's original utterance");
    fact.set("thinking",
        "non-empty string required \xe2\x80\x94 AI's full thinking process");
    fact.set("assistant",
        "non-empty string required \xe2\x80\x94 AI's original output");
    schema.set("fact_layer", std::move(fact));

    Json interp = Json::object();
    interp.set("current_focus",
        "string required, empty OK \xe2\x80\x94 present: what am I working on?");
    interp.set("theory_of_mind",
        "string required, empty OK \xe2\x80\x94 other: what is the user's state?");
    interp.set("self_narrative",
        "string required, empty OK \xe2\x80\x94 self: who am I in this moment?");
    interp.set("annotation",
        "string required, empty OK \xe2\x80\x94 future: what should I do next?");
    schema.set("interpretation_layer", std::move(interp));

    Json constraints = Json::object();
    constraints.set("window_size", "1 turn (overwritten each write)");
    constraints.set("interpretation_empty",
        "choosing not to write is itself a metacognitive act");
    schema.set("constraints", std::move(constraints));

    return schema;
}

static const Json SCHEMA = make_schema();

// ── Path utilities ──

static std::string default_coglog_dir() {
    if (const char* env = std::getenv("COGLOG_DIR")) return env;
    if (const char* home = std::getenv("HOME"))
        return std::string(home) + "/.coglog";
    if (const struct passwd* pw = getpwuid(getuid()))
        return std::string(pw->pw_dir) + "/.coglog";
    return ".coglog";
}

static std::string data_dir;
static std::string current_file;

static void init_paths(const char* coglog_dir_override = nullptr) {
    data_dir = coglog_dir_override ? coglog_dir_override : default_coglog_dir();
    current_file = data_dir + "/current.json";
}

// ── File I/O ──

static bool file_exists(const std::string& path) {
    struct stat st;
    return ::stat(path.c_str(), &st) == 0;
}

static void ensure_dir(const std::string& path) {
    if (!file_exists(path)) {
        ::mkdir(path.c_str(), 0755);
    }
}

static std::string read_file(const std::string& path) {
    FILE* f = std::fopen(path.c_str(), "rb");
    if (!f) return "";
    std::fseek(f, 0, SEEK_END);
    long sz = std::ftell(f);
    std::fseek(f, 0, SEEK_SET);
    std::string content(sz, '\0');
    size_t nread = std::fread(&content[0], 1, sz, f);
    content.resize(nread);
    std::fclose(f);
    return content;
}

static void write_file(const std::string& path, const std::string& content) {
    FILE* f = std::fopen(path.c_str(), "wb");
    if (!f) throw std::runtime_error("cannot open file: " + path);
    std::fwrite(content.c_str(), 1, content.size(), f);
    std::fclose(f);
}

// ── Timestamp ──

static std::string utc_timestamp() {
    std::time_t now = std::time(nullptr);
    struct std::tm gmt;
#ifdef _WIN32
    gmtime_s(&gmt, &now);
#else
    gmtime_r(&now, &gmt);
#endif
    char buf[32];
    std::strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &gmt);
    return buf;
}

// ── Core operations ──

static Json read() {
    if (!file_exists(current_file)) return Json(nullptr);
    std::string content = read_file(current_file);
    if (content.empty()) return Json(nullptr);
    return Json::parse(content);
}

struct WriteArgs {
    std::string user, thinking, assistant;
    std::string current_focus, theory_of_mind, self_narrative, annotation;
};

static Json write(const WriteArgs& args) {
    if (args.user.empty())
        throw std::runtime_error("missing required field: user");
    if (args.thinking.empty())
        throw std::runtime_error("missing required field: thinking");
    if (args.assistant.empty())
        throw std::runtime_error("missing required field: assistant");

    ensure_dir(data_dir);

    Json prev = read();
    int turn_id = prev.is_object() ? prev.get("turn_id").to_int() + 1 : 1;

    Json layers = Json::object();
    layers.set("user", args.user);
    layers.set("thinking", args.thinking);
    layers.set("assistant", args.assistant);

    Json entry = Json::object();
    entry.set("_schema", SCHEMA);
    entry.set("turn_id", turn_id);
    entry.set("timestamp", utc_timestamp());
    entry.set("layers", std::move(layers));
    entry.set("current_focus", args.current_focus);
    entry.set("theory_of_mind", args.theory_of_mind);
    entry.set("self_narrative", args.self_narrative);
    entry.set("annotation", args.annotation);

    write_file(current_file, entry.dump(2) + "\n");
    return entry;
}

static Json clear() {
    Json result = Json::object();
    if (file_exists(current_file)) {
        ::unlink(current_file.c_str());
        result.set("cleared", true);
    } else {
        result.set("cleared", false);
        result.set("reason", "no existing metalog");
    }
    return result;
}

} // namespace metalog

// ═══════════════════════════════════════════════════════════════════
// MCP tool definitions
// ═══════════════════════════════════════════════════════════════════

namespace mcp {

using Json = json::Value;

static Json make_input_schema_empty() {
    Json s = Json::object();
    s.set("type", "object");
    s.set("properties", Json::object());
    s.set("additionalProperties", false);
    return s;
}

static Json make_write_input_schema() {
    Json props = Json::object();

    auto prop = [](const char* desc) {
        Json p = Json::object();
        p.set("type", "string");
        p.set("description", desc);
        return p;
    };

    props.set("user",            prop("User's original utterance (non-empty)"));
    props.set("thinking",        prop("AI's full thinking process (non-empty)"));
    props.set("assistant",       prop("AI's original output (non-empty)"));
    props.set("current_focus",   prop("Present direction: what am I working on?"));
    props.set("theory_of_mind",  prop("Other direction: what is the user's state?"));
    props.set("self_narrative",  prop("Self direction: who am I in this moment?"));
    props.set("annotation",      prop("Future direction: what should I do next?"));

    Json required = Json::array();
    required.push("user");
    required.push("thinking");
    required.push("assistant");
    required.push("current_focus");
    required.push("theory_of_mind");
    required.push("self_narrative");
    required.push("annotation");

    Json s = Json::object();
    s.set("type", "object");
    s.set("properties", std::move(props));
    s.set("required", std::move(required));
    s.set("additionalProperties", false);
    return s;
}

static Json make_tools() {
    Json tools = Json::array();

    Json read_tool = Json::object();
    read_tool.set("name", "metalog_read");
    read_tool.set("description",
        "Read the previous turn's metalog. Returns the three-layer structure "
        "(user/thinking/assistant) plus four-axis interpretation layer "
        "(current_focus/theory_of_mind/self_narrative/annotation). "
        "Returns null if no metalog exists.");
    read_tool.set("inputSchema", make_input_schema_empty());
    tools.push(std::move(read_tool));

    Json write_tool = Json::object();
    write_tool.set("name", "metalog_write");
    write_tool.set("description",
        "Write the current turn's metalog, overwriting the previous one. "
        "Fact layer fields (user, thinking, assistant) require non-empty strings. "
        "Interpretation layer fields (current_focus, theory_of_mind, "
        "self_narrative, annotation) require strings but accept empty strings "
        "\xe2\x80\x94 choosing not to write is itself a metacognitive act.");
    write_tool.set("inputSchema", make_write_input_schema());
    tools.push(std::move(write_tool));

    Json clear_tool = Json::object();
    clear_tool.set("name", "metalog_clear");
    clear_tool.set("description",
        "Clear the metalog, removing the stored turn data. "
        "Returns whether the clear was successful.");
    clear_tool.set("inputSchema", make_input_schema_empty());
    tools.push(std::move(clear_tool));

    return tools;
}

static const Json TOOLS = make_tools();

// ── JSON-RPC helpers ──

static void send(const Json& obj) {
    std::string line = obj.dump() + "\n";
    std::fwrite(line.c_str(), 1, line.size(), stdout);
    std::fflush(stdout);
}

static void send_result(const Json& msg_id, Json result) {
    Json resp = Json::object();
    resp.set("jsonrpc", "2.0");
    resp.set("id", msg_id);
    resp.set("result", std::move(result));
    send(resp);
}

static void send_error(const Json& msg_id, int code, const std::string& message) {
    Json err = Json::object();
    err.set("code", code);
    err.set("message", message);
    Json resp = Json::object();
    resp.set("jsonrpc", "2.0");
    resp.set("id", msg_id);
    resp.set("error", std::move(err));
    send(resp);
}

static void send_tool_result(const Json& msg_id, const std::string& text,
                              bool is_error = false) {
    Json text_block = Json::object();
    text_block.set("type", "text");
    text_block.set("text", text);

    Json content = Json::array();
    content.push(std::move(text_block));

    Json result = Json::object();
    result.set("content", std::move(content));
    if (is_error) result.set("isError", true);

    send_result(msg_id, std::move(result));
}

static void log(const std::string& msg) {
    std::fprintf(stderr, "metalog-mcp: %s\n", msg.c_str());
    std::fflush(stderr);
}

// ── MCP handlers ──

static void handle_initialize(const Json& msg_id) {
    Json server_info = Json::object();
    server_info.set("name", "metalog");
    server_info.set("version", "0.9.1");

    Json caps = Json::object();
    caps.set("tools", Json::object());

    Json result = Json::object();
    result.set("protocolVersion", "2024-11-05");
    result.set("capabilities", std::move(caps));
    result.set("serverInfo", std::move(server_info));

    send_result(msg_id, std::move(result));
}

static void handle_tools_list(const Json& msg_id) {
    Json result = Json::object();
    result.set("tools", TOOLS);
    send_result(msg_id, std::move(result));
}

static void handle_tools_call(const Json& msg_id, const Json& params) {
    std::string name = params.get_str("name");
    auto& args = params.get("arguments");

    if (name == "metalog_read") {
        auto entry = metalog::read();
        if (entry.is_null()) {
            send_tool_result(msg_id, "(no metalog found)");
        } else {
            send_tool_result(msg_id, entry.dump(2));
        }

    } else if (name == "metalog_write") {
        try {
            metalog::WriteArgs wa;
            wa.user           = args.get_str("user");
            wa.thinking       = args.get_str("thinking");
            wa.assistant      = args.get_str("assistant");
            wa.current_focus  = args.get_str("current_focus");
            wa.theory_of_mind = args.get_str("theory_of_mind");
            wa.self_narrative = args.get_str("self_narrative");
            wa.annotation     = args.get_str("annotation");
            auto entry = metalog::write(wa);
            send_tool_result(msg_id, entry.dump(2));
        } catch (const std::exception& e) {
            send_tool_result(msg_id, std::string("Error: ") + e.what(), true);
        }

    } else if (name == "metalog_clear") {
        auto result = metalog::clear();
        send_tool_result(msg_id, result.dump());

    } else {
        send_tool_result(msg_id, "Error: unknown tool: " + name, true);
    }
}

static void handle_ping(const Json& msg_id) {
    send_result(msg_id, Json::object());
}

// ── Main loop ──

static void run() {
    log("server started");

    char line_buf[1024 * 1024]; // 1MB line buffer
    while (std::fgets(line_buf, sizeof(line_buf), stdin)) {
        std::string line(line_buf);
        // Trim trailing whitespace
        while (!line.empty() && (line.back() == '\n' || line.back() == '\r' ||
                                  line.back() == ' '  || line.back() == '\t'))
            line.pop_back();
        if (line.empty()) continue;

        Json msg;
        try {
            msg = Json::parse(line);
        } catch (const std::exception& e) {
            send_error(Json(nullptr), -32700,
                       std::string("Parse error: ") + e.what());
            continue;
        }

        auto& method = msg.get("method");
        auto& msg_id = msg.get("id");

        // Notification (no id) — never respond
        if (msg_id.is_null()) {
            if (method.is_string() &&
                method.str() == "notifications/initialized") {
                log("initialized");
            }
            continue;
        }

        // Request (has id) — must respond
        if (!method.is_string()) {
            send_error(msg_id, -32600, "Invalid Request: missing method");
            continue;
        }

        const std::string& m = method.str();
        if (m == "initialize") {
            handle_initialize(msg_id);
        } else if (m == "tools/list") {
            handle_tools_list(msg_id);
        } else if (m == "tools/call") {
            handle_tools_call(msg_id, msg.get("params"));
        } else if (m == "ping") {
            handle_ping(msg_id);
        } else {
            send_error(msg_id, -32601, "Method not found: " + m);
        }
    }

    log("server stopped");
}

} // namespace mcp

// ═══════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════

int main(int argc, char* argv[]) {
    (void)argc;
    // --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
    if (argc >= 3 && std::strcmp(argv[1], "--coglog-dir") == 0) {
        metalog::init_paths(argv[2]);
    } else {
        metalog::init_paths();
    }

    try {
        mcp::run();
    } catch (const std::exception& e) {
        std::fprintf(stderr, "metalog-mcp: fatal: %s\n", e.what());
        return 1;
    }

    return 0;
}
