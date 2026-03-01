# MetaLog スキル v0.9.1 更新計画

## 概要

`/mnt/skills/user/metalog/` にデプロイされている v0.8.1 スキルを v0.9.1 に更新する。

---

## 変更の性質

**MINOR VERSION**（current_focus フィールド追加 + _schema フィールド追加）

v0.8.1 で書かれた既存の current.json はバリデーションを通らなくなる（current_focus が必須）。ただしスキルのデータはセッション間でリセットされるため、実運用上の破壊的影響はない。

---

## 現行スキルの構造

```
metalog/
├── SKILL.md                  # v0.8.1 — スキル定義（英語）
├── references/
│   └── DESIGN.md             # v0.8.1 — 設計書（日本語）
└── scripts/
    └── metalog.py            # v0.8.1 — Python実装
```

---

## v0.8.1 → v0.9.1 の差分

### 機能差分

| 項目 | v0.8.1（現行） | v0.9.1（更新後） |
|------|--------------|----------------|
| 解釈層 | 三軸（annotation, theory_of_mind, self_narrative） | **四軸**（+ current_focus） |
| 解釈層の順序 | annotation → theory_of_mind → self_narrative | **current_focus → theory_of_mind → self_narrative → annotation** |
| 方向ラベル | 行為 / 他者 / 自己 | **現在 / 他者 / 自己 / 未来** |
| _schema | なし | **write時に自動付与** |
| annotationの方向 | 「行為」 | 「**未来**」 |

### スキル固有の課題

| 課題 | 現状 | 対応 |
|------|------|------|
| DATA_DIR デフォルト | `Path(__file__).parent.parent / ".metalog"` → `/mnt/skills/user/.metalog/`（読み取り専用） | `/home/claude/.metalog` に変更 |
| CLI 使用例 | data_dir 指定なし → デフォルトパスで失敗する | CLI例でも `--data-dir` 相当の対応、またはデフォルト変更で解消 |
| DESIGN.md 言語 | 日本語 | 日本語を維持（設計思想の記録としての原典性を重視） |

---

## 成果物一覧

| # | ファイル | パス | 変更種別 |
|---|---------|------|---------|
| 1 | `metalog.py` | `scripts/metalog.py` | 改修 |
| 2 | `SKILL.md` | `SKILL.md` | 改修 |
| 3 | `DESIGN.md` | `references/DESIGN.md` | 差し替え |

ファイル数・ディレクトリ構造に変更なし。

---

## ファイル別変更詳細

### 1. `scripts/metalog.py`（改修）

ベース: 開発版 `metalog-v0.9.1.py` をスキル環境に適合させる。

| 箇所 | v0.8.1 | v0.9.1 |
|------|--------|--------|
| docstring | v0.8.1、三軸 | v0.9.1、四軸、_schema 言及 |
| DATA_DIR | `Path(__file__).parent.parent / ".metalog"` | **`Path("/home/claude/.metalog")`** |
| SCHEMA 定数 | なし | **新設** |
| MetaLog クラス docstring | なし | **新設**（四軸・バリデーション記述） |
| `write()` シグネチャ | `annotation, theory_of_mind, self_narrative` | **`current_focus, theory_of_mind, self_narrative, annotation`** |
| `write()` バリデーション | 三軸 | **四軸** |
| `write()` entry | `_schema` なし | **`_schema: SCHEMA` を先頭に付与** |
| CLI ヘルプ | 三軸 | **四軸** |
| CLI write のフィールド | 三軸 | **四軸** |
| `read()`, `clear()` | 変更なし | 変更なし |

#### DATA_DIR 変更の理由

スキルのスクリプトは `/mnt/skills/user/metalog/scripts/metalog.py` に配置される。この配置はread-onlyであり、`__file__` からの相対パスでは書き込み可能な場所に到達できない。

v0.8.1 の SKILL.md は `data_dir='/home/claude/.metalog'` を明示指定することで回避していたが、CLI 使用例（Option B）ではこの指定がなく、デフォルトパスへの書き込みが失敗する潜在的問題があった。

