# CogLog MCP Server v0.9.1 (C++)

シングルファイル・ゼロ依存の MCP サーバー実装。CogLog の read / write / clear を JSON-RPC 2.0 over stdio で公開する。

A single-file, zero-dependency MCP server implementation. Exposes CogLog's read / write / clear via JSON-RPC 2.0 over stdio.

## 必要環境 / Requirements

- C++17 対応コンパイラ（g++, clang++, MSVC） / C++17-compatible compiler
- ユニバーサルバイナリ生成時 / For universal binary: [cosmocc](https://github.com/jart/cosmopolitan)

## ビルド / Build

### 通常のコンパイラ / Standard Compiler

```bash
g++ -std=c++17 -Os -o coglog-mcp coglog-mcp.cpp
```

### Cosmopolitan Libc（ユニバーサルバイナリ / Universal Binary）

```bash
./cosmocc/bin/cosmoc++ -std=c++17 -Os -o coglog-mcp coglog-mcp.cpp
```

cosmocc のセットアップは [coglog-cli の README](../coglog/) を参照。APE 形式のバイナリが Linux, macOS, Windows, FreeBSD, OpenBSD, NetBSD で動作する。

See the [coglog-cli README](../coglog/) for cosmocc setup. The APE-format binary runs on Linux, macOS, Windows, FreeBSD, OpenBSD, and NetBSD.

## 使い方 / Usage

### 起動 / Start

```bash
./coglog-mcp
```

stdin から JSON-RPC 2.0 メッセージを受信し、stdout に応答する。ログは stderr に出力される。

Receives JSON-RPC 2.0 messages from stdin and responds on stdout. Logs are written to stderr.

### MCP クライアント設定 / MCP Client Configuration

```json
{
  "mcpServers": {
    "coglog": {
      "command": "/path/to/coglog-mcp"
    }
  }
}
```

### 提供ツール / Provided Tools

| ツール名 / Tool name | 説明 / Description |
|---|---|
| `coglog_read` | 直前ターンのコグログを読み出す / Read the previous turn's coglog |
| `coglog_write` | 現ターンのコグログを書き込む（前回分を上書き） / Write the current turn's coglog (overwrites previous) |
| `coglog_clear` | コグログをリセットする / Reset the coglog |

### プロトコル / Protocol

- MCP 2024-11-05
- JSON-RPC 2.0 over stdio
- 改行区切り JSON / Newline-delimited JSON

## 環境変数 / Environment Variables

| 変数 / Variable | 説明 / Description | デフォルト / Default |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ / Data directory | `~/.coglog` |

## 特徴 / Features

- **ランタイム不要 / No runtime required**: Python も Node.js もインストールされていない環境で MCP サーバーを起動できる / Can run an MCP server in environments without Python or Node.js
- **ユニバーサルバイナリ / Universal binary**: 単一バイナリが 6 OS で動作する / A single binary runs on 6 OSes
- **完全互換 / Fully compatible**: 他の全言語実装と同じデータ形式 / Same data format as all other language implementations

## 内部構成 / Internal Structure

```
coglog-mcp.cpp
├── json::Value          ミニ JSON ライブラリ / Mini JSON library（再帰下降パーサー + シリアライザー / recursive descent parser + serializer）
├── coglog::            CogLog コア / CogLog core（read / write / clear）
├── mcp::                MCP プロトコル層 / MCP protocol layer
│   ├── TOOLS            ツール定義（JSON-Schema） / Tool definitions (JSON-Schema)
│   ├── send/recv        JSON-RPC 2.0 ヘルパー / JSON-RPC 2.0 helpers
│   ├── handle_*         各メソッドのハンドラ / Method handlers
│   └── run()            stdin ループ / stdin loop
└── main()               エントリポイント / Entry point
```

CLI 版（[coglog-cli](../coglog/)）と json::Value および coglog:: を意図的に複製しており、シングルファイル原則を優先している。

The json::Value and coglog:: namespaces are intentionally duplicated from the CLI version ([coglog-cli](../coglog/)), prioritizing the single-file principle.

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス / License

MIT
