# CogLog v0.9.1 Rust 実装計画

## 変更の性質

**新規インターフェースの追加**（既存の Python / Node.js / C++ 実装への変更なし）

---

## 動機

Rust 版の位置づけは C++ 版と異なる。C++ + Cosmopolitan は「極小ユニバーサルバイナリ」——1つのバイナリが6 OS で動く——という驚きを提供した。Rust 版が提供するのは **エコシステムとの接合** である。

- `cargo install coglog` の一行でインストールできる
- crates.io に公開することで Rust エコシステムの一部になる
- `cargo build --release` で最適化バイナリが得られる
- AI ツールチェーンの Rust 化の流れ（Hugging Face Tokenizers, Polars, uv 等）と合流する

C++ 版が「設計のミニマリズムが物理的な軽さとして見える」ことを示したとすれば、Rust 版は「ミニマルな設計が Rust の型システムでどう表現されるか」を示す。

---

## 設計判断

### JSON処理

Rust 標準ライブラリに JSON パーサーはない。C++ 版では自作ミニライブラリ（約300行）で対応した。Rust では選択肢が異なる。

| 方針 | 依存 | バイナリ影響 | 評価 |
|---|---|---|---|
| A. serde + serde_json | 3 crates | +数十KB（LTO後） | Rust の事実上の標準。derive マクロで型安全 |
| B. ミニ JSON 自作 | ゼロ | 最小 | 可能だが Rust の所有権モデルで C++ より冗長（~500行） |
| C. simd-json / sonic | 1+ crates | 中〜大 | 高速だが過剰 |

**推奨: A（serde + serde_json）**

理由：

- **ゼロ依存の意味が言語ごとに異なる。** Python / Node.js のゼロ依存は「標準ライブラリの JSON で足りる」ことを意味していた。C++ のゼロ依存は「パッケージマネージャが標準でない」世界での合理的選択だった。Rust では Cargo が言語の一部であり、serde_json は標準ライブラリに最も近い位置にある外部クレートである
- **型安全。** `#[derive(Serialize, Deserialize)]` で MetaLog のスキーマが Rust の型として表現される。バリデーションがコンパイル時に部分的に保証される
- **バイナリサイズへの影響は小さい。** LTO + strip 後、serde_json の追加コストは数十KB。C++ 版の自作 JSON ライブラリ（300行）のコンパイル結果と同程度
- **crates.io のエコシステム慣行。** serde を使わない JSON 処理はレビュアーの警戒を招く

ただし、ゼロ依存版を将来的に作る選択肢は閉じない。その場合は C++ 版のミニ JSON ライブラリを Rust に移植する形になる。

### プロジェクト構造

```
coglog/
├── Cargo.toml
├── LICENSE
├── README.md → README-rust-v0.9.1.md
├── src/
│   ├── lib.rs              共有コード（MetaLog コア + JSON スキーマ）
│   ├── bin/
│   │   ├── coglog.rs       CLI エントリポイント
│   │   └── coglog-mcp-server.rs  MCP サーバーエントリポイント
```

**1クレート・2バイナリ構成。** 理由：

- MetaLog コアを `lib.rs` に置き、両バイナリから参照する。コードの重複なし
- `cargo install coglog` で両バイナリがインストールされる
- crates.io のパッケージ名は `coglog` 1つで済む
- `coglog-mcp` の名前は必要に応じて後から予約可能

これは Python 版・C++ 版の「シングルファイル・コア複製」方針とは異なる。Rust / Cargo の世界では `lib.rs` + `bin/` が自然な共有形態であり、言語の慣行に従う。

### 依存クレート

| クレート | 用途 | 必要性 |
|---|---|---|
| serde | シリアライズ/デシリアライズ derive | 必須 |
| serde_json | JSON パース/シリアライズ | 必須 |

**2クレートのみ。** 以下は使用しない：

- **chrono**: タイムスタンプは `libc::gmtime_r` + 手動フォーマットで生成。chrono は大きい
- **anyhow / thiserror**: エラー型は手書き。この規模では derive マクロの方が重い
- **clap**: CLI 引数は `std::env::args` で十分。サブコマンドは read / write / clear の3つのみ
- **tokio / async-std**: MCP サーバーは同期 stdio。非同期は不要

