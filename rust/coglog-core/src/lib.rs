//! CogLog v0.9.1 — Minimal cognitive continuity for LLMs.
//!
//! A single-window (size 1) log that holds the previous turn's three-layer
//! structure (user utterance, thinking process, assistant output) plus a
//! four-axis interpretation layer (current_focus, theory_of_mind,
//! self_narrative, annotation), making it available at the start of the
//! next turn.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::fs;
use std::path::PathBuf;

// ═══════════════════════════════════════════════════════════════════
// Error
// ═══════════════════════════════════════════════════════════════════

#[derive(Debug)]
pub enum Error {
    Io(std::io::Error),
    Json(serde_json::Error),
    Validation(String),
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Error::Io(e) => write!(f, "{}", e),
            Error::Json(e) => write!(f, "invalid JSON: {}", e),
            Error::Validation(msg) => write!(f, "{}", msg),
        }
    }
}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e)
    }
}

impl From<serde_json::Error> for Error {
    fn from(e: serde_json::Error) -> Self {
        Error::Json(e)
    }
}

// ═══════════════════════════════════════════════════════════════════
// Data types
// ═══════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FactLayerSchema {
    pub user: String,
    pub thinking: String,
    pub assistant: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InterpretationLayerSchema {
    pub current_focus: String,
    pub theory_of_mind: String,
    pub self_narrative: String,
    pub annotation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintsSchema {
    pub window_size: String,
    pub interpretation_empty: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schema {
    pub version: String,
    pub fact_layer: FactLayerSchema,
    pub interpretation_layer: InterpretationLayerSchema,
    pub constraints: ConstraintsSchema,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Layers {
    pub user: String,
    pub thinking: String,
    pub assistant: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entry {
    pub _schema: Schema,
    pub turn_id: u64,
    pub timestamp: String,
    pub layers: Layers,
    pub current_focus: String,
    pub theory_of_mind: String,
    pub self_narrative: String,
    pub annotation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClearResult {
    pub cleared: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

// ═══════════════════════════════════════════════════════════════════
// Schema constant
// ═══════════════════════════════════════════════════════════════════

pub fn make_schema() -> Schema {
    Schema {
        version: "0.9.1".into(),
        fact_layer: FactLayerSchema {
            user: "non-empty string required \u{2014} user's original utterance".into(),
            thinking: "non-empty string required \u{2014} AI's full thinking process".into(),
            assistant: "non-empty string required \u{2014} AI's original output".into(),
        },
        interpretation_layer: InterpretationLayerSchema {
            current_focus: "string required, empty OK \u{2014} present: what am I working on?"
                .into(),
            theory_of_mind:
                "string required, empty OK \u{2014} other: what is the user's state?".into(),
            self_narrative:
                "string required, empty OK \u{2014} self: who am I in this moment?".into(),
            annotation: "string required, empty OK \u{2014} future: what should I do next?".into(),
        },
        constraints: ConstraintsSchema {
            window_size: "1 turn (overwritten each write)".into(),
            interpretation_empty: "choosing not to write is itself a metacognitive act".into(),
        },
    }
}

// ═══════════════════════════════════════════════════════════════════
// WriteArgs + validation
// ═══════════════════════════════════════════════════════════════════

#[derive(Debug, Clone, Deserialize)]
pub struct WriteArgs {
    pub user: String,
    pub thinking: String,
    pub assistant: String,
    pub current_focus: String,
    pub theory_of_mind: String,
    pub self_narrative: String,
    pub annotation: String,
}

impl WriteArgs {
    pub fn validate(&self) -> Result<(), Error> {
        if self.user.is_empty() {
            return Err(Error::Validation(
                "missing required field: user".into(),
            ));
        }
        if self.thinking.is_empty() {
            return Err(Error::Validation(
                "missing required field: thinking".into(),
            ));
        }
        if self.assistant.is_empty() {
            return Err(Error::Validation(
                "missing required field: assistant".into(),
            ));
        }
        // Interpretation layer: string required, empty acceptable.
        // Fields exist by virtue of being String (not Option<String>).
        Ok(())
    }
}

// ═══════════════════════════════════════════════════════════════════
// Timestamp
// ═══════════════════════════════════════════════════════════════════

pub fn utc_timestamp() -> String {
    unsafe {
        let now = libc::time(std::ptr::null_mut());
        let mut tm: libc::tm = std::mem::zeroed();
        libc::gmtime_r(&now, &mut tm);
        format!(
            "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}Z",
            tm.tm_year + 1900,
            tm.tm_mon + 1,
            tm.tm_mday,
            tm.tm_hour,
            tm.tm_min,
            tm.tm_sec,
        )
    }
}

// ═══════════════════════════════════════════════════════════════════
// Path resolution
// ═══════════════════════════════════════════════════════════════════

pub fn default_coglog_dir() -> PathBuf {
    // 優先順位: COGLOG_DIR env > $HOME/.coglog > ./.coglog（最終フォールバック）
    if let Ok(d) = std::env::var("COGLOG_DIR") {
        return PathBuf::from(d);
    }
    if let Ok(home) = std::env::var("HOME") {
        return PathBuf::from(home).join(".coglog");
    }
    PathBuf::from(".coglog")
}

// ═══════════════════════════════════════════════════════════════════
// MetaLog
// ═══════════════════════════════════════════════════════════════════

pub struct MetaLog {
    pub data_dir: PathBuf,
    pub current_file: PathBuf,
}

impl MetaLog {
    pub fn new() -> Self {
        let data_dir = default_coglog_dir();
        let current_file = data_dir.join("current.json");
        MetaLog {
            data_dir,
            current_file,
        }
    }

    pub fn with_dir(dir: PathBuf) -> Self {
        let current_file = dir.join("current.json");
        MetaLog {
            data_dir: dir,
            current_file,
        }
    }

    pub fn read(&self) -> Result<Option<Entry>, Error> {
        match fs::read_to_string(&self.current_file) {
            Ok(content) => {
                let entry: Entry = serde_json::from_str(&content)?;
                Ok(Some(entry))
            }
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(Error::Io(e)),
        }
    }

    pub fn write(&self, args: WriteArgs) -> Result<Entry, Error> {
        args.validate()?;

        fs::create_dir_all(&self.data_dir)?;

        let prev = self.read()?;
        let turn_id = prev.map_or(1, |e| e.turn_id + 1);

        let entry = Entry {
            _schema: make_schema(),
            turn_id,
            timestamp: utc_timestamp(),
            layers: Layers {
                user: args.user,
                thinking: args.thinking,
                assistant: args.assistant,
            },
            current_focus: args.current_focus,
            theory_of_mind: args.theory_of_mind,
            self_narrative: args.self_narrative,
            annotation: args.annotation,
        };

        let json = serde_json::to_string_pretty(&entry)?;
        fs::write(&self.current_file, json + "\n")?;

        Ok(entry)
    }

    pub fn clear(&self) -> Result<ClearResult, Error> {
        match fs::remove_file(&self.current_file) {
            Ok(()) => Ok(ClearResult {
                cleared: true,
                reason: None,
            }),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(ClearResult {
                cleared: false,
                reason: Some("no existing metalog".into()),
            }),
            Err(e) => Err(Error::Io(e)),
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::sync::atomic::{AtomicU32, Ordering};

    static COUNTER: AtomicU32 = AtomicU32::new(0);

    struct TempDir(PathBuf);

    impl TempDir {
        fn new() -> Self {
            let id = COUNTER.fetch_add(1, Ordering::SeqCst);
            let pid = std::process::id();
            let dir = std::env::temp_dir().join(format!("coglog-test-{}-{}", pid, id));
            fs::create_dir_all(&dir).expect("create temp dir");
            TempDir(dir)
        }

        fn path(&self) -> &std::path::Path {
            &self.0
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn temp_metalog() -> (MetaLog, TempDir) {
        let tmp = TempDir::new();
        let ml = MetaLog::with_dir(tmp.path().to_path_buf());
        (ml, tmp)
    }

    fn sample_args() -> WriteArgs {
        WriteArgs {
            user: "Hello".into(),
            thinking: "User greeted me".into(),
            assistant: "Hi there!".into(),
            current_focus: "greeting".into(),
            theory_of_mind: "friendly".into(),
            self_narrative: "conversational partner".into(),
            annotation: "".into(),
        }
    }

    #[test]
    fn test_read_empty() {
        let (ml, _tmp) = temp_metalog();
        assert!(ml.read().unwrap().is_none());
    }

    #[test]
    fn test_write_read_roundtrip() {
        let (ml, _tmp) = temp_metalog();
        let written = ml.write(sample_args()).unwrap();
        let read = ml.read().unwrap().unwrap();
        assert_eq!(written.turn_id, read.turn_id);
        assert_eq!(written.layers.user, read.layers.user);
        assert_eq!(written.layers.thinking, read.layers.thinking);
        assert_eq!(written.layers.assistant, read.layers.assistant);
        assert_eq!(written.current_focus, read.current_focus);
        assert_eq!(written.theory_of_mind, read.theory_of_mind);
        assert_eq!(written.self_narrative, read.self_narrative);
        assert_eq!(written.annotation, read.annotation);
    }

    #[test]
    fn test_turn_id_increment() {
        let (ml, _tmp) = temp_metalog();
        let e1 = ml.write(sample_args()).unwrap();
        let e2 = ml.write(sample_args()).unwrap();
        assert_eq!(e1.turn_id, 1);
        assert_eq!(e2.turn_id, 2);
    }

    #[test]
    fn test_clear() {
        let (ml, _tmp) = temp_metalog();
        ml.write(sample_args()).unwrap();
        let result = ml.clear().unwrap();
        assert!(result.cleared);
        assert!(ml.read().unwrap().is_none());
    }

    #[test]
    fn test_double_clear() {
        let (ml, _tmp) = temp_metalog();
        let result = ml.clear().unwrap();
        assert!(!result.cleared);
        assert_eq!(result.reason.as_deref(), Some("no existing metalog"));
    }

    #[test]
    fn test_validation_empty_user() {
        let (ml, _tmp) = temp_metalog();
        let mut args = sample_args();
        args.user = "".into();
        let err = ml.write(args).unwrap_err();
        assert!(matches!(err, Error::Validation(_)));
        assert!(err.to_string().contains("user"));
    }

    #[test]
    fn test_validation_empty_thinking() {
        let (ml, _tmp) = temp_metalog();
        let mut args = sample_args();
        args.thinking = "".into();
        let err = ml.write(args).unwrap_err();
        assert!(err.to_string().contains("thinking"));
    }

    #[test]
    fn test_validation_empty_assistant() {
        let (ml, _tmp) = temp_metalog();
        let mut args = sample_args();
        args.assistant = "".into();
        let err = ml.write(args).unwrap_err();
        assert!(err.to_string().contains("assistant"));
    }

    #[test]
    fn test_interpretation_empty_ok() {
        let (ml, _tmp) = temp_metalog();
        let args = WriteArgs {
            user: "test".into(),
            thinking: "t".into(),
            assistant: "a".into(),
            current_focus: "".into(),
            theory_of_mind: "".into(),
            self_narrative: "".into(),
            annotation: "".into(),
        };
        let entry = ml.write(args).unwrap();
        assert_eq!(entry.current_focus, "");
        assert_eq!(entry.theory_of_mind, "");
        assert_eq!(entry.self_narrative, "");
        assert_eq!(entry.annotation, "");
    }

    #[test]
    fn test_utf8_japanese() {
        let (ml, _tmp) = temp_metalog();
        let args = WriteArgs {
            user: "日本語テスト".into(),
            thinking: "メタ認知ログ".into(),
            assistant: "こんにちは".into(),
            current_focus: "多言語対応".into(),
            theory_of_mind: "".into(),
            self_narrative: "".into(),
            annotation: "".into(),
        };
        let entry = ml.write(args).unwrap();
        let read = ml.read().unwrap().unwrap();
        assert_eq!(read.layers.user, "日本語テスト");
        assert_eq!(read.current_focus, "多言語対応");
        assert_eq!(entry.layers.user, read.layers.user);
    }

    #[test]
    fn test_schema_present() {
        let (ml, _tmp) = temp_metalog();
        let entry = ml.write(sample_args()).unwrap();
        assert_eq!(entry._schema.version, "0.9.1");
        assert!(entry._schema.fact_layer.user.contains("non-empty"));
        assert!(entry
            ._schema
            .interpretation_layer
            .annotation
            .contains("future"));
    }

    #[test]
    fn test_json_compat() {
        let (ml, _tmp) = temp_metalog();
        ml.write(sample_args()).unwrap();
        let raw = fs::read_to_string(&ml.current_file).unwrap();
        let reparsed: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(reparsed["turn_id"], 1);
        assert_eq!(reparsed["_schema"]["version"], "0.9.1");
        assert_eq!(reparsed["layers"]["user"], "Hello");
    }
}