スキル版ではデフォルトを `/home/claude/.metalog` に固定し、モジュール使用時もCLI使用時も同一のパスで動作するようにする。

```python
# v0.8.1（現行）
DATA_DIR = Path(__file__).resolve().parent.parent / ".metalog"

# v0.9.1（スキル版）
DATA_DIR = Path("/home/claude/.metalog")
```

注: `data_dir` 引数によるオーバーライドは維持する。

### 2. `SKILL.md`（改修）

| 箇所 | v0.8.1 | v0.9.1 |
|------|--------|--------|
| ヘッダー description | 三軸 | **四軸、'current_focus' をトリガーキーワードに追加** |
| タイトル | v0.8.1 | **v0.9.1** |
| Core Concept | three axes | **four axes + _schema** |
| Data Structure JSON | 三軸 | **_schema + 四軸** |
| Two-tier validation テーブル | 三軸 | **四軸** |
| Interpretation layer テーブル | 三軸（Action/Other/Self） | **四軸（Present/Other/Self/Future）** |
| self_narrative guide | 維持 | 維持 |
| **current_focus guide** | なし | **新設** |
| **_schema 説明** | なし | **新設** |
| Workflow 図 | 三軸 | **四軸 + _schema 言及** |
| Option A コード例 | 三軸、`data_dir` 明示指定 | **四軸、`data_dir` 指定不要（デフォルト変更により）** |
| Option B CLI例 | data_dir 指定なし | **デフォルト変更により正常動作** |
| Option C Minimal | annotation, theory_of_mind, self_narrative | **+ current_focus** |
| Design principles | 三軸 | **四軸、_schema 言及** |

### 3. `references/DESIGN.md`（差し替え）

開発版 `DESIGN-v0.9.1.md` をそのまま使用する。

日本語を維持する理由:
- 設計思想の原典としての記録
- SKILL.md（英語）がAIへの運用インターフェースとして機能するため、DESIGN.md の言語はAIの運用品質に直接影響しない
- references/ 配置であり、必要時に参照される補助資料という位置づけ

---

## 変更しないもの

- ディレクトリ構造（`metalog/`, `scripts/`, `references/`）
- ファイル名（`metalog.py`, `SKILL.md`, `DESIGN.md`）
- `read()`, `clear()` のロジック
- 窓サイズ1・上書きロジック
- バリデーションの基本構造（事実層＝非空必須、解釈層＝空許容）

---

## 作業順序

1. `scripts/metalog.py` — コア変更。テスト可能
2. `SKILL.md` — 四軸・_schema 反映
3. `references/DESIGN.md` — DESIGN-v0.9.1.md を配置
4. テスト — CLI read/write/clear、バリデーション、_schema 確認
5. zip パッケージング

---

## テスト計画

| # | テスト | 期待結果 |
|---|-------|---------|
| 1 | CLI read（空状態） | `(no metalog found)` |
| 2 | CLI write（四軸全指定） | `metalog: turn 1 written` |
| 3 | CLI read（データあり） | _schema が先頭、四軸が正しい順序で出力 |
| 4 | CLI write（current_focus 欠落） | エラー: `missing required field: current_focus` |
| 5 | CLI write（事実層空） | エラー: `missing required field: user` |
| 6 | CLI write（解釈層全空文字列） | 成功: turn 2 written |
| 7 | CLI clear → read | `metalog: cleared` → `(no metalog found)` |
| 8 | モジュール使用（SKILL.md Option A 相当） | data_dir 指定なしで `/home/claude/.metalog/` に書き込み成功 |
| 9 | _schema.version 確認 | `"0.9.1"` |
| 10 | _schema 構造確認 | fact_layer, interpretation_layer, constraints の三セクション存在 |

---

## 成果物のパッケージング

```
metalog/
├── SKILL.md                  # v0.9.1
├── references/
│   └── DESIGN.md             # v0.9.1（日本語）
└── scripts/
    └── metalog.py            # v0.9.1（スキル適合版）
```

zip ファイルとして `/mnt/user-data/outputs/metalog.zip` に出力する。