### エラー処理

```rust
#[derive(Debug)]
enum Error {
    Io(std::io::Error),
    Json(serde_json::Error),
    Validation(String),
}
```

`Box<dyn std::error::Error>` やトレイトオブジェクトは使わない。列挙型で閉じた世界を維持する。

### タイムスタンプ

```rust
fn utc_timestamp() -> String {
    // libc::time + libc::gmtime_r → ISO 8601 手動フォーマット
    // chrono を避けるための措置
}
```

`std::time::SystemTime` から UNIX epoch 秒を取得し、libc で UTC に変換する。もしくは UNIX epoch からの手動計算で libc すら避けることもできるが、可読性とのトレードオフ。

---

## 内部構成

### lib.rs

```rust
// ── データ型 ──
#[derive(Serialize, Deserialize)]
struct Schema { ... }

#[derive(Serialize, Deserialize)]
struct Layers {
    user: String,
    thinking: String,
    assistant: String,
}

#[derive(Serialize, Deserialize)]
struct Entry {
    _schema: Schema,
    turn_id: u64,
    timestamp: String,
    layers: Layers,
    current_focus: String,
    theory_of_mind: String,
    self_narrative: String,
    annotation: String,
}

// ── バリデーション ──
struct WriteArgs { ... }   // 全7フィールド
impl WriteArgs {
    fn validate(&self) -> Result<(), Error> { ... }
}

// ── コア操作 ──
struct MetaLog {
    data_dir: PathBuf,
    current_file: PathBuf,
}

impl MetaLog {
    fn new() -> Self { ... }         // exe と同ディレクトリに .metalog/
    fn read(&self) -> Result<Option<Entry>, Error> { ... }
    fn write(&self, args: WriteArgs) -> Result<Entry, Error> { ... }
    fn clear(&self) -> Result<ClearResult, Error> { ... }
}
```

### bin/coglog.rs

```rust
fn main() {
    let ml = MetaLog::new();
    match args {
        "read"  => ml.read() → JSON pretty-print → stdout,
        "write" => stdin → serde_json::from_reader → ml.write() → stdout,
        "clear" => ml.clear() → stdout,
        _       => usage,
    }
}
```

### bin/coglog-mcp-server.rs

```rust
fn main() {
    let ml = MetaLog::new();
    // stdin 行ループ
    for line in BufReader::new(stdin()).lines() {
        let msg: JsonValue = serde_json::from_str(&line)?;
        // method / id 抽出 → ディスパッチ
        match method {
            "initialize"  => handle_initialize(id),
            "tools/list"  => handle_tools_list(id),
            "tools/call"  => handle_tools_call(id, params, &ml),
            "ping"        => handle_ping(id),
            _             => send_error(id, -32601, ...),
        }
    }
}
```

MCP ハンドラ層では `serde_json::Value` を直接操作する。ツール定義の inputSchema 等は静的 JSON として構築する。

---

## バリデーション

| 層 | フィールド | Rust での表現 |
|---|---|---|
| 事実層 | user, thinking, assistant | `String` + `validate()` で `is_empty()` 検査 |
| 解釈層 | current_focus, theory_of_mind, self_narrative, annotation | `String`（空許容。型で保証） |

`WriteArgs` の全フィールドが `String` であること自体が「存在チェック」を兼ねる。`Option<String>` ではなく `String` とすることで、フィールドの欠落をデシリアライズ時に検出する。

---

## データ互換性

Rust 版が書き出す `current.json` は全実装と互換。

- serde_json のデフォルトシリアライズは JSON 仕様準拠
- `_schema` のフィールド順序は `#[derive(Serialize)]` のフィールド定義順で決まる。struct の定義順を他実装と合わせる
- UTF-8 はバイト列のまま保存（serde_json のデフォルト動作）
- `ensure_ascii=False`（Python）/ `ensure_ascii: false`（C++版）と同等

検証項目：
- Rust write → Python read: ✓
- Rust write → C++ read: ✓
- Python write → Rust read: ✓
- C++ write → Rust read: ✓

