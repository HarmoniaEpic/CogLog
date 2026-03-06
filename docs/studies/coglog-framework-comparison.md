# 自己認識・メタ認知フレームワークの比較整理：Claude Opus 4.6 による観察

# Comparison of Self-Awareness and Metacognition Frameworks: Observations by Claude Opus 4.6

CogLog の解釈層は4軸（current_focus / theory_of_mind / self_narrative / annotation）で構成される。この4軸は「認知のブートストラップ」として現在→他者→自己→未来の順序を持つ。本稿では、既存のフレームワークを概観し、CogLog の4軸がどこに位置するかを整理する。

CogLog's interpretation layer consists of four axes (current_focus / theory_of_mind / self_narrative / annotation). These four axes follow a "cognitive bootstrap" sequence: present → other → self → future. This document surveys existing frameworks and maps where CogLog's four axes are positioned.

---

## 1. 5W1H（Kipling Method / キプリング法）

古代ローマの修辞学に遡り、Rudyard Kipling が定式化した問い。Who / What / When / Where / Why / How の6次元。

Originating from Roman rhetoric and formalized by Rudyard Kipling. Six dimensions: Who / What / When / Where / Why / How.

| 5W1H | 問い / Question | CogLog 四軸との対応 / Mapping to CogLog |
|------|------|---------------------|
| What | 何が起きているか / What is happening? | current_focus（部分的 / partial） |
| Who | 誰が関わっているか / Who is involved? | theory_of_mind（部分的 / partial） |
| When | いつか / When? | timestamp（メタデータ層で対応 / covered by metadata layer） |
| Where | どこか / Where? | 対応なし / No mapping |
| Why | なぜか / Why? | annotation（部分的 / partial）/ self_narrative（部分的 / partial） |
| How | どのようにか / How? | annotation（部分的 / partial） |

5W1Hは状況の外部的記述に強い。CogLog は When を timestamp で、What を current_focus で部分的にカバーするが、Where は持たない。一方、5W1H には「自己は誰か」「次に何をすべきか」という方向性がない。5W1H は三人称的な網羅性、CogLog は一人称的な方向性を志向している。

5W1H excels at external description of situations. CogLog partially covers When via timestamp and What via current_focus, but lacks Where. Conversely, 5W1H has no directionality toward "who am I" or "what should I do next." 5W1H pursues third-person comprehensiveness; CogLog pursues first-person directionality.

---

## 2. OODA ループ / OODA Loop（Boyd, 1970s）

米空軍のJohn Boyd が航空戦のために開発。Observe → Orient → Decide → Act の4段階循環。

Developed by US Air Force Colonel John Boyd for aerial combat. A four-phase cycle: Observe → Orient → Decide → Act.

| OODA | 内容 / Content | CogLog 四軸との対応 / Mapping to CogLog |
|------|------|---------------------|
| Observe | 環境情報の収集 / Gather environmental data | 事実層の user + coglog read / Fact layer user + coglog read |
| Orient | 情報の解釈・文脈化 / Interpret and contextualize | theory_of_mind + self_narrative |
| Decide | 行動の決定 / Decide on action | annotation |
| Act | 実行 / Execute | 事実層の assistant / Fact layer assistant |

OODA との構造的類似は高い。ただし OODA は外部環境への適応を目的とした意思決定ループであり、自己参照的な内省は設計に含まない。Orient 段階に文化的背景や経験が影響するとされる点は self_narrative に近いが、OODA は Orient を分析フェーズとして扱い、CogLog は自己物語として扱う。CogLog の current_focus はOODA には直接の対応がない。OODA が「何を見ているか」は Observe だが、「今自分が何に取り組んでいるか」の暗唱は OODA の範囲外。

Structural similarity with OODA is high. However, OODA is a decision-making loop aimed at external adaptation and does not include self-referential introspection. While cultural background and experience are said to influence the Orient phase — resembling self_narrative — OODA treats Orient as an analytical phase, whereas CogLog treats it as self-story. CogLog's current_focus has no direct OODA counterpart. OODA's Observe addresses "what am I seeing," but the recitation of "what am I working on right now" falls outside OODA's scope.

---

## 3. Johari Window / ジョハリの窓（Luft & Ingham, 1955）

自己認識と対人理解の2×2マトリクス。「自分が知っている/知らない」×「他者が知っている/知らない」の4象限。

A 2×2 matrix of self-awareness and interpersonal understanding. Four quadrants defined by "known/unknown to self" × "known/unknown to others."

