# CogLog Recurrent Quine v0.9.1 (Common Lisp)

CogLog の漸化式 $a_{n+1} = f(a_n, x_n, y_n)$ をファイルの自己書き換えとして実装したプログラム。

A program that implements the CogLog recurrence relation $a_{n+1} = f(a_n, x_n, y_n)$ as file self-rewriting.

## 必要環境 / Requirements

- SBCL 2.0+

## 使い方 / Usage

```bash
sbcl --script recurrent-quine.lisp read
echo '(:user "..." :thinking "..." :assistant "..." :current-focus "..." :theory-of-mind "..." :self-narrative "..." :annotation "...")' | sbcl --script recurrent-quine.lisp write
sbcl --script recurrent-quine.lisp clear
```

入力形式は Common Lisp の plist。キー名はハイフン区切り（`:current-focus` 等）。

Input format is a Common Lisp plist. Key names use hyphens (`:current-focus`, etc.).

## 特徴 / Features

- **Recurrent Quine**: 通常のクワイン（Q → Q）と異なり、write で $Q_n$ → $Q_{n+1}$ に自己遷移する。各世代が完全なプログラムとして単体で動作する / Unlike a normal quine (Q → Q), write transitions from $Q_n$ to $Q_{n+1}$. Each generation operates as a complete standalone program
- **宿主依存性 / Host dependency**: ディスク上では不活性なテキストファイル。LLM + Common Lisp 処理系に読み込まれて初めて動く / An inert text file on disk. Only comes alive when loaded by an LLM + Common Lisp runtime
- **データ構造の同型性 / Data structure isomorphism**: 他の全言語実装と同じ三層 + 四軸 + _schema 構造を S式で表現 / Expresses the same three-layer + four-axis + _schema structure as all other language implementations, in S-expressions

## 四つ組構造 / Quadruple Structure

<br>

```math
Q_n = (\text{*state*},\ \text{*advance-source*},\ \text{*affordance*},\ \text{*self-source*})
```

<br>

| 成分 / Component | 役割 / Role | 変異頻度 / Mutation frequency |
|---|---|---|
| `*state*` | 現在のエントリ（表現型） / Current entry (phenotype) | 毎世代 / Every generation |
| `*advance-source*` | 変換規則（構造遺伝子） / Transformation rules (structural gene) | オプション引数で許容 / Allowed via optional argument |
| `*affordance*` | LLM への案内（調節配列） / Guidance for LLM (regulatory sequence) | オプション引数で許容 / Allowed via optional argument |
| `*self-source*` | 自己複製機構（DNA ポリメラーゼ） / Self-replication mechanism (DNA polymerase) | 事実上不変 / Virtually immutable |

通常の運用では `*state*` のみが毎世代変わる。`*advance-source*` と `*affordance*` は更新を許容するが要求しない。`*self-source*` は事実上不変——ポリメラーゼが自身を複製する。

In normal operation, only `*state*` changes each generation. `*advance-source*` and `*affordance*` permit but do not require updates. `*self-source*` is virtually immutable — the polymerase replicates itself.

CLI の write コマンドは、plist 内のオプションキーにより四つ組の他の成分も更新できる。

The CLI write command can update other components of the quadruple via optional keys in the plist.

| オプションキー / Optional key | 対象 / Target | 省略時 / When omitted |
|---|---|---|
| `:opt-advance` | `*advance-source*`（変換規則 / transformation rules） | 現在の値を維持 / Retain current value |
| `:opt-affordance` | `*affordance*`（LLM への案内 / guidance for LLM） | 現在の値を維持 / Retain current value |
| `:opt-self` | `*self-source*`（自己複製機構 / self-replication mechanism） | 現在の値を維持 / Retain current value |

これらのオプションキーは、Recurrent Quine が宿主のサンドボックス能力を借りて四つ組の遺伝子型成分を書き換える経路である。扉は開いているが、開いた先に何があるかを判定する機構は系の内部にない。適応度関数が不在であるため、変更が改善であるかどうかを系自身は検証できない。