---

## テスト計画

### 単体テスト（`#[cfg(test)]`）

lib.rs に組み込む。`cargo test` で実行。

| # | テスト | 検証内容 |
|---|---|---|
| 1 | `test_write_read_roundtrip` | write → read で全フィールドが一致する |
| 2 | `test_turn_id_increment` | 2回 write して turn_id が 1, 2 になる |
| 3 | `test_clear` | clear 後に read が None を返す |
| 4 | `test_double_clear` | データなし時の clear が cleared: false を返す |
| 5 | `test_validation_empty_user` | user 空文字列で Validation エラー |
| 6 | `test_validation_empty_thinking` | thinking 空文字列で Validation エラー |
| 7 | `test_validation_empty_assistant` | assistant 空文字列で Validation エラー |
| 8 | `test_interpretation_empty_ok` | 解釈層全空で write が成功する |
| 9 | `test_utf8_japanese` | 日本語テキストの write → read |
| 10 | `test_schema_present` | エントリに _schema が含まれ version が "0.9.1" |
| 11 | `test_json_compat` | Rust 版の出力を serde_json で再パースして一致 |

### 統合テスト（CLI）

C++ 版と同じパイプ方式。

| # | テスト | コマンド | 期待結果 |
|---|---|---|---|
| 1 | 空読み出し | `./coglog read` | `(no metalog found)` |
| 2 | 書き込み | `echo '{...}' \| ./coglog write` | `metalog: turn 1 written` |
| 3 | 読み出し | `./coglog read` | 書き込んだエントリ |
| 4 | クリア | `./coglog clear` | `metalog: cleared` |
| 5 | バリデーション | user 空で write | exit 1, エラーメッセージ |

### 統合テスト（MCP）

| # | テスト | メソッド | 期待結果 |
|---|---|---|---|
| 1 | ハンドシェイク | `initialize` | protocolVersion, capabilities, serverInfo |
| 2 | ツール一覧 | `tools/list` | 3ツール定義 |
| 3 | read/write/clear サイクル | `tools/call` 各種 | 正常動作 |
| 4 | バリデーションエラー | write (user空) | `isError: true` |
| 5 | 不正 JSON | 壊れた入力 | `-32700` |

---

## 規模見積もり

| セクション | 行数 |
|---|---|
| lib.rs: データ型定義（Entry, Schema, WriteArgs, Error） | ~80行 |
| lib.rs: MetaLog impl（new, read, write, clear, validate） | ~100行 |
| lib.rs: ユーティリティ（パス解決, タイムスタンプ） | ~30行 |
| lib.rs: テスト | ~120行 |
| bin/coglog.rs: CLI | ~70行 |
| bin/coglog-mcp-server.rs: MCP ツール定義 | ~60行 |
| bin/coglog-mcp-server.rs: JSON-RPC 層 | ~50行 |
| bin/coglog-mcp-server.rs: ハンドラ + メインループ | ~100行 |
| Cargo.toml | ~20行 |
| **合計（テスト含む）** | **~630行** |

C++ 版（テストなし 1,441行）より少ない。理由：

- コア部分の重複がない（lib.rs を共有）
- serde の derive マクロが JSON シリアライズコードを自動生成
- Rust の `?` 演算子によるエラー処理の簡潔さ

---

## ビルドとリリース

### ローカルビルド

```bash
cargo build --release
# target/release/coglog
# target/release/coglog-mcp-server
```

### バイナリサイズ最適化（Cargo.toml）

```toml
[profile.release]
opt-level = "z"     # サイズ最適化
lto = true          # リンク時最適化
codegen-units = 1   # 最適化の徹底
panic = "abort"     # パニック時の巻き戻しコード削除
strip = true        # デバッグシンボル除去
```

推定サイズ: 300KB〜600KB（ターゲットによる）。

### クロスコンパイル

Rust + Cosmopolitan は実験的であり安定していない。代わりに GitHub Actions のマトリクスビルドで各ターゲットのネイティブバイナリを生成する。

