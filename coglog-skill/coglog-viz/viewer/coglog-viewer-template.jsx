import { useState, useEffect } from "react";

// ╔═══════════════════════════════════════════════════════════════╗
// ║  CogLog Viewer Template                                       ║
// ║                                                               ║
// ║  Replace COGLOG_DATA below with the output of:                ║
// ║    python3 metalog.py read                                    ║
// ║                                                               ║
// ║  Theme: dark / light / system (default: system)               ║
// ║                                                               ║
// ║  Everything below the data section is the viewer template.    ║
// ║  Do not edit unless customizing the display.                  ║
// ╚═══════════════════════════════════════════════════════════════╝

const COGLOG_DATA = {
  "_schema": {
    "version": "0.9.1",  // @coglog-version
    "fact_layer": {
      "user": "non-empty string required — user's original utterance",
      "thinking": "non-empty string required — AI's full thinking process",
      "assistant": "non-empty string required — AI's original output"
    },
    "interpretation_layer": {
      "current_focus": "string required, empty OK — present: what am I working on?",
      "theory_of_mind": "string required, empty OK — other: what is the user's state?",
      "self_narrative": "string required, empty OK — self: who am I in this moment?",
      "annotation": "string required, empty OK — future: what should I do next?"
    },
    "constraints": {
      "window_size": "1 turn (overwritten each write)",
      "interpretation_empty": "choosing not to write is itself a metacognitive act"
    }
  },
  "turn_id": 0,
  "timestamp": "",
  "layers": {
    "user": "",
    "thinking": "",
    "assistant": ""
  },
  "current_focus": "",
  "theory_of_mind": "",
  "self_narrative": "",
  "annotation": ""
};

// ── Palettes ────────────────────────────────────────────────────

const darkPalette = {
  bg: "#0f0f0f",
  surface: "#1a1a1a",
  border: "#2a2a2a",
  textPrimary: "#e0ddd5",
  textSecondary: "#8a8780",
  textMuted: "#5a5850",
  toggleBg: "#222",
  toggleActive: "#e0ddd5",
  toggleActiveText: "#0f0f0f",
  toggleInactive: "transparent",
  toggleInactiveText: "#5a5850",
  toggleBorder: "#333",
  meta: { accent: "#6b6560", bg: "#1a1918", border: "#2e2b28" },
  fact: {
    user:      { accent: "#c4956a", bg: "#1e1814", border: "#3a2e24" },
    thinking:  { accent: "#9a8a6e", bg: "#1a1914", border: "#33301e" },
    assistant: { accent: "#b08060", bg: "#1c1712", border: "#362a20" },
  },
  axes: {
    current_focus:  { accent: "#d4a44a", bg: "#1c1a12", border: "#3d3518", icon: "\u25C9", direction: "present" },
    theory_of_mind: { accent: "#5a9ead", bg: "#121a1c", border: "#1e3338", icon: "\u25C8", direction: "other" },
    self_narrative:  { accent: "#9a7abf", bg: "#1a1520", border: "#2e2340", icon: "\u25C7", direction: "self" },
    annotation:     { accent: "#6aaa6e", bg: "#141c14", border: "#203820", icon: "\u25B7", direction: "future" },
  }
};

const lightPalette = {
  bg: "#f5f3ef",
  surface: "#ffffff",
  border: "#ddd8d0",
  textPrimary: "#2a2520",
  textSecondary: "#6a6560",
  textMuted: "#9a958e",
  toggleBg: "#e8e4de",
  toggleActive: "#2a2520",
  toggleActiveText: "#f5f3ef",
  toggleInactive: "transparent",
  toggleInactiveText: "#9a958e",
  toggleBorder: "#d0ccc5",
  meta: { accent: "#8a8580", bg: "#edebe6", border: "#d8d4cc" },
  fact: {
    user:      { accent: "#a06830", bg: "#faf5f0", border: "#e8d8c8" },
    thinking:  { accent: "#7a6c4e", bg: "#f8f6f0", border: "#e0dcc8" },
    assistant: { accent: "#906838", bg: "#f9f4ee", border: "#e4d4c4" },
  },
  axes: {
    current_focus:  { accent: "#a07820", bg: "#faf8f0", border: "#e8e0c0", icon: "\u25C9", direction: "present" },
    theory_of_mind: { accent: "#3a7a88", bg: "#f0f6f8", border: "#c0d8e0", icon: "\u25C8", direction: "other" },
    self_narrative:  { accent: "#7050a0", bg: "#f6f0fa", border: "#d4c4e8", icon: "\u25C7", direction: "self" },
    annotation:     { accent: "#3a8040", bg: "#f0f8f0", border: "#c0e0c4", icon: "\u25B7", direction: "future" },
  }
};

