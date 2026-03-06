# CogLog CLI v0.9.1 (C++)

シングルファイル・ゼロ依存の CLI 実装。Cosmopolitan Libc でビルドすることで、1つのバイナリが 6 OS で動作するユニバーサルバイナリを生成できる。

A single-file, zero-dependency CLI implementation. By building with Cosmopolitan Libc, a single binary can run on 6 operating systems as a universal binary.

## 必要環境 / Requirements

- C++17 対応コンパイラ（g++, clang++, MSVC） / C++17-compatible compiler
- ユニバーサルバイナリ生成時 / For universal binary: [cosmocc](https://github.com/jart/cosmopolitan)

## ビルド / Build

### 通常のコンパイラ / Standard Compiler

```bash
g++ -std=c++17 -Os -o coglog-cli coglog-cli.cpp
```

### Cosmopolitan Libc（ユニバーサルバイナリ / Universal Binary）

```bash
# cosmocc のダウンロード / Download cosmocc
mkdir -p cosmocc && cd cosmocc
wget https://cosmo.zip/pub/cosmocc/cosmocc.zip
unzip cosmocc.zip
cd ..

# ビルド / Build
./cosmocc/bin/cosmoc++ -std=c++17 -Os -o coglog-cli coglog-cli.cpp
```

生成されるバイナリは Actually Portable Executable (APE) 形式:

The resulting binary is in Actually Portable Executable (APE) format:

| OS | x86_64 | ARM64 |
|----|--------|-------|
| Linux | ✓ | ✓ |
| macOS | ✓ | ✓ |
| Windows | ✓ | — |
| FreeBSD | ✓ | ✓ |
| OpenBSD 7.3+ | ✓ | ✓ |
| NetBSD | ✓ | ✓ |

### 極小バイナリ / Tiny Binary

```bash
./cosmocc/bin/cosmoc++ -std=c++17 -Os -mtiny -o coglog-cli coglog-cli.cpp
```

## 使い方 / Usage

```bash
./coglog-cli read
echo '{"user":"...","thinking":"...","assistant":"...","current_focus":"...","theory_of_mind":"...","self_narrative":"...","annotation":"..."}' | ./coglog-cli write
./coglog-cli clear
```

## 環境変数 / Environment Variables

| 変数 / Variable | 説明 / Description | デフォルト / Default |
|------|------|-----------|
| `COGLOG_DIR` | データディレクトリ / Data directory | `~/.coglog` |

## 特徴 / Features

- **ランタイム不要 / No runtime required**: Python も Node.js もインストールされていない環境で動作する / Works in environments without Python or Node.js installed
- **ユニバーサルバイナリ / Universal binary**: cosmocc ビルドにより、単一バイナリが 6 OS で動作する / A single cosmocc-built binary runs on 6 OSes
- **極小サイズ / Tiny size**: `-mtiny` オプションで 12KB〜 のバイナリを生成可能 / The `-mtiny` option can produce binaries as small as 12KB
- **起動速度 / Fast startup**: インタプリタの起動コストがない / No interpreter startup cost
- **完全互換 / Fully compatible**: 他の全言語実装と同じ JSON 形式を入出力 / Reads and writes the same JSON format as all other language implementations

## この実装の位置づけ / Positioning of This Implementation

ルート README の系統図において、C++ は分析層と実用層の中間に位置する。

In the root README's phylogenetic diagram, C++ sits between the analytical and practical layers.

分析的な意味での照射（Bash の POSIX 還元、Haskell の純粋/不純分離、Common Lisp のホモイコニシティ）は持たないが、「ランタイムもパッケージマネージャも不要」という性質が CogLog の実装上の最小要件を示す——C++17 の標準ライブラリだけで JSON パーサーから CogLog コアまで完結する。

It does not possess analytical illumination (Bash's POSIX reduction, Haskell's pure/impure separation, Common Lisp's homoiconicity), but the property of "requiring neither a runtime nor a package manager" demonstrates CogLog's minimal implementation requirements — everything from the JSON parser to the CogLog core is completed with only the C++17 standard library.

## 内部構成 / Internal Structure

```
coglog-cli.cpp
├── json::Value          ミニ JSON ライブラリ / Mini JSON library（再帰下降パーサー + シリアライザー / recursive descent parser + serializer）
├── coglog::            CogLog コア / CogLog core（read / write / clear）
└── main()               CLI ディスパッチ / CLI dispatch
```

JSON ライブラリを内蔵し、外部依存ゼロを実現する。MCP サーバー版（[coglog-mcp](../coglog-mcp/)）とは json::Value および coglog:: を意図的に複製しており、各ファイルが単体で完結するシングルファイル原則を優先している。

Embeds a JSON library to achieve zero external dependencies. The json::Value and coglog:: namespaces are intentionally duplicated from the MCP server version ([coglog-mcp](../coglog-mcp/)), prioritizing the single-file principle where each file is self-contained.

## 詳細 / Details

[DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md)

## ライセンス / License

MIT
