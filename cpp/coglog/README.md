# CogLog CLI v0.9.1 (C++)

シングルファイル・ゼロ依存の CLI 実装。Cosmopolitan Libc でビルドすることで、1つのバイナリが 6 OS で動作するユニバーサルバイナリを生成できる。

## 必要環境

- C++17 対応コンパイラ（g++, clang++, MSVC）
- ユニバーサルバイナリ生成時: [cosmocc](https://github.com/jart/cosmopolitan)

## ビルド

### 通常のコンパイラ

```bash
g++ -std=c++17 -Os -o coglog-cli coglog-cli.cpp
```

### Cosmopolitan Libc（ユニバーサルバイナリ）

```bash
# cosmocc のダウンロード
mkdir -p cosmocc && cd cosmocc
wget https://cosmo.zip/pub/cosmocc/cosmocc.zip
unzip cosmocc.zip
cd ..

# ビルド
./cosmocc/bin/cosmoc++ -std=c++17 -Os -o coglog-cli coglog-cli.cpp
```

生成されるバイナリは Actually Portable Executable (APE) 形式:

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
./cosmocc/bin/cosmoc++ -std=c++17 -Os -mtiny -fno-exceptions -fno-rtti \
  -o coglog-cli coglog-cli.cpp
```

## 使い方

```bash
./coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | ./coglog-cli write
./coglog-cli clear
```

## 環境変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ | `~/.coglog` |

## 特徴

- **ランタイム不要**: Python も Node.js もインストールされていない環境で動作する
- **ユニバーサルバイナリ**: cosmocc ビルドにより、単一バイナリが 6 OS で動作する
- **極小サイズ**: `-mtiny` オプションで 12KB〜 のバイナリを生成可能
- **起動速度**: インタプリタの起動コストがない
- **完全互換**: 他の全言語実装と同じ JSON 形式を入出力

## この実装の位置づけ

ルート README の系統図において、C++ は分析層と実用層の中間に位置する。

分析的な意味での照射（Bash の POSIX 還元、Haskell の純粋/不純分離、Common Lisp のホモイコニシティ）は持たないが、「ランタイムもパッケージマネージャも不要」という性質が CogLog の実装上の最小要件を示す——C++17 の標準ライブラリだけで JSON パーサーから CogLog コアまで完結する。

## 内部構成

```
coglog-cli.cpp
├── json::Value          ミニ JSON ライブラリ（再帰下降パーサー + シリアライザー）
├── metalog::            CogLog コア（read / write / clear）
└── main()               CLI ディスパッチ
```

JSON ライブラリを内蔵し、外部依存ゼロを実現する。MCP サーバー版（[coglog-mcp](../coglog-mcp/)）とは json::Value および metalog:: を意図的に複製しており、各ファイルが単体で完結するシングルファイル原則を優先している。

## 詳細

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス

MIT
