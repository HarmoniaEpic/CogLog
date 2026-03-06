# CogLog CLI v0.9.1 (Bash)

CogLog の全操作が jq + POSIX に還元できることの証明。

Proof that all CogLog operations reduce to jq + POSIX.

## 必要環境 / Requirements

- Bash 4.0+
- [jq](https://jqlang.github.io/jq/) 1.6+

jq が未検出の場合、OS を判定してインストールコマンドを案内する。

If jq is not detected, the script identifies the OS and suggests the appropriate install command.

## インストール / Installation

```bash
# GitHub Releases からダウンロード / Download from GitHub Releases
curl -LO https://github.com/HarmoniaEpic/coglog/releases/latest/download/coglog-bash-v0.9.1.zip
unzip coglog-bash-v0.9.1.zip

# または直接取得 / Or fetch directly
curl -LO https://raw.githubusercontent.com/HarmoniaEpic/coglog/main/bash/coglog/coglog-cli.sh
chmod +x coglog-cli.sh
```

## 使い方 / Usage

```bash
bash coglog-cli.sh read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | bash coglog-cli.sh write
bash coglog-cli.sh clear
```

## 環境変数 / Environment Variables

| 変数 / Variable | 説明 / Description | デフォルト / Default |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ / Data directory | `~/.coglog` |

## 特徴 / Features

- **CLI のみ / CLI only**: MCP サーバーは実装しない。POSIX shell では Content-Length フレーミングの実用的な実装が不可能なため / No MCP server. Practical implementation of Content-Length framing is infeasible in POSIX shell
- **外部依存は jq のみ / Only external dependency is jq**: グルー言語として「つなぐ対象」が jq しかないという事実が、CogLog の本質的単純さの証明になる / The fact that jq is the only thing to "glue" proves CogLog's essential simplicity
- **アトミック書き込み / Atomic writes**: mktemp + mv による安全なファイル置換。他の言語実装にはない安全策 / Safe file replacement via mktemp + mv — a safety measure absent from other language implementations
- **完全互換 / Fully compatible**: 他の全言語実装と同じ JSON 形式を入出力 / Reads and writes the same JSON format as all other language implementations

## この実装が照射するもの / What This Implementation Illuminates

CogLog の操作は3つに分解される。

CogLog's operations decompose into three:

| 操作 / Operation | POSIX 還元 / POSIX Reduction |
|------|-----------|
| read | cat → jq（整形 / formatting） |
| write | jq（バリデーション + 構築 / validation + construction）→ mktemp → mv |
| clear | rm |

`_schema` の生成すら jq フィルタの一発で完結する。CogLog の「コア」は JSON の変換規則以外の何物でもない——Bash 版はこの事実を最も直接的に示す。

Even `_schema` generation is completed in a single jq filter. CogLog's "core" is nothing more than JSON transformation rules — the Bash version demonstrates this fact most directly.

## 内部構成 / Internal Structure

```
coglog-cli.sh
├── require_jq      jq 依存の検出 + OS 別インストール案内 / jq dependency detection + OS-specific install guidance
├── SCHEMA_FILTER   _schema を生成する jq フィルタ（定数） / jq filter that generates _schema (constant)
├── cmd_read        cat + jq '.'
├── cmd_write       jq(validate) → jq(build) → mktemp → mv
├── cmd_clear       rm
└── main            dispatch
```

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献 / Design philosophy and references

## ライセンス / License

MIT
