# CogLog MCP Server v0.9.1 (C++)

シングルファイル・ゼロ依存の MCP サーバー実装。CogLog の read / write / clear を JSON-RPC 2.0 over stdio で公開する。

## 必要環境

- C++17 対応コンパイラ（g++, clang++, MSVC）
- ユニバーサルバイナリ生成時: [cosmocc](https://github.com/jart/cosmopolitan)

## ビルド

### 通常のコンパイラ

```bash
g++ -std=c++17 -Os -o coglog-mcp coglog-mcp.cpp
```

### Cosmopolitan Libc（ユニバーサルバイナリ）

```bash
./cosmocc/bin/cosmocc -std=c++17 -Os -o coglog-mcp coglog-mcp.cpp
```

cosmocc のセットアップは [coglog-cli の README](../coglog/) を参照。APE 形式のバイナリが Linux, macOS, Windows, FreeBSD, OpenBSD, NetBSD で動作する。

## 使い方

### 起動

```bash
./coglog-mcp
```

stdin から JSON-RPC 2.0 メッセージを受信し、stdout に応答する。ログは stderr に出力される。

### MCP クライアント設定

```json
{
  "mcpServers": {
    "metalog": {
      "command": "/path/to/coglog-mcp"
    }
  }
}
```

### 提供ツール

| ツール名 | 説明 |
|---|---|
| `metalog_read` | 直前ターンのメタログを読み出す |
| `metalog_write` | 現ターンのメタログを書き込む（前回分を上書き） |
| `metalog_clear` | メタログをリセットする |

### プロトコル

- MCP 2024-11-05
- JSON-RPC 2.0 over stdio
- 改行区切り JSON

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ | `~/.coglog` |

## 特徴

- **ランタイム不要**: Python も Node.js もインストールされていない環境で MCP サーバーを起動できる
- **ユニバーサルバイナリ**: 単一バイナリが 6 OS で動作する
- **完全互換**: 他の全言語実装と同じデータ形式

## 内部構成

```
coglog-mcp.cpp
├── json::Value          ミニ JSON ライブラリ（再帰下降パーサー + シリアライザー）
├── metalog::            CogLog コア（read / write / clear）
├── mcp::                MCP プロトコル層
│   ├── TOOLS            ツール定義（JSON-Schema）
│   ├── send/recv        JSON-RPC 2.0 ヘルパー
│   ├── handle_*         各メソッドのハンドラ
│   └── run()            stdin ループ
└── main()               エントリポイント
```

CLI 版（[coglog-cli](../coglog/)）と json::Value および metalog:: を意図的に複製しており、シングルファイル原則を優先している。

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス

MIT
