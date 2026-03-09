# CI テスト導入計画

> **改訂履歴**
>
> | 日付 | 内容 |
> |------|------|
> | 2026-03-09 | 初版作成 |

---

## 概要

既存の shell テストハーネス（611 テスト全 PASS）を GitHub Actions 上で自動実行する CI パイプラインを導入する。

### 設計原則

現行設計の利点を維持することを最優先とする。

| 現行設計の利点 | CI 導入時の制約 |
|---|---|
| shell ハーネスが仕様の Single Source of Truth | CI は harness.sh をそのまま呼ぶ。言語別ユニットテストを新設しない |
| `prepare_lang` の graceful skip | 全ツールチェーンの強制インストールはしない。利用可能言語のみテスト |
| 追加ビルドシステム層の不在 | Makefile / タスクランナーを新設しない。ハーネスが自己完結 |
| リンター設定の不在 | 言語別リンターを CI に導入しない |

```
VERSION (root)
  ↓
version-sync.yml ─→ v{VERSION} tag ─→ release-*.yml (既存)
  │
  │  ┌──────────────────────────────────────────┐
  └──┤ ci-test.yml (新規)                       │
     │  ├─ Layer 1: harness.sh      (CLI)       │
     │  ├─ Layer 2: harness-mcp.sh  (MCP)       │
     │  └─ Layer 3: harness-quine.sh (Quine)    │
     └──────────────────────────────────────────┘
```

---

## §1. ワークフロー設計

### 1.1 トリガー

```yaml
on:
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '*.md'
      - 'coglog-skill/**'
      - 'LICENSE'
      - 'THIRD_PARTY_LICENSES.md'
  pull_request:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '*.md'
      - 'coglog-skill/**'
      - 'LICENSE'
      - 'THIRD_PARTY_LICENSES.md'
```

**根拠**: コード変更のみで発火。ドキュメント・ライセンス・スキルパッケージの変更は CI 不要。

### 1.2 言語ティア分割

11言語全てのツールチェーンを単一ジョブに載せると、インストール時間が支配的になり CI の実用性が低下する。言語を **3 ティア** に分割し、ティアごとにジョブを並列実行する。

| ティア | 言語 | 根拠 | ランナーのツールチェーン状況 |
|---|---|---|---|
| **Tier 1: ゼロセットアップ** | Python, Node.js, Bash | `ubuntu-latest` にプリインストール | 追加インストール不要 |
| **Tier 2: 軽量セットアップ** | Rust, Go, Ruby, Java, C# | 公式 Actions / `apt` で 1-2 分以内 | actions/setup-* で導入 |
| **Tier 3: 重量セットアップ** | Haskell, Common Lisp, C++ | cabal / sbcl / cosmocc のインストールに時間を要する | 別ジョブで分離 |

### 1.3 ジョブ構成

```
ci-test.yml
  ├── tier1-core (Python, Node.js, Bash)     ~1 min
  ├── tier2-compiled (Rust, Go, Ruby, Java, C#)  ~5 min
  ├── tier3-specialized (Haskell, CL, C++)   ~8 min
  ├── cross-compat (全言語間の相互運用)       depends: tier1, tier2, tier3
  ├── mcp (harness-mcp.sh)                   depends: tier1, tier2, tier3
  └── quine (harness-quine.sh)               depends: tier3 (sbcl)
```

**cross-compat が全ティアに依存する理由**: クロス互換テスト（言語 A で write → 言語 B で read）は全言語のビルドが完了している必要がある。ただし、現行ハーネスのクロス互換テストは `harness.sh all` 内に含まれるため、ティアごとに `harness.sh <lang...>` を実行した場合はクロス互換がスキップされる。これを解決する方法は §2 で定義する。

### 1.4 ワークフロー YAML（完全版）