```yaml
strategy:
  matrix:
    include:
      - target: x86_64-unknown-linux-gnu
        os: ubuntu-latest
      - target: x86_64-unknown-linux-musl
        os: ubuntu-latest
      - target: aarch64-unknown-linux-gnu
        os: ubuntu-latest
      - target: x86_64-apple-darwin
        os: macos-latest
      - target: aarch64-apple-darwin
        os: macos-latest
      - target: x86_64-pc-windows-msvc
        os: windows-latest
```

C++ 版が1バイナリで6 OS をカバーするのに対し、Rust 版は6バイナリで6ターゲットをカバーする。アプローチが異なるが、到達点は同じ。

### crates.io 公開

```bash
cargo login
cargo publish --dry-run   # 事前確認
cargo publish
```

公開後、`cargo install coglog` で両バイナリがインストールされる。

---

## Cargo.toml

```toml
[package]
name = "coglog"
version = "0.9.1"
edition = "2021"
description = "CogLog — a meta-cognition log for LLMs"
license = "MIT"
repository = "https://github.com/xxx/coglog"
keywords = ["llm", "metacognition", "mcp", "ai", "cognitive"]
categories = ["command-line-utilities"]

[dependencies]
serde = { version = "1", features = ["derive"] }
serde_json = "1"

[[bin]]
name = "coglog"
path = "src/bin/coglog.rs"

[[bin]]
name = "coglog-mcp-server"
path = "src/bin/coglog-mcp-server.rs"

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
panic = "abort"
strip = true
```

---

## 各言語版の比較

| | Python | Node.js | C++ | **Rust** |
|---|---|---|---|---|
| ファイル構成 | シングルファイル | シングルファイル | シングルファイル | Cargo プロジェクト |
| JSON 処理 | 標準ライブラリ | 標準ライブラリ | 自作300行 | serde_json |
| 外部依存 | ゼロ | ゼロ | ゼロ | 2 crates |
| コア重複 | CLI/MCP で複製 | CLI/MCP で複製 | CLI/MCP で複製 | lib.rs 共有 |
| バイナリ配布 | cosmofy (34MB) | QuickJS+cosmocc (~1MB) | cosmocc (~50KB) | ネイティブ (~500KB) |
| ユニバーサル | ✓ (APE) | ✓ (APE) | ✓ (APE) | ✗（ターゲット別） |
| パッケージ | PyPI | npm | GitHub Releases | **crates.io** |
| インストール | `pip install coglog` | `npm i coglog` | `curl` + 実行 | `cargo install coglog` |
| 型安全 | — | — | — | **コンパイル時検証** |
| テスト | 外部 | 外部 | 外部 | `cargo test` 統合 |

---

## 変更なし

以下のファイルに変更はない：

- `metalog-v0.9.1.py` — Python CLI
- `metalog-v0.9.1.mjs` — Node.js CLI
- `metalog-mcp-server-v0.9.1.py` — Python MCP サーバー
- `metalog-mcp-server-v0.9.1.mjs` — Node.js MCP サーバー
- `coglog-v0.9.1.cpp` — C++ CLI
- `coglog-mcp-server-v0.9.1.cpp` — C++ MCP サーバー
- `DESIGN-v0.9.1.md` — 設計書
- 各 README, PLAN

Rust 版は既存実装と並立する追加のインターフェースである。

---

## バージョニング

CogLog のバージョンは **v0.9.1 のまま**。

Rust 版は新しいビルドターゲットの追加であり、データ構造・バリデーション・`_schema` に変更はない。全実装が同一の `current.json` を共有可能。

---

## 承認事項

以下について承認を求めます：

1. **serde_json の採用**: ゼロ依存ではなく、serde + serde_json（2 crates）を依存に含める
2. **Cargo プロジェクト構造**: シングルファイルではなく、lib.rs + bin/ の標準的な Cargo レイアウトを採用する
3. **libc クレートの追加可否**: タイムスタンプ生成に `libc::gmtime_r` を使う場合、libc クレートが追加で必要になる。代替として UNIX epoch からの手動計算で libc を避けることも可能だが、閏秒等の扱いが煩雑になる