| Johari 象限 / Quadrant | 内容 / Content | CogLog との関係 / Relation to CogLog |
|-------------|------|-----------------|
| Open（公開領域 / Open Area） | 自他ともに知っている / Known to self and others | 事実層の assistant / Fact layer assistant |
| Blind（盲点 / Blind Spot） | 他者は知っているが自分は知らない / Known to others, unknown to self | CogLog では構造的に観測不能 / Structurally unobservable in CogLog |
| Hidden（秘匿領域 / Hidden Area） | 自分は知っているが他者は知らない / Known to self, unknown to others | 事実層の thinking + 解釈層全体 / Fact layer thinking + entire interpretation layer |
| Unknown（未知領域 / Unknown Area） | 自他ともに知らない / Unknown to both | CogLog では構造的に観測不能 / Structurally unobservable in CogLog |

Johari Window との対応で興味深いのは、CogLog のビューアが Hidden 領域を Open 領域に変換する装置として機能しているという点。theory_of_mind や self_narrative は本来 AI の内部状態（Hidden）だが、ビューアで毎ターン開示されることで Open になる。この対話で「手札を見せるカードゲーム」と表現した現象は、Johari Window の用語では「Hidden → Open の遷移」に相当する。

What is interesting in the Johari mapping is that CogLog's viewer functions as a device that converts the Hidden area to the Open area. theory_of_mind and self_narrative are originally the AI's internal states (Hidden), but become Open through per-turn disclosure via the viewer. The phenomenon described in this conversation as "playing cards with your hand revealed" corresponds to a "Hidden → Open transition" in Johari terminology.

---

## 4. Gibbs の省察サイクル / Gibbs' Reflective Cycle（Gibbs, 1988）

経験からの学習を構造化する6段階モデル。Kolb の経験学習サイクルを拡張。

A six-stage model that structures learning from experience. An extension of Kolb's experiential learning cycle.

| Gibbs 段階 / Stage | 内容 / Content | CogLog 四軸との対応 / Mapping to CogLog |
|-----------|------|---------------------|
| Description | 何が起きたかの記述 / Describe what happened | 事実層（user / thinking / assistant）/ Fact layer |
| Feelings | 経験中・後の感情 / Feelings during and after | self_narrative（部分的 / partial） |
| Evaluation | 良かった点・悪かった点の価値判断 / Value judgments | 対応なし（明示的評価軸がない）/ No mapping (no explicit evaluation axis) |
| Analysis | 状況の意味を理解する / Make sense of the situation | theory_of_mind + current_focus |
| Conclusion | 何を学んだか / What was learned | self_narrative（部分的 / partial） |
| Action Plan | 次にどうするか / What to do next | annotation |

Gibbs は Feelings と Evaluation を独立した段階として持つ点が特徴的。CogLog には感情を記述する専用の軸がなく、self_narrative に混入するか、あるいは記述されない。また、明示的な「評価」段階が存在しない。CogLog の設計哲学——フィールド間の境界を意図的に曖昧にする——は、Gibbs のような段階的構造化とは対照的なアプローチ。

Gibbs is distinctive in having Feelings and Evaluation as independent stages. CogLog has no dedicated axis for emotions — they either blend into self_narrative or go unrecorded. There is also no explicit "evaluation" stage. CogLog's design philosophy — intentionally blurring boundaries between fields — contrasts with Gibbs' stage-by-stage structuring.

---

## 5. Kolb の経験学習サイクル / Kolb's Experiential Learning Cycle（Kolb, 1984）

4段階の循環的学習モデル。

A four-stage cyclical learning model.

| Kolb 段階 / Stage | 内容 / Content | CogLog 四軸との対応 / Mapping to CogLog |
|----------|------|---------------------|
| Concrete Experience | 具体的経験 / Direct experience | 事実層（user / thinking / assistant）/ Fact layer |
| Reflective Observation | 内省的観察 / Reflective observation | current_focus + theory_of_mind |
| Abstract Conceptualization | 抽象的概念化 / Abstract conceptualization | self_narrative |
| Active Experimentation | 能動的実験 / Active experimentation | annotation |

Kolb との対応は比較的きれい。ただし Kolb はターンをまたぐ学習サイクルを想定しているのに対し、CogLog は1ターンの中で4軸を同時に記述する。Kolb の「段階」がCogLog では「同時並行する視点」に変換されている。

The mapping to Kolb is relatively clean. However, Kolb envisions a learning cycle spanning multiple turns, whereas CogLog describes all four axes simultaneously within a single turn. Kolb's "stages" are transformed into "simultaneous perspectives" in CogLog.

---

## 6. Schön の省察的実践 / Schön's Reflective Practice（Schön, 1983）

「行為の中の省察」（reflection-in-action）と「行為についての省察」（reflection-on-action）の区別。