```yaml
name: CI Tests

on:
  push:
    branches: [main]
    paths-ignore: ['docs/**', '*.md', 'coglog-skill/**', 'LICENSE', 'THIRD_PARTY_LICENSES.md']
  pull_request:
    branches: [main]
    paths-ignore: ['docs/**', '*.md', 'coglog-skill/**', 'LICENSE', 'THIRD_PARTY_LICENSES.md']

permissions:
  contents: read

jobs:
  # ── Tier 1: ゼロセットアップ言語 ──
  tier1-core:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install jq
        run: command -v jq || sudo apt-get install -y jq

      - name: Run CLI tests (Python, Node.js, Bash)
        run: ./tests/harness.sh python node bash

      - name: Run MCP tests (Python, Node.js)
        run: ./tests/harness-mcp.sh python node

  # ── Tier 2: 軽量セットアップ言語 ──
  tier2-compiled:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: 'stable'

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Install jq
        run: command -v jq || sudo apt-get install -y jq

      - name: Run CLI tests (Rust, Go, Ruby, Java, C#)
        run: ./tests/harness.sh rust go ruby java csharp

      - name: Run MCP tests (Rust, Go, Ruby, Java, C#)
        run: ./tests/harness-mcp.sh rust go ruby java csharp

  # ── Tier 3: 重量セットアップ言語 ──
  tier3-specialized:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Haskell
        uses: haskell-actions/setup@v2
        with:
          ghc-version: 'latest'
          cabal-version: 'latest'

      - name: Cabal update
        run: cabal update

      - name: Setup SBCL
        run: sudo apt-get install -y sbcl

      - name: Setup C++ (system compiler)
        run: command -v c++ || sudo apt-get install -y g++

      - name: Install jq
        run: command -v jq || sudo apt-get install -y jq

      - name: Run CLI tests (Haskell, CL, C++)
        run: ./tests/harness.sh haskell cl cpp

      - name: Run MCP tests (Haskell, CL, C++)
        run: ./tests/harness-mcp.sh haskell cl cpp

      - name: Run Quine tests
        run: ./tests/harness-quine.sh

  # ── 全言語クロス互換テスト ──
  cross-compat:
    needs: [tier1-core, tier2-compiled, tier3-specialized]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # 全ツールチェーンのセットアップ（Tier 1-3 の合算）
      - uses: dtolnay/rust-toolchain@stable
      - uses: actions/setup-go@v5
        with: { go-version: 'stable' }
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: '3.3' }
      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }
      - uses: actions/setup-dotnet@v4
        with: { dotnet-version: '8.0.x' }
      - uses: haskell-actions/setup@v2
        with: { ghc-version: 'latest', cabal-version: 'latest' }
      - run: cabal update

      - name: Install system dependencies
        run: sudo apt-get install -y jq sbcl

      - name: Run full test suite (all 11 languages)
        run: ./tests/harness.sh all
```

### 1.5 キャッシュ戦略

初期導入時はキャッシュなしで運用する。安定稼働後に以下を段階的に追加する。

| ティア | キャッシュ対象 | キーパターン |
|---|---|---|
| Tier 2 | `~/.cargo/registry`, `rust/target` | `cargo-${{ hashFiles('rust/Cargo.lock') }}` |
| Tier 2 | `~/go/pkg/mod` | `go-${{ hashFiles('go/go.sum') }}` |
| Tier 2 | `~/.m2/repository` | `maven-${{ hashFiles('java/**/pom.xml') }}` |
| Tier 3 | `~/.cabal/store` | `cabal-${{ hashFiles('haskell/**/*.cabal') }}` |

**根拠**: キャッシュの導入は CI の安定性が確認されてからが適切。キャッシュの不整合はデバッグが困難であり、初期段階で複雑性を入れない。

---

## §2. ハーネスへの変更

### 2.1 変更方針

ハーネス自体の変更は **最小限** に留める。

### 2.2 CI 環境での graceful skip

現行の `prepare_lang` は既に graceful skip を実装している。CI 環境では全ツールチェーンをセットアップするため skip は発生しないが、セットアップ失敗時にも安全に動作する。

```
prepare_lang()
  ├─ require_cmd ─→ コマンド存在 → テスト実行
  │                  コマンド不在 → skip() → SKIP カウント増加（FAIL ではない）
  └─ build_java_jar / build_cpp_binary → 自動ビルド
```

**変更不要**: この仕組みは CI でもローカルでも同一に動作する。

