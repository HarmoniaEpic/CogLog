# CogLog CLI v0.9.1 (Bash)

CogLog の全操作が jq + POSIX に還元できることの証明。

## 必要環境

- Bash 4.0+
- [jq](https://jqlang.github.io/jq/) 1.6+

jq が未検出の場合、OS を判定してインストールコマンドを案内する。

## インストール

```bash
# GitHub Releases からダウンロード
curl -LO https://github.com/HarmoniaEpic/coglog/releases/latest/download/coglog-bash-v0.9.1.zip
unzip coglog-bash-v0.9.1.zip

# または直接取得
curl -LO https://raw.githubusercontent.com/HarmoniaEpic/coglog/main/bash/coglog/coglog-cli.sh
chmod +x coglog-cli.sh
```

## 使い方

```bash
bash coglog-cli.sh read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | bash coglog-cli.sh write
bash coglog-cli.sh clear
```

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ | `~/.coglog` |

## 特徴

- **CLI のみ**: MCP サーバーは実装しない。POSIX shell では Content-Length フレーミングの実用的な実装が不可能なため
- **外部依存は jq のみ**: グルー言語として「つなぐ対象」が jq しかないという事実が、CogLog の本質的単純さの証明になる
- **アトミック書き込み**: mktemp + mv による安全なファイル置換。他の言語実装にはない安全策
- **完全互換**: 他の全言語実装と同じ JSON 形式を入出力

## この実装が照射するもの

CogLog の操作は3つに分解される。

| 操作 | POSIX 還元 |
|------|-----------|
| read | cat → jq（整形） |
| write | jq（バリデーション + 構築）→ mktemp → mv |
| clear | rm |

`_schema` の生成すら jq フィルタの一発で完結する。CogLog の「コア」は JSON の変換規則以外の何物でもない——Bash 版はこの事実を最も直接的に示す。

## 内部構成

```
coglog-cli.sh
├── require_jq      jq 依存の検出 + OS 別インストール案内
├── SCHEMA_FILTER   _schema を生成する jq フィルタ（定数）
├── cmd_read        cat + jq '.'
├── cmd_write       jq(validate) → jq(build) → mktemp → mv
├── cmd_clear       rm
└── main            dispatch
```

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/CogLog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想・背景文献

## ライセンス

MIT