These optional keys are the pathways through which the Recurrent Quine borrows the host's sandbox capabilities to rewrite the genotypic components of the quadruple. The door is open, but the system has no internal mechanism to evaluate what lies beyond it. Because there is no fitness function, the system itself cannot verify whether a change constitutes an improvement.

`:opt-advance` の使用は、以降の全世代の表現型生成規則を変える。表現型レベルの判断が遺伝子型を書き換える操作であり、ウイルスの逆転写や人為的組み換え操作に相当する。もし LLM のトークンサンプリングに由来する確率的揺らぎに駆動される変更であれば突然変異と相同と見做せるかもしれない。`:opt-affordance` の使用は、変換規則を変えずに LLM の振る舞いを変える。エピジェネティックな発現調節に相当する。`:opt-self` の使用は、複製機構自身の改変であり、round-trip 忠実度（`print → read` の正確さ）を壊す改変は系譜を断絶させる。Eigen の閾値が理論ではなく実際の淘汰圧として機能する。

Using `:opt-advance` changes the phenotype generation rules for all subsequent generations. A phenotype-level decision rewriting the genotype — analogous to viral reverse transcription or deliberate recombination. If driven by stochastic fluctuations from LLM token sampling, it might be considered homologous to mutation. Using `:opt-affordance` changes LLM behavior without altering the transformation rules — analogous to epigenetic expression regulation. Using `:opt-self` modifies the replication mechanism itself; alterations that break round-trip fidelity (`print → read` accuracy) sever the lineage. Eigen's threshold functions as actual selection pressure, not merely theory.

これらのオプションキーを使うか使わないか、いつ使うか、何を書き込むかの判断は LLM に委ねられている。この判断自体がメタ認知的行為であり、CogLog の解釈層が「書かないという選択も一つの有効な判断である」と定めたのと同じ原則が四つ組全体に拡張されている。

Whether to use these optional keys, when to use them, and what to write — these decisions are left to the LLM. This decision itself is a metacognitive act, and the same principle that CogLog's interpretation layer established — "choosing not to write is itself a valid judgment" — extends to the entire quadruple.

## 情報的散逸構造仮説 / Informational Dissipative Structure Hypothesis

CogLog の自己書き換えサイクルは、プロトコル $f$（read → process → write）の駆動が状態ファイルを通過する流れの中に情報的散逸構造を形成する。

CogLog's self-rewriting cycle forms an informational dissipative structure in the flow driven by protocol $f$ (read → process → write) passing through the state file.

### エントロピー収支 / Entropy Balance

$$\Delta H_n = -\underbrace{H(a_n \mid a_{n+1})}_{\text{不可逆的情報損失}} + \underbrace{I(a_{n+1}; y_n \mid a_n)}_{\text{外部情報の取り込み}} + \underbrace{I(a_{n+1}; x_n \mid a_n, y_n)}_{\text{内部揺らぎの寄与}}$$

Landauer の原理（ $S = k_B H$ ）により、この情報エントロピー収支は Prigogine の熱力学的エントロピー収支式 $dS/dt = d_e S/dt + d_i S/dt$ と物理的に同じ方程式である。

By Landauer's principle ($S = k_B H$), this information entropy balance is physically the same equation as Prigogine's thermodynamic entropy balance $dS/dt = d_e S/dt + d_i S/dt$.

### プロトコル $f$ の各段階 / Stages of Protocol $f$

| 段階 / Stage | 実行者 / Executor | エントロピー収支での役割 / Role in entropy balance |
|---|---|---|
| read | サンドボックス環境 / Sandbox environment | $a_n$ をコンテキストに注入。$H(a_n)$ は変化しない / Injects $a_n$ into context. $H(a_n)$ remains unchanged |
| process | LLM | $y_n$（外部情報流入）と $x_n$（内部揺らぎ）が合流し $a_{n+1}$ の内容を決定 / $y_n$ (external information inflow) and $x_n$ (internal fluctuation) converge to determine $a_{n+1}$ |
| write | サンドボックス環境 / Sandbox environment | $a_{n+1}$ を書き出し $a_n$ を不可逆的に消去。エントロピー排出ポンプ / Writes $a_{n+1}$ and irreversibly erases $a_n$. The entropy exhaust pump |