### 2.3 cross-compat ジョブとの整合

`harness.sh all` を実行すれば、テストグループ 12（クロス互換テスト）が自動的に発火する。Tier 別ジョブではクロス互換テストがスキップされるが、これは意図的である。

```
Tier 1-3: 各言語の独立テスト（グループ 1-11, 14）
cross-compat: harness.sh all でグループ 12 を含む全テスト実行
```

**変更不要**: ハーネスは `lang_count > 1` でクロス互換を自動判定する既存ロジックで対応済み。

### 2.4 CI 用出力の改善（Phase 2 で検討）

GitHub Actions のログ上で PASS/FAIL/SKIP が見づらい場合、以下の対応を検討する。

| 改善案 | 内容 | 優先度 |
|---|---|---|
| `GITHUB_ACTIONS` 環境変数検出 | `::group::` / `::endgroup::` で言語ごとにログを折り畳み | 低 |
| JUnit XML 出力 | テスト結果を XML で出力し、Actions の Test Reporter で可視化 | 低 |
| 終了コードの明確化 | SKIP のみ（FAIL なし）の場合に exit 0 を保証 | 不要（現行で対応済み） |

**根拠**: ハーネスの主たる価値は「11言語の仕様適合検証」であり、出力フォーマットの改善は本質的ではない。CI が安定稼働した後で必要に応じて対応する。

---

## §3. セキュリティテストの CI 統合

### 3.1 方針

セキュリティテストは機能テストと分離し、**別ワークフローまたはスケジュール実行** とする。

**根拠**:
- セキュリティテスト（5 ハーネス）は実行時間が長い（並行テスト、大量入力等）
- PR ごとの実行はコスト効率が悪い
- P0/P1/P2 の優先度に応じた実行頻度の差別化が望ましい

### 3.2 実行戦略

| 優先度 | ハーネス | 実行タイミング |
|---|---|---|
| **P0** | `harness-path.sh`, `harness-tampering.sh` | main push 時（機能テストと同時） |
| **P1** | `harness-input.sh`, `harness-mcp-security.sh` | 週次スケジュール（`cron: '0 6 * * 1'`） |
| **P2** | `harness-concurrency.sh` | リリース前の手動実行（`workflow_dispatch`） |

### 3.3 ワークフロー YAML（概要）

```yaml
name: Security Tests

on:
  push:
    branches: [main]
    paths-ignore: ['docs/**', '*.md']
  schedule:
    - cron: '0 6 * * 1'   # 毎週月曜 06:00 UTC
  workflow_dispatch:
    inputs:
      priority:
        description: 'Test priority level (P0, P1, P2, all)'
        required: true
        default: 'all'

jobs:
  security-p0:
    runs-on: ubuntu-latest
    # ... 全ツールチェーンセットアップ ...
    steps:
      - run: ./tests-security/harness-path.sh
      - run: ./tests-security/harness-tampering.sh

  security-p1:
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    steps:
      - run: ./tests-security/harness-input.sh
      - run: ./tests-security/harness-mcp-security.sh

  security-p2:
    if: github.event_name == 'workflow_dispatch' && github.event.inputs.priority == 'all' || github.event.inputs.priority == 'P2'
    runs-on: ubuntu-latest
    steps:
      - run: ./tests-security/harness-concurrency.sh
```

---

## §4. 実装手順

### Phase 1: 最小 CI（Tier 1 のみ）

**目標**: CI パイプラインの基本動作を確認する。

| Step | 作業 | 検証 |
|---|---|---|
| 1 | `.github/workflows/ci-test.yml` を作成（tier1-core ジョブのみ） | PR でワークフロー発火を確認 |
| 2 | harness.sh が exit 0 で終了することを確認 | PASS/FAIL/SKIP カウントの出力確認 |
| 3 | harness-mcp.sh の発火確認 | Python, Node.js MCP テスト |

**完了条件**: Python, Node.js, Bash の CLI テスト + Python, Node.js の MCP テストが CI 上で全 PASS。

### Phase 2: Tier 2 追加

