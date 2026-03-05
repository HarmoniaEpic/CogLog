# coglog-core v0.9.1

CogLog のコアライブラリ。データ型、バリデーション、ファイル I/O を提供する。

[coglog](https://crates.io/crates/coglog)（CLI）と [coglog-mcp](https://crates.io/crates/coglog-mcp)（MCP サーバー）が依存する。11言語実装の中で Rust のみが純粋核を独立クレートとして分離しており、これは workspace 内で型の同一性を保つための言語上の制約による。

## 使い方

```rust
use coglog_core::{MetaLog, WriteArgs};

let ml = MetaLog::new();

// 読み出し
let entry = ml.read()?;

// 書き込み
let entry = ml.write(WriteArgs {
    user: "Hello".into(),
    thinking: "User greeted me".into(),
    assistant: "Hi there!".into(),
    current_focus: "greeting".into(),
    theory_of_mind: "friendly".into(),
    self_narrative: "".into(),
    annotation: "".into(),
})?;

// リセット
let result = ml.clear()?;
```

API の詳細は [docs.rs](https://docs.rs/coglog-core) を参照。

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス

MIT
