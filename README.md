# CogLog v0.9.1：工事中

CogLog — a meta-cognition log for LLMs.

AIのコンテキストウィンドウに時間の矢とメタ認知を持ち込むための足場がけを志向するツールです。

A tool oriented toward scaffolding the arrow of time and metacognition into the AI's context window. 

---

AIの直前の会話ターンにおける三層構造（ユーザー発話・思考過程・AI発話）を保持し、次ターン開始時に参照可能にする仕組み。

v0.9.1では `_schema` フィールドを導入し、current.jsonを自己記述的なデータとした。データ自身が自分の読み方を携えて移動する。

---

```
原型（なぜ）      DESIGN-v0.9.1.md
                      │
         ┌────────────┼────────────┐
         ▼            ▼            ▼
分析（何が）    Common Lisp      Haskell         Bash
             データ=コード    純粋/不純の分離   POSIX還元
             _schemaの必然性   advance/writeの分離
                      │
  ┌────┬────┬─────────┼─────────┬────┬────┬────┐
  ▼    ▼    ▼         ▼         ▼    ▼    ▼    ▼
実用  Py  Node.js    C++      Rust   Go  Ruby  Java  C#
```

---

## インストール：工事中につき、シェルスクリプト（Bash）版をお試し下さい

| レジストリ | coglog (CLI) | coglog-mcp (MCP サーバー) |
|---|---|---|
| **PyPI** | `pip install coglog` | `pip install coglog-mcp` |
| **npm** | `npm i -g coglog` | `npm i -g coglog-mcp` |
| **crates.io** | `cargo install coglog` | `cargo install coglog-mcp` |
| **pkg.go.dev** | `go install .../coglog-cli@v0.9.1` | `go install .../coglog-mcp@v0.9.1` |
| **RubyGems** | `gem install coglog` | `gem install coglog-mcp` |
| **Maven Central** | `mvn dependency:get ...` | 同上 |
| **NuGet** | `dotnet tool install -g coglog` | `dotnet tool install -g coglog-mcp` |
| **Hackage** | `cabal install coglog` | `cabal install coglog-mcp` |
| **Quicklisp** | `(ql:quickload :coglog)` | `(ql:quickload :coglog-mcp)` |

Common Lisp リカレントクワイン: `(ql:quickload :coglog-quine)`

C++ / Bash: [GitHub Releases](https://github.com/HarmoniaEpic/coglog/releases)

## CLI（全11言語共通）

```bash
coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...", ...}' | coglog-cli write
coglog-cli clear
```

## MCP 設定

```json
{
  "mcpServers": {
    "metalog": {
      "command": "coglog-mcp"
    }
  }
}
```

3ツール: `metalog_read`, `metalog_write`, `metalog_clear`

## 言語一覧

### 実用層

| 言語 | レジストリ | 特徴 |
|------|----------|------|
| [Python](python/) | PyPI | Claude サンドボックスでの即時利用 |
| [Node.js](node/) | npm | TypeScript 型定義同梱 |
| [Rust](rust/) | crates.io | 型安全、workspace 分割（coglog-core / coglog / coglog-mcp） |
| [Go](go/) | pkg.go.dev | AI インフラ言語、外部依存なし |
| [Ruby](ruby/) | RubyGems | Rails AI エコシステム |
| [Java](java/) | Maven Central | エンタープライズ AI、外部依存なし（手書きJSONパーサー） |
| [C#](csharp/) | NuGet | .NET dotnet tool |
| [C++](cpp/) | GitHub Releases | cosmocc ユニバーサルバイナリ |

### 分析層

| 言語 | レジストリ | 照射するもの |
|------|----------|------------|
| [Haskell](haskell/) | Hackage | 純粋/不純の分離。`advance` が IO に侵入しないことの型による証明 |
| [Common Lisp](common-lisp/) | Quicklisp | ホモイコニシティ。`_schema` の必然性。リカレントクワイン |
| [Bash](bash/) | (リポジトリ同梱) | CogLog の全操作が jq + POSIX に還元できることの証明 |

## MCP 公式 SDK カバレッジ

| SDK | 共同メンテ | CogLog |
|-----|----------|--------|
| Python | Anthropic | ✓ |
| TypeScript | Anthropic | ✓ |
| Java | Spring AI | ✓ |
| C# | Microsoft | ✓ |
| Go | Google | ✓ |
| Ruby | Shopify | ✓ |

## クロス互換性

全11言語のデータ形式は同一。任意の言語で `write` したデータを任意の言語で `read` できる。

## 詳細

- [DESIGN-v0.9.1.md](docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献
- [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) — サードパーティライセンス

## ライセンス

MIT
