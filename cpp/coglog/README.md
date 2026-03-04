# CogLog v0.9.1 — C++ Implementation

CogLog — a meta-cognition log for LLMs.

C++ によるシングルファイル・ゼロ依存実装。Cosmopolitan Libc でビルドすることで、Linux・macOS・Windows・FreeBSD・OpenBSD・NetBSD 上で動作するユニバーサルバイナリを生成できる。

---

## ファイル構成

| ファイル | 行数 | 説明 |
|---|---|---|
| `coglog-v0.9.1.cpp` | 635 | CLI版（read / write / clear） |
| `coglog-mcp-server-v0.9.1.cpp` | 806 | MCPサーバー版（JSON-RPC 2.0 over stdio） |

両ファイルは独立したシングルファイル。JSON ライブラリと MetaLog コアを各ファイルに内蔵する。

---

## ビルド

### 通常のコンパイラ

```bash
# CLI
g++ -std=c++17 -Os -o coglog coglog-v0.9.1.cpp

# MCP サーバー
g++ -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp
```

### Cosmopolitan Libc（ユニバーサルバイナリ）

```bash
# cosmocc のダウンロード
mkdir -p cosmocc && cd cosmocc
wget https://cosmo.zip/pub/cosmocc/cosmocc.zip
unzip cosmocc.zip
cd ..

# CLI
./cosmocc/bin/cosmocc -std=c++17 -Os -o coglog coglog-v0.9.1.cpp

# MCP サーバー
./cosmocc/bin/cosmocc -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp
```

生成されるバイナリは Actually Portable Executable (APE) 形式。1つのバイナリが以下全てで動作する：

| OS | x86_64 | ARM64 |
|----|--------|-------|
| Linux | ✓ | ✓ |
| macOS | ✓ | ✓ |
| Windows | ✓ | — |
| FreeBSD | ✓ | ✓ |
| OpenBSD 7.3+ | ✓ | ✓ |
| NetBSD | ✓ | ✓ |

### 極小バイナリ

```bash
# -mtiny で最小サイズ（12KB〜）
./cosmocc/bin/cosmocc -std=c++17 -Os -mtiny -o coglog coglog-v0.9.1.cpp
```

### GitHub Actions

```yaml
- name: setup cosmocc
  run: |
    mkdir -p /tmp/cosmocc && cd /tmp/cosmocc
    wget https://cosmo.zip/pub/cosmocc/cosmocc.zip
    unzip cosmocc.zip

- name: build
  run: |
    /tmp/cosmocc/bin/cosmocc -std=c++17 -Os -o coglog coglog-v0.9.1.cpp
    /tmp/cosmocc/bin/cosmocc -std=c++17 -Os -o coglog-mcp-server coglog-mcp-server-v0.9.1.cpp
```

---

## 使い方（CLI）

```bash
# 読み出し
./coglog read

# 書き込み（stdin から JSON）
echo '{
  "user": "ユーザーの発話",
  "thinking": "AIの思考過程",
  "assistant": "AIの出力",
  "current_focus": "今取り組んでいること",
  "theory_of_mind": "ユーザーの意図に関する推測",
  "self_narrative": "この対話を経ての即興的な自己物語",
  "annotation": "次の自分への申し送り"
}' | ./coglog write

# リセット
./coglog clear
```

### バリデーション

| 層 | フィールド | 制約 |
|---|---|---|
| 事実層 | user, thinking, assistant | 非空文字列必須 |
| 解釈層 | current_focus, theory_of_mind, self_narrative, annotation | 文字列必須、空文字列許容 |

解釈層を意図的に空にする——「書くべきことがない」という判断——も一つの有効なメタ認知的行為である。

---

## 使い方（MCP サーバー）

### 起動

```bash
./coglog-mcp-server
```

stdin から JSON-RPC 2.0 メッセージを受信し、stdout に応答する。ログは stderr に出力される。

### MCP クライアント設定例

```json
{
  "mcpServers": {
    "metalog": {
      "command": "/path/to/coglog-mcp-server",
      "args": []
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

---

## データ形式

Python 版・Node.js 版と完全互換。C++ 版で書いたデータを Python 版で読める。

```
.metalog/
└── current.json    ← 実行ファイルと同じディレクトリに生成
```

### current.json の構造

```json
{
  "_schema": {
    "version": "0.9.1",
    "fact_layer": { ... },
    "interpretation_layer": { ... },
    "constraints": { ... }
  },
  "turn_id": 1,
  "timestamp": "2026-02-28T12:00:00Z",
  "layers": {
    "user": "ユーザーの発話",
    "thinking": "AIの思考過程",
    "assistant": "AIの出力"
  },
  "current_focus": "...",
  "theory_of_mind": "...",
  "self_narrative": "...",
  "annotation": "..."
}
```

`_schema` はデータに内在する自己記述的スキーマ。データが自分の読み方を携えて移動する。

---

## 他の実装との対応

| 実装 | CLI | MCP | ランタイム | サイズ |
|---|---|---|---|---|
| Python | `metalog-v0.9.1.py` | `metalog-mcp-server-v0.9.1.py` | Python 3.11+ | ~11KB |
| Node.js | `metalog-v0.9.1.mjs` | `metalog-mcp-server-v0.9.1.mjs` | Node.js 18+ | ~8KB |
| C++ | `coglog-v0.9.1.cpp` | `coglog-mcp-server-v0.9.1.cpp` | なし | ~50KB (native) |
| C++ (cosmocc) | 同上 | 同上 | なし | ユニバーサルバイナリ |

C++ 版の固有の利点：

- **ランタイム不要**: Python も Node.js もインストールされていない環境で動作する
- **ユニバーサルバイナリ**: cosmocc ビルドにより、単一バイナリが6 OS で動作する
- **極小サイズ**: `-mtiny` オプションで12KB〜のバイナリを生成可能
- **起動速度**: インタプリタの起動コストがない

---

## 内部構成

JSON ライブラリを内蔵し、外部依存ゼロを実現する。

```
coglog-v0.9.1.cpp
├── json::Value          ミニ JSON ライブラリ（パーサー + シリアライザー）
│   ├── parse()          再帰下降パーサー。UTF-8 パススルー
│   └── dump()           インデント対応シリアライザー
├── metalog::            MetaLog コア
│   ├── read()           current.json を読み出し
│   ├── write()          バリデーション + 書き込み
│   └── clear()          ファイル削除
└── main()               CLI フロントエンド

coglog-mcp-server-v0.9.1.cpp
├── json::Value          （同上）
├── metalog::            （同上）
├── mcp::                MCP プロトコル層
│   ├── TOOLS            ツール定義（JSON-Schema）
│   ├── send/recv        JSON-RPC 2.0 ヘルパー
│   ├── handle_*         各メソッドのハンドラ
│   └── run()            stdin ループ
└── main()               エントリポイント
```

---

## ライセンス

MIT
