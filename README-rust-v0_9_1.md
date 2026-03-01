# CogLog v0.9.1 — Rust Implementation

CogLog — a meta-cognition log for LLMs.

Rust による実装。`cargo install` でインストール可能。serde_json による型安全な JSON 処理。

---

## インストール

### crates.io から

```bash
cargo install coglog
```

`coglog`（CLI）と `coglog-mcp-server`（MCP サーバー）の両バイナリがインストールされる。

### ソースからビルド

```bash
git clone https://github.com/xxx/coglog.git
cd coglog
cargo build --release
# target/release/coglog
# target/release/coglog-mcp-server
```

---

## プロジェクト構成

```
coglog/
├── Cargo.toml
├── src/
│   ├── lib.rs                    MetaLog コア + データ型 + テスト
│   └── bin/
│       ├── coglog.rs             CLI エントリポイント
│       └── coglog-mcp-server.rs  MCP サーバーエントリポイント
```

| ファイル | 行数 | 説明 |
|---|---|---|
| `lib.rs` | 479 | コア（Entry型, Schema型, MetaLog struct, バリデーション, 12テスト） |
| `coglog.rs` | 88 | CLI（read / write / clear） |
| `coglog-mcp-server.rs` | 229 | MCP サーバー（JSON-RPC 2.0 over stdio） |
| **合計** | **825** | テスト含む |

---

## 依存クレート

```
coglog v0.9.1
├── serde v1         シリアライズ/デシリアライズ
├── serde_json v1    JSON パース/シリアライズ
└── libc v0.2        タイムスタンプ生成（gmtime_r）
```

3クレートのみ。async ランタイム、CLI フレームワーク、日時ライブラリは使用しない。

---

## 使い方（CLI）

```bash
# 読み出し
coglog read

# 書き込み（stdin から JSON）
echo '{
  "user": "ユーザーの発話",
  "thinking": "AIの思考過程",
  "assistant": "AIの出力",
  "current_focus": "今取り組んでいること",
  "theory_of_mind": "ユーザーの意図に関する推測",
  "self_narrative": "この対話を経ての即興的な自己物語",
  "annotation": "次の自分への申し送り"
}' | coglog write

# リセット
coglog clear
```

### バリデーション

| 層 | フィールド | 制約 |
|---|---|---|
| 事実層 | user, thinking, assistant | 非空文字列必須 |
| 解釈層 | current_focus, theory_of_mind, self_narrative, annotation | 文字列必須、空文字列許容 |

---

## 使い方（MCP サーバー）

### 起動

```bash
coglog-mcp-server
```

### MCP クライアント設定例

```json
{
  "mcpServers": {
    "metalog": {
      "command": "coglog-mcp-server",
      "args": []
    }
  }
}
```

### Claude Code

```bash
claude mcp add metalog -- coglog-mcp-server
```

### 提供ツール

| ツール名 | 説明 |
|---|---|
| `metalog_read` | 直前ターンのメタログを読み出す |
| `metalog_write` | 現ターンのメタログを書き込む（前回分を上書き） |
| `metalog_clear` | メタログをリセットする |

---

## テスト

```bash
cargo test
```

12の単体テスト: roundtrip, turn_id採番, clear, バリデーション（事実層3フィールド）, 解釈層空許容, UTF-8日本語, スキーマ検証, JSON互換性。

---

## データ互換性

Python 版・Node.js 版・C++ 版と完全互換。Rust 版で書いたデータを他の実装で読める。

```
.metalog/
└── current.json    ← 実行ファイルと同じディレクトリに生成
```

---

## バイナリサイズ

`opt-level = "z"`, LTO, `codegen-units = 1`, `panic = "abort"`, strip で最適化済み。

| バイナリ | サイズ |
|---|---|
| `coglog` (CLI) | 419KB |
| `coglog-mcp-server` | 447KB |

---

## 他の実装との比較

| | Python | Node.js | C++ (cosmocc) | **Rust** |
|---|---|---|---|---|
| インストール | `pip install` | `npm i` | `curl` + 実行 | **`cargo install`** |
| 外部依存 | ゼロ | ゼロ | ゼロ | 3 crates |
| CLI サイズ | ~11KB (+Python) | ~8KB (+Node) | ~50KB | **419KB** |
| ユニバーサル | ✓ (APE) | ✓ (APE) | ✓ (APE) | ✗（ターゲット別） |
| 型安全 | — | — | — | **✓** |
| テスト統合 | 外部 | 外部 | 外部 | **`cargo test`** |

---

## ライセンス

MIT