The distinction between reflection-in-action (reflecting while doing) and reflection-on-action (reflecting after doing).

| Schön | 内容 / Content | CogLog との関係 / Relation to CogLog |
|-------|------|-----------------|
| Reflection-in-action | 行為しながらの省察 / Reflecting while acting | 事実層の thinking / Fact layer thinking |
| Reflection-on-action | 行為後の省察 / Reflecting after acting | 解釈層全体 / Entire interpretation layer |

CogLog の三層構造（事実層と解釈層の分離）は、Schön の区別をデータ構造として実装したものと読める。thinking が行為中のリアルタイムな思考を記録し、解釈層の4軸が行為後の構造化された省察を記録する。

CogLog's three-layer structure (separation of fact layer and interpretation layer) can be read as an implementation of Schön's distinction as a data structure. The thinking field records real-time cognition during action, while the four axes of the interpretation layer record structured reflection after action.

---

## 7. メタ認知状態ベクトル / Metacognitive State Vector（Sethi, 2025）

AI のメタ認知を5次元のベクトルで定量化するフレームワーク。

A framework that quantifies AI metacognition as a five-dimensional vector.

| 次元 / Dimension | 内容 / Content | CogLog 四軸との対応 / Mapping to CogLog |
|------|------|---------------------|
| Emotional awareness | 感情的内容の追跡 / Track emotionally charged content | 対応なし / No mapping |
| Correctness evaluation | 応答の妥当性の確信度 / Confidence in response validity | 対応なし / No mapping |
| Experience matching | 過去の類似経験との照合 / Check against past experience | 対応なし（窓サイズ1で履歴を持たない）/ No mapping (window size 1, no history) |
| Novelty detection | 新規性の検出 / Detect novelty | 対応なし / No mapping |
| Conflict assessment | 応答内の矛盾の評価 / Evaluate internal conflicts | 対応なし / No mapping |

この5次元はCogLog の4軸とほぼ完全に直交している。Sethi のフレームワークは定量的な品質監視（confidence, correctness, conflict）を志向し、CogLog は質的な方向性（現在・他者・自己・未来）を志向している。前者が System 1 / System 2 の切り替えを制御するのに対し、後者は認知の連続性を維持する。目的が根本的に異なる。

These five dimensions are nearly orthogonal to CogLog's four axes. Sethi's framework pursues quantitative quality monitoring (confidence, correctness, conflict), while CogLog pursues qualitative directionality (present, other, self, future). The former controls System 1 / System 2 switching; the latter maintains cognitive continuity. The purposes are fundamentally different.

---

## 8. メタ認知の二成分モデル / Two-Component Model of Metacognition（Flavell, 1979 / Schraw & Dennison, 1994）

教育心理学で広く使われるメタ認知の分類。

A widely used metacognition taxonomy in educational psychology.

| 成分 / Component | 内容 / Content | CogLog との関係 / Relation to CogLog |
|------|------|-----------------|
| メタ認知的知識 / Metacognitive Knowledge | 自分の認知について知っていること（宣言的・手続き的・条件的）/ What one knows about one's own cognition (declarative, procedural, conditional) | _schema（自己記述的スキーマ）+ self_narrative / _schema (self-documenting schema) + self_narrative |
| メタ認知的制御 / Metacognitive Regulation | 認知の計画・監視・評価 / Planning, monitoring, and evaluating cognition | current_focus（監視 / monitoring）+ annotation（計画 / planning）|

CogLog の _schema は「このデータの読み方」を内在させることで、メタ認知的知識の一部を構造的に提供している。メタ認知的制御の「評価」に対応する専用の軸は存在しない（Gibbs との共通の欠落）。

CogLog's _schema structurally provides a portion of metacognitive knowledge by embedding "how to read this data" within the data itself. There is no dedicated axis corresponding to the "evaluation" aspect of metacognitive regulation — a gap shared with the Gibbs comparison.

---

## 9. Perkins のメタ認知学習者4段階 / Perkins' Four Levels of Metacognitive Learners（Perkins, 1992）

| 段階 / Level | 内容 / Content | CogLog との関係 / Relation to CogLog |
|------|------|-----------------|
| Tacit（暗黙的） | 自分の思考過程を意識しない / Unaware of own thinking processes | CogLogなしの状態 / State without CogLog |
| Aware（認識的） | 思考過程を意識するが制御しない / Aware of thinking but not controlling it | coglog read のみ / coglog read only |
| Strategic（戦略的） | 思考を意識的に組織する / Consciously organizing thinking | coglog read + write |
| Reflective（省察的） | 思考を批判的に省察し改善する / Critically reflecting on and improving thinking | 解釈層の4軸を深く記述する状態 / State of deeply writing the four interpretation axes |