function getPalette(theme) {
  return theme === "dark" ? darkPalette : lightPalette;
}

// ── Fonts ───────────────────────────────────────────────────────

const mono = "'IBM Plex Mono', 'SF Mono', 'Consolas', monospace";
const sans = "'Noto Sans JP', 'Hiragino Sans', 'Helvetica Neue', sans-serif";

// ── Theme Hook ──────────────────────────────────────────────────

function useTheme() {
  const [preference, setPreference] = useState("system");
  const [systemTheme, setSystemTheme] = useState("dark");

  useEffect(() => {
    try {
      const mql = window.matchMedia("(prefers-color-scheme: dark)");
      setSystemTheme(mql.matches ? "dark" : "light");
      const handler = (e) => setSystemTheme(e.matches ? "dark" : "light");
      if (mql.addEventListener) {
        mql.addEventListener("change", handler);
        return () => mql.removeEventListener("change", handler);
      }
    } catch (e) {
      setSystemTheme("dark");
    }
  }, []);

  const resolved = preference === "system" ? systemTheme : preference;
  return { preference, setPreference, resolved };
}

// ── Theme Toggle ────────────────────────────────────────────────

function ThemeToggle({ preference, setPreference, p }) {
  const options = [
    { key: "light", label: "\u2600" },
    { key: "system", label: "\u25D0" },
    { key: "dark", label: "\u263E" },
  ];
  return (
    <div style={{
      display: "inline-flex", borderRadius: 6, overflow: "hidden",
      border: `1px solid ${p.toggleBorder}`, background: p.toggleBg,
    }}>
      {options.map(({ key, label }) => {
        const active = preference === key;
        return (
          <button
            key={key}
            onClick={() => setPreference(key)}
            style={{
              background: active ? p.toggleActive : p.toggleInactive,
              color: active ? p.toggleActiveText : p.toggleInactiveText,
              border: "none", cursor: "pointer",
              padding: "3px 10px", fontSize: 13,
              fontFamily: mono,
              transition: "background 0.15s ease, color 0.15s ease",
            }}
            title={key}
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}

// ── Schema Block (collapsible) ──────────────────────────────────

function SchemaBlock({ schema, p }) {
  const [open, setOpen] = useState(false);
  return (
    <div style={{ borderLeft: `2px solid ${p.meta.border}`, marginBottom: 20 }}>
      <button
        onClick={() => setOpen(!open)}
        style={{
          background: "none", border: "none", cursor: "pointer",
          color: p.meta.accent, fontSize: 11, letterSpacing: "0.08em",
          fontFamily: mono, padding: "4px 0 4px 12px",
          display: "flex", alignItems: "center", gap: 6,
          textTransform: "uppercase",
        }}
      >
        <span style={{
          display: "inline-block",
          transform: open ? "rotate(90deg)" : "rotate(0deg)",
          transition: "transform 0.15s ease", fontSize: 9,
        }}>{"\u25B6"}</span>
        _schema v{schema.version}
        <span style={{ color: p.textMuted, textTransform: "none", letterSpacing: 0 }}>
          {" \u2014 "}{open ? "collapse" : "expand"}
        </span>
      </button>
      {open && (
        <pre style={{
          margin: "6px 0 0 12px", padding: 12, fontSize: 10, lineHeight: 1.6,
          background: p.meta.bg, borderRadius: 4, color: p.textMuted,
          fontFamily: mono, overflowX: "auto",
          border: `1px solid ${p.meta.border}`,
        }}>
          {JSON.stringify(schema, null, 2)}
        </pre>
      )}
    </div>
  );
}

// ── Turn Header ─────────────────────────────────────────────────

function TurnHeader({ turnId, timestamp, p }) {
  let formatted = "";
  if (timestamp) {
    const t = new Date(timestamp);
    formatted = [
      t.getUTCFullYear(),
      "-", String(t.getUTCMonth() + 1).padStart(2, "0"),
      "-", String(t.getUTCDate()).padStart(2, "0"),
      " ", String(t.getUTCHours()).padStart(2, "0"),
      ":", String(t.getUTCMinutes()).padStart(2, "0"),
      ":", String(t.getUTCSeconds()).padStart(2, "0"),
      " UTC"
    ].join("");
  }
  return (
    <div style={{
      display: "flex", alignItems: "baseline", gap: 16,
      marginBottom: 24, paddingBottom: 16,
      borderBottom: `1px solid ${p.border}`,
    }}>
      <span style={{
        fontFamily: mono, fontSize: 28, fontWeight: 300,
        color: p.textPrimary, letterSpacing: "-0.02em",
      }}>
        Turn {turnId}
      </span>
      {formatted && (
        <span style={{ fontFamily: mono, fontSize: 11, color: p.textMuted }}>
          {formatted}
        </span>
      )}
    </div>
  );
}

// ── Fact Layer ───────────────────────────────────────────────────

function FactLayer({ layers, p }) {
  const entries = [
    { key: "user",      ...p.fact.user },
    { key: "thinking",  ...p.fact.thinking },
    { key: "assistant", ...p.fact.assistant },
  ];
  return (
    <div style={{ marginBottom: 28 }}>
      <div style={{
        fontSize: 10, letterSpacing: "0.12em", textTransform: "uppercase",
        color: p.textMuted, marginBottom: 10, fontFamily: mono,
      }}>
        Fact Layer {"\u2014"} layers
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {entries.map(({ key, accent, bg, border }) => (
          <div key={key} style={{
            background: bg, border: `1px solid ${border}`, borderRadius: 6,
            padding: "10px 14px", borderLeft: `3px solid ${accent}`,
          }}>
            <div style={{
              fontSize: 10, color: accent, marginBottom: 5,
              fontFamily: mono, letterSpacing: "0.05em",
            }}>
              {key}
            </div>
            <div style={{
              fontSize: 13, lineHeight: 1.65, color: p.textPrimary,
              fontFamily: sans,
            }}>
              {layers[key] || (
                <span style={{ color: p.textMuted, fontStyle: "italic" }}>(empty)</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Interpretation Layer ────────────────────────────────────────

function InterpretationLayer({ data, p }) {
  const axisKeys = ["current_focus", "theory_of_mind", "self_narrative", "annotation"];
  const axes = axisKeys.map((key) => ({
    key, ...p.axes[key], value: data[key],
  }));
  return (
    <div>
      <div style={{
        fontSize: 10, letterSpacing: "0.12em", textTransform: "uppercase",
        color: p.textMuted, marginBottom: 10, fontFamily: mono,
      }}>
        Interpretation Layer {"\u2014"} four axes
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
        {axes.map(({ key, accent, bg, border, icon, direction, value }) => (
          <div key={key} style={{
            background: bg, border: `1px solid ${border}`, borderRadius: 6,
            padding: "12px 14px", borderTop: `3px solid ${accent}`,
            display: "flex", flexDirection: "column",
          }}>
            <div style={{
              display: "flex", alignItems: "center", gap: 6, marginBottom: 8,
            }}>
              <span style={{ color: accent, fontSize: 14 }}>{icon}</span>
              <span style={{
                fontSize: 10, color: accent, fontFamily: mono,
                letterSpacing: "0.05em",
              }}>
                {key}
              </span>
              <span style={{
                fontSize: 9, color: p.textMuted, fontFamily: mono,
                marginLeft: "auto",
              }}>
                {direction}
              </span>
            </div>
            <div style={{
              fontSize: 12.5, lineHeight: 1.65, color: p.textPrimary,
              fontFamily: sans, flex: 1,
            }}>
              {value || (
                <span style={{ color: p.textMuted, fontStyle: "italic" }}>(empty)</span>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Main Viewer ─────────────────────────────────────────────────

export default function CogLogViewer() {
  const d = COGLOG_DATA;
  const { preference, setPreference, resolved } = useTheme();
  const p = getPalette(resolved);

  return (
    <div style={{
      background: p.bg, minHeight: "100vh", padding: "32px 24px",
      fontFamily: sans,
      transition: "background 0.2s ease",
    }}>
      <link
        href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@300;400&family=Noto+Sans+JP:wght@300;400&display=swap"
        rel="stylesheet"
      />
      <div style={{ maxWidth: 720, margin: "0 auto" }}>
        <div style={{
          display: "flex", justifyContent: "space-between", alignItems: "center",
          marginBottom: 8,
        }}>
          <div style={{
            fontSize: 11, color: p.textMuted,
            fontFamily: mono, letterSpacing: "0.15em", textTransform: "uppercase",
          }}>
            CogLog v{d._schema?.version || "0.9.1"}{/* @coglog-version */}
          </div>
          <ThemeToggle preference={preference} setPreference={setPreference} p={p} />
        </div>
        <SchemaBlock schema={d._schema} p={p} />
        <TurnHeader turnId={d.turn_id} timestamp={d.timestamp} p={p} />
        <FactLayer layers={d.layers} p={p} />
        <InterpretationLayer data={d} p={p} />
      </div>
    </div>
  );
}
