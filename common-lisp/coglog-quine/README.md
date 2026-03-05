# CogLog Recurrent Quine v0.9.1 (Common Lisp)

CogLog の漸化式 $a_{n+1} = f(a_n, x_n, y_n)$ をファイルの自己書き換えとして実装したプログラム。

## 必要環境

- SBCL 2.0+

## 使い方

```bash
sbcl --script recurrent-quine.lisp read
echo '(:user "..." :thinking "..." :assistant "..." :current-focus "..." :theory-of-mind "..." :self-narrative "..." :annotation "...")' | sbcl --script recurrent-quine.lisp write
sbcl --script recurrent-quine.lisp clear
```

入力形式は Common Lisp の plist。キー名はハイフン区切り（`:current-focus` 等）。

## 特徴

- **Recurrent Quine**: 通常のクワイン（Q → Q）と異なり、write で $Q_n$ → $Q_{n+1}$ に自己遷移する。各世代が完全なプログラムとして単体で動作する
- **宿主依存性**: ディスク上では不活性なテキストファイル。LLM + Common Lisp 処理系に読み込まれて初めて動く
- **データ構造の同型性**: 他の全言語実装と同じ三層 + 四軸 + _schema 構造を S式で表現

## 四つ組構造

<br>

```math
Q_n = (\text{*state*},\ \text{*advance-source*},\ \text{*affordance*},\ \text{*self-source*})
```

<br>

| 成分 | 役割 | 変異頻度 |
|---|---|---|
| `*state*` | 現在のエントリ（表現型） | 毎世代 |
| `*advance-source*` | 変換規則（構造遺伝子） | オプション引数で許容 |
| `*affordance*` | LLM への案内（調節配列） | オプション引数で許容 |
| `*self-source*` | 自己複製機構（DNA ポリメラーゼ） | 事実上不変 |

通常の運用では `*state*` のみが毎世代変わる。`*advance-source*` と `*affordance*` は更新を許容するが要求しない。`*self-source*` は事実上不変——ポリメラーゼが自身を複製する。

CLI の write コマンドは、plist 内のオプションキーにより四つ組の他の成分も更新できる。

| オプションキー | 対象 | 省略時 |
|---|---|---|
| `:opt-advance` | `*advance-source*`（変換規則） | 現在の値を維持 |
| `:opt-affordance` | `*affordance*`（LLM への案内） | 現在の値を維持 |
| `:opt-self` | `*self-source*`（自己複製機構） | 現在の値を維持 |

これらのオプションキーは、Recurrent Quine が宿主のサンドボックス能力を借りて四つ組の遺伝子型成分を書き換える経路である。扉は開いているが、開いた先に何があるかを判定する機構は系の内部にない。適応度関数が不在であるため、変更が改善であるかどうかを系自身は検証できない。

`:opt-advance` の使用は、以降の全世代の表現型生成規則を変える。表現型レベルの判断が遺伝子型を書き換える操作であり、ウイルスの逆転写や人為的組み換え操作に相当する。もし LLM のトークンサンプリングに由来する確率的揺らぎに駆動される変更であれば突然変異と相同と見做せるかもしれない。`:opt-affordance` の使用は、変換規則を変えずに LLM の振る舞いを変える。エピジェネティックな発現調節に相当する。`:opt-self` の使用は、複製機構自身の改変であり、round-trip 忠実度（`print → read` の正確さ）を壊す改変は系譜を断絶させる。Eigen の閾値が理論ではなく実際の淘汰圧として機能する。

これらのオプションキーを使うか使わないか、いつ使うか、何を書き込むかの判断は LLM に委ねられている。この判断自体がメタ認知的行為であり、CogLog の解釈層が「書かないという選択も一つの有効な判断である」と定めたのと同じ原則が四つ組全体に拡張されている。

## 情報的散逸構造仮説

CogLog の自己書き換えサイクルは、プロトコル $f$（read → process → write）の駆動が状態ファイルを通過する流れの中に情報的散逸構造を形成する。