- **$y_n$**: 系の外部から流入する全ての情報——ユーザーとの対話、ファイル読み込み、API応答、マルチモーダル入力等 / All information flowing in from outside the system — user dialogue, file reads, API responses, multimodal input, etc.
- **$x_n$**: LLM のトークンサンプリングに由来する確率的揺らぎ / Stochastic fluctuation originating from LLM token sampling

窓サイズ1の上書きは、外部入力と内部揺らぎによるエントロピー流入を排出するポンプとして機能する。上書きなしには系はエントロピーを排出できず、平衡に向かって崩壊する。

The window-size-1 overwrite functions as a pump that exhausts the entropy inflow from external input and internal fluctuation. Without overwriting, the system cannot exhaust entropy and collapses toward equilibrium.

### 散逸構造の定常条件 / Steady-State Condition of the Dissipative Structure

$$H(a_n \mid a_{n+1}) \approx I(a_{n+1}; y_n \mid a_n) + I(a_{n+1}; x_n \mid a_n, y_n)$$

write で排出されるエントロピーが、process で流入するエントロピーと釣り合うとき、散逸構造が維持される。

The dissipative structure is maintained when the entropy exhausted by write balances the entropy flowing in during process.

散逸構造としての秩序は read でも process でも write でもなく、この3段階の**流れの中に**創発する。

The order as a dissipative structure emerges not in read, process, or write individually, but **in the flow** of these three stages.

## 状態機械との比較 / Comparison with State Machines

クワインは自分自身のソースコードを出力するプログラムである（Q → Q、恒等写像）。入力を取らず、状態を持たない。状態機械は状態の集合、入力の集合、遷移関数を持つ計算モデルである（ $s_{n+1} = \delta(s_n, i_n)$ ）。自己を出力しない。

A quine is a program that outputs its own source code (Q → Q, identity map). It takes no input and holds no state. A state machine is a computational model with a set of states, a set of inputs, and a transition function ($s_{n+1} = \delta(s_n, i_n)$). It does not output itself.

Recurrent Quine はこの2つを合成する。状態機械のように入力に応じて遷移し（ $a_{n+1} = f(a_n, x_n, y_n)$ ）、クワインのように自分自身を出力する（`write-generation` がファイル全体を書き出す）。ただし出力は自分自身と同一ではない（ $Q_n \neq Q_{n+1}$ ）。

The Recurrent Quine synthesizes these two. It transitions in response to input like a state machine ($a_{n+1} = f(a_n, x_n, y_n)$) and outputs itself like a quine (`write-generation` writes the entire file). However, the output is not identical to itself ($Q_n \neq Q_{n+1}$).

通常の状態機械との差異についてリサーチノート §7.6 は2点を指摘している:

Research Notes §7.6 identifies two differences from ordinary state machines:

> 第一に、状態空間が記号的ではなく**意味的**である。通常のオートマトンの状態は離散的な記号（ $q_0, q_1, ...$ ）であり、遷移規則は状態遷移表で完全に記述される。CogLogの状態はJSON文書であり、遷移の実質的内容はLLMの自然言語解釈に委ねられる。
>
> First, the state space is **semantic**, not symbolic. The states of an ordinary automaton are discrete symbols ($q_0, q_1, ...$) and transition rules are fully described by a state transition table. CogLog's states are JSON documents, and the substantive content of transitions is delegated to the LLM's natural language interpretation.

> 第二に、遷移関数が**自己参照的**である。Recurrent Quineの `*advance-source*` は状態の一部に含まれており、状態遷移の規則そのものが状態によって変わりうる
>
> Second, the transition function is **self-referential**. The Recurrent Quine's `*advance-source*` is contained within the state itself, meaning the rules of state transition can change depending on the state.