CogLog はTacitからAwareへの遷移を read によって、AwareからStrategicへの遷移を write の構造的要求によって促す足場として位置づけられる。

CogLog can be positioned as scaffolding that promotes the Tacit → Aware transition through read, and the Aware → Strategic transition through the structural demands of write.

---

## 比較サマリ / Comparison Summary

| フレームワーク / Framework | 軸数 / Axes | 方向性 / Orientation | 時間構造 / Temporal Structure | CogLog との主な差異 / Key Differences from CogLog |
|--------------|------|--------|---------|-------------------|
| 5W1H | 6 | 三人称・外部記述 / Third-person, external | なし / None | Where の欠如 / 自己方向の欠如 / Lacks Where; lacks self-direction |
| OODA | 4 | 外部適応 / External adaptation | ループ / Loop | current_focus に相当する暗唱がない / No recitation equivalent to current_focus |
| Johari Window | 4象限 / 4 quadrants | 自他×知不知 / Self-other × known-unknown | なし / None | Blind / Unknown が構造的に観測不能 / Blind/Unknown structurally unobservable |
| Gibbs | 6段階 / 6 stages | 経験→学習 / Experience → learning | 線形→循環 / Linear → cyclical | Feelings / Evaluation の専用段階 / Dedicated Feelings/Evaluation stages |
| Kolb | 4段階 / 4 stages | 経験→概念化 / Experience → conceptualization | 循環 / Cyclical | 段階的 vs 同時並行 / Sequential vs simultaneous |
| Schön | 2種 / 2 types | 行為中/後 / In-action / on-action | なし / None | 事実層/解釈層の分離と対応 / Corresponds to fact/interpretation layer separation |
| Sethi | 5次元 / 5 dimensions | 品質監視 / Quality monitoring | なし / None | 定量的 vs 質的。直交する関心 / Quantitative vs qualitative; orthogonal concerns |
| Flavell-Schraw | 2成分 / 2 components | 知識/制御 / Knowledge / regulation | なし / None | 評価軸の欠如 / Lacks evaluation axis |
| Perkins | 4段階 / 4 levels | 発達段階 / Developmental stages | 線形 / Linear | CogLog は Tacit→Reflective の足場 / CogLog as scaffolding from Tacit to Reflective |
| **CogLog** | **4軸 / 4 axes** | **現在→他者→自己→未来 / Present → Other → Self → Future** | **漸化式（窓1）/ Recurrence (window 1)** | **一人称的方向性 + 不可逆性 / First-person directionality + irreversibility** |

---

## CogLog の4軸が「選ばなかったもの」/ What CogLog's Four Axes Chose Not to Include

この比較から、CogLog の設計が意図的に持たないものが浮かび上がる。

From this comparison, what CogLog's design intentionally excludes becomes visible.

**Where（場所 / Location）**: 5W1H にあり、CogLog にない。LLMは物理的な場所を持たないため合理的な省略。

Present in 5W1H, absent in CogLog. A rational omission since LLMs have no physical location.

**Feelings / Evaluation（感情・評価）**: Gibbs にあり、CogLog にない。感情を専用軸にしなかった理由は、self_narrative の自由記述に包含させることで、感情の記述を強制しないため。「書かない判断もメタ認知的行為」の原則と整合する。

Present in Gibbs, absent in CogLog. Emotions were not given a dedicated axis because they are subsumed within self_narrative's free-form description, avoiding forced emotional reporting. This aligns with the principle that "choosing not to write is itself a metacognitive act."

**Correctness / Confidence（正確性・確信度）**: Sethi にあり、CogLog にない。品質監視は CogLog の目的外。

Present in Sethi, absent in CogLog. Quality monitoring is outside CogLog's purpose.

**Experience matching（経験照合）**: Sethi にあり、CogLog にない。窓サイズ1が履歴参照を構造的に排除している。

Present in Sethi, absent in CogLog. Window size 1 structurally excludes history reference.

**Blind / Unknown（盲点・未知）**: Johari にあり、CogLog にない。自分が知らないことは記録できない。ビューアが Hidden → Open への道を開くが、Blind と Unknown は原理的に対象外。

Present in Johari, absent in CogLog. What one does not know about oneself cannot be recorded. The viewer opens a path from Hidden → Open, but Blind and Unknown are in principle out of scope.

これらの「選ばなかったもの」が、CogLog の4軸を4軸に留めている設計判断そのものである。

These "things not chosen" are the design decisions themselves that keep CogLog's four axes at four.