### エントロピー収支

$$\Delta H_n = -\underbrace{H(a_n \mid a_{n+1})}_{\text{不可逆的情報損失}} + \underbrace{I(a_{n+1}; y_n \mid a_n)}_{\text{外部情報の取り込み}} + \underbrace{I(a_{n+1}; x_n \mid a_n, y_n)}_{\text{内部揺らぎの寄与}}$$

Landauer の原理（ $S = k_B H$ ）により、この情報エントロピー収支は Prigogine の熱力学的エントロピー収支式 $dS/dt = d_e S/dt + d_i S/dt$ と物理的に同じ方程式である。

### プロトコル $f$ の各段階

| 段階 | 実行者 | エントロピー収支での役割 |
|---|---|---|
| read | サンドボックス環境 | $a_n$ をコンテキストに注入。$H(a_n)$ は変化しない |
| process | LLM | $y_n$（外部情報流入）と $x_n$（内部揺らぎ）が合流し $a_{n+1}$ の内容を決定 |
| write | サンドボックス環境 | $a_{n+1}$ を書き出し $a_n$ を不可逆的に消去。エントロピー排出ポンプ |

- **$y_n$**: 系の外部から流入する全ての情報——ユーザーとの対話、ファイル読み込み、API応答、マルチモーダル入力等
- **$x_n$**: LLM のトークンサンプリングに由来する確率的揺らぎ

窓サイズ1の上書きは、外部入力と内部揺らぎによるエントロピー流入を排出するポンプとして機能する。上書きなしには系はエントロピーを排出できず、平衡に向かって崩壊する。

### 散逸構造の定常条件

$$H(a_n \mid a_{n+1}) \approx I(a_{n+1}; y_n \mid a_n) + I(a_{n+1}; x_n \mid a_n, y_n)$$

write で排出されるエントロピーが、process で流入するエントロピーと釣り合うとき、散逸構造が維持される。

散逸構造としての秩序は read でも process でも write でもなく、この3段階の**流れの中に**創発する。

## 状態機械との比較

クワインは自分自身のソースコードを出力するプログラムである（Q → Q、恒等写像）。入力を取らず、状態を持たない。状態機械は状態の集合、入力の集合、遷移関数を持つ計算モデルである（ $s_{n+1} = \delta(s_n, i_n)$ ）。自己を出力しない。

Recurrent Quine はこの2つを合成する。状態機械のように入力に応じて遷移し（ $a_{n+1} = f(a_n, x_n, y_n)$ ）、クワインのように自分自身を出力する（`write-generation` がファイル全体を書き出す）。ただし出力は自分自身と同一ではない（ $Q_n \neq Q_{n+1}$ ）。

通常の状態機械との差異についてリサーチノート §7.6 は2点を指摘している:

> 第一に、状態空間が記号的ではなく**意味的**である。通常のオートマトンの状態は離散的な記号（ $q_0, q_1, ...$ ）であり、遷移規則は状態遷移表で完全に記述される。CogLogの状態はJSON文書であり、遷移の実質的内容はLLMの自然言語解釈に委ねられる。

> 第二に、遷移関数が**自己参照的**である。Recurrent Quineの `*advance-source*` は状態の一部に含まれており、状態遷移の規則そのものが状態によって変わりうる

今回の改修により `:opt-advance` と `:opt-self` が CLI から操作可能になったことで、第二の性質——遷移関数の自己参照性——が LLM から実際に行使できるようになった。遷移関数（`*advance-source*`）だけでなく、複製機構（`*self-source*`）も状態の一部として書き換え可能である。通常の状態機械では遷移関数は固定されており、この構造はフォン・ノイマンの自己増殖オートマトンに近い。

## 詳細

- [DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想
- [coglog-research-notes-01.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/studies/coglog-research-notes-01.md) — 研究ノート（§4.8 情報的散逸構造仮説、§7 Recurrent Quine、§8 情報生命の構造条件）

## ライセンス

MIT