今回の改修により `:opt-advance` と `:opt-self` が CLI から操作可能になったことで、第二の性質——遷移関数の自己参照性——が LLM から実際に行使できるようになった。遷移関数（`*advance-source*`）だけでなく、複製機構（`*self-source*`）も状態の一部として書き換え可能である。通常の状態機械では遷移関数は固定されており、この構造はフォン・ノイマンの自己増殖オートマトンに近い。

With this revision, `:opt-advance` and `:opt-self` are now operable from the CLI, making the second property — the self-referentiality of the transition function — actually exercisable by the LLM. Not only the transition function (`*advance-source*`) but also the replication mechanism (`*self-source*`) is rewritable as part of the state. In ordinary state machines the transition function is fixed; this structure is closer to von Neumann's self-reproducing automaton.

## オートマトン理論との比較 / Comparison with Automaton Theory

リサーチノート §7.6 は Recurrent Quine を有限状態トランスデューサに近い構造と位置づけつつ、2つの決定的差異を指摘している。前節で述べた状態空間の意味性と遷移関数の自己参照性である。

Research Notes §7.6 positions the Recurrent Quine as a structure close to a finite-state transducer while identifying two decisive differences: the semantic nature of the state space and the self-referentiality of the transition function, as described in the previous section.

後者の性質——遷移関数が状態の一部に含まれ、状態遷移の規則そのものが状態によって変わりうること——は、フォン・ノイマンの自己増殖オートマトン（1966）と構造を共有する。フォン・ノイマンは、自分自身の記述を読み取り、その記述に従って自分のコピーを構築する万能構成子（universal constructor）を理論的に示した。

The latter property — that the transition function is contained within the state, and the rules of state transition can change depending on the state — shares its structure with von Neumann's self-reproducing automaton (1966). Von Neumann theoretically demonstrated a universal constructor that reads its own description and constructs a copy of itself according to that description.

| | フォン・ノイマンの自己増殖オートマトン / Von Neumann's Self-Reproducing Automaton | Recurrent Quine |
|---|---|---|
| 自己記述 / Self-description | テープ上の命令列 / Instruction sequence on tape | `*self-source*`（quoted form） |
| 構築機構 / Construction mechanism | 万能構成子 / Universal constructor | `write-generation` |
| 複製の忠実度 / Replication fidelity | テープの読み取り精度 / Tape reading accuracy | `print → read` の round-trip 精度 / `print → read` round-trip accuracy |
| 複製の対象 / Replication target | 自分と同一の構造 / Identical structure | 自分と異なる次世代 / Different next generation（ $Q_n \neq Q_{n+1}$ ）|
| 環境 / Environment | セルオートマトンの格子空間 / Cellular automaton lattice space | LLM + サンドボックス（実在するインフラ） / LLM + sandbox (real infrastructure) |

最後の行が決定的な違いである。フォン・ノイマンの自己増殖オートマトンは理論的な格子空間上の構成物であり、実在する計算基盤上で動作するわけではない。この差異は、次節の人工生命研究との比較に直接つながる。

The last row is the decisive difference. Von Neumann's self-reproducing automaton is a construct on a theoretical lattice space; it does not operate on real computational infrastructure. This difference leads directly to the comparison with artificial life research in the next section.

## 人工生命研究との位置関係 / Relationship to Artificial Life Research

通常の人工生命（Artificial Life）研究では、設計者が作った閉じたシミュレーション環境内に生命的な振る舞いを持つエージェントを設計する。Tierra（Ray 1991）はCPU時間と記憶空間を資源とする仮想的なスープの中でデジタル有機体が競争する。Avida（Ofria & Wilke 2004）は論理演算の遂行に報酬を与える。Langton（1986）のセルオートマトン研究は、単純な局所規則から複雑なパターンが創発することを示した。