| Step | 作業 | 検証 |
|---|---|---|
| 4 | tier2-compiled ジョブを追加 | Rust, Go, Ruby, Java, C# のテスト全 PASS |
| 5 | 各 `actions/setup-*` のバージョン固定を確認 | ツールチェーンバージョンの安定性 |

**完了条件**: Tier 1 + Tier 2 の全テストが CI 上で PASS。

### Phase 3: Tier 3 + クロス互換

| Step | 作業 | 検証 |
|---|---|---|
| 6 | tier3-specialized ジョブを追加 | Haskell, CL, C++ テスト全 PASS |
| 7 | quine テストの動作確認 | harness-quine.sh が CI 上で全 PASS |
| 8 | cross-compat ジョブを追加 | `harness.sh all` で 611 テスト全 PASS |

**完了条件**: 全 611 テストが CI 上で PASS。cross-compat ジョブでグループ 12 が実行される。

### Phase 4: セキュリティテスト統合

| Step | 作業 | 検証 |
|---|---|---|
| 9 | `ci-security.yml` を作成（P0 のみ） | main push で harness-path.sh, harness-tampering.sh が実行 |
| 10 | P1 スケジュール実行を追加 | 週次実行の動作確認 |
| 11 | P2 手動実行を追加 | `workflow_dispatch` での動作確認 |

### Phase 5: 最適化（安定稼働確認後）

| Step | 作業 | 検証 |
|---|---|---|
| 12 | Cargo / Go / Maven / Cabal キャッシュ導入 | 実行時間短縮を計測 |
| 13 | `::group::` ログ折り畳み対応 | GitHub Actions UI での視認性確認 |
| 14 | branch protection rule に CI ステータスチェックを追加 | main への直接 push 防止 |

---

## §5. コスト・時間見積もり

### 実行時間（キャッシュなし）

| ジョブ | 見積もり | 内訳 |
|---|---|---|
| tier1-core | ~1 min | セットアップ不要、テスト実行のみ |
| tier2-compiled | ~5 min | Rust ビルド 2 min + Go/Java/C# ビルド 2 min + テスト 1 min |
| tier3-specialized | ~8 min | Haskell cabal build 5 min + テスト 3 min |
| cross-compat | ~10 min | 全ツールチェーンセットアップ 6 min + harness.sh all 4 min |
| **合計（並列実行）** | **~18 min** | tier1-3 並列 → cross-compat 直列 |

### GitHub Actions 無料枠との整合

| 項目 | 値 |
|---|---|
| 月間無料枠 (public repo) | 無制限 |
| 月間無料枠 (private repo) | 2,000 min |
| 1 回の CI 消費 | ~24 min（4 ジョブ合計） |
| 月 100 回 push 時の消費 | ~2,400 min |

**結論**: パブリックリポジトリであれば無制限。プライベートの場合、cross-compat ジョブを PR のみに限定すれば無料枠内に収まる。

---

## §6. 変更しないもの

- テストハーネスの構造（harness.sh, harness-mcp.sh, harness-quine.sh）
- `common-build.sh` の `require_cmd` / `build_*` ヘルパー
- テストフィクスチャ（fixtures/*.json）
- 既存リリースワークフロー（release-*.yml）
- `version-sync.yml` のトリガー・処理フロー
- 言語別リンター / フォーマッター設定（導入しない）
- Makefile / タスクランナー（導入しない）

---

## §7. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| Haskell cabal build が CI タイムアウト | Tier 3 ジョブ失敗 | タイムアウトを 30 min に設定。キャッシュ導入で緩和 |
| sbcl のバージョン差異でクワインテスト失敗 | Quine テスト失敗 | `apt` の sbcl バージョンを確認。必要なら PPA / Roswell で固定 |
| `actions/setup-*` のメジャーバージョン更新 | ワークフロー破損 | Dependabot で Actions のバージョン更新を自動検出 |
| cross-compat ジョブの実行時間増大 | CI 待ち時間増加 | PR では cross-compat をスキップし、main push でのみ実行する選択肢 |
| flaky test（非決定的テスト失敗） | 偽陽性 | 現行 611 テストは全て決定的。並行テスト (P2) のみ非決定的リスクあり |