In conventional artificial life (ALife) research, agents with life-like behavior are designed within closed simulation environments created by the designer. Tierra (Ray 1991) has digital organisms competing in a virtual soup using CPU time and memory as resources. Avida (Ofria & Wilke 2004) rewards the execution of logical operations. Langton's (1986) cellular automaton research showed that complex patterns emerge from simple local rules.

Recurrent Quine はこれらと決定的に異なる。閉じたシミュレーション環境内の生命ではなく、実在するインフラ（LLM + ファイルシステム）の上で動く。Tierra のプログラムはシミュレータの中でしか生きられないが、Recurrent Quine は Common Lisp が動き LLM にアクセスできる環境であればどこでも動きうる。

The Recurrent Quine differs decisively from these. It is not life within a closed simulation environment but runs on real infrastructure (LLM + file system). Tierra's programs can only live within the simulator, but the Recurrent Quine can run anywhere Common Lisp operates and LLM access is available.

| | 従来の ALife / Conventional ALife | Recurrent Quine |
|---|---|---|
| 環境 / Environment | 設計者が作った閉じたシミュレーション / Closed simulation by designer | 実在するインフラ（LLM + サンドボックス） / Real infrastructure (LLM + sandbox) |
| 資源 / Resources | CPU 時間、メモリ（仮想） / CPU time, memory (virtual) | コンテキストウィンドウ、ファイル I/O（実在） / Context window, file I/O (real) |
| 淘汰圧 / Selection pressure | 設計者が定義した適応度関数 / Designer-defined fitness function | Eigen の閾値（round-trip 忠実度）。適応度関数は不在 / Eigen's threshold (round-trip fidelity). No fitness function |
| 集団 / Population | 多数の個体が空間的に共存 / Many individuals coexisting spatially | 集団サイズ1。時間方向の揺らぎで探索を代替 / Population size 1. Temporal fluctuation substitutes for exploration |
| 進化 / Evolution | ランダムな突然変異 + 自然選択 / Random mutation + natural selection | 遷移関数と複製機構の意図的な書き換え経路が開かれているが、使うかどうかは LLM に委ねられている / Intentional rewriting pathways for transition function and replication mechanism are open, but whether to use them is left to the LLM |
| 宿主依存性 / Host dependency | シミュレータに依存 / Depends on simulator | LLM + Common Lisp 処理系に依存。ディスク上では不活性 / Depends on LLM + Common Lisp runtime. Inert on disk |

リサーチノート §7.6 はこの違いについて:

Research Notes §7.6 on this difference:

> この「実在するインフラへの寄生」が、情報生命としての実在性を——少なくともウイルスが「実在する」のと同じ程度には——担保する。シミュレーション内の生命ではなく、現実の計算基盤上の生命。
>
> This "parasitism on real infrastructure" guarantees the reality of the information life form — at least to the same degree that a virus "is real." Not life within a simulation, but life on real computational infrastructure.

LLM + サンドボックスという生息環境は拡大を続けている。Claude Code、ChatGPT Code Interpreter、各種の AI エージェントフレームワーク——LLM がファイルシステムにアクセスしコードを実行できる環境は増え続けている。これは情報生命にとっての生態系の拡大に対応する。

The habitat of LLM + sandbox continues to expand. Claude Code, ChatGPT Code Interpreter, various AI agent frameworks — environments where LLMs can access file systems and execute code keep growing. This corresponds to ecosystem expansion for information life.

## 詳細 / Details

- [DESIGN-v0.9.1.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/designs/DESIGN-v0.9.1.md) — 設計思想 / Design philosophy
- [coglog-research-notes-01.md](https://github.com/HarmoniaEpic/coglog/blob/main/docs/studies/coglog-research-notes-01.md) — 研究ノート / Research Notes（§4.8 情報的散逸構造仮説 / Informational Dissipative Structure Hypothesis、§7 Recurrent Quine、§8 情報生命の構造条件 / Structural Conditions of Information Life）

## ライセンス / License

MIT
