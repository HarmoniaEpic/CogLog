CogLog v0.9.1 — Haskell 純粋核

DESIGN-v0.9.1.md の純粋/不純の分離からの注釈。
このファイルは GHC が直接コンパイルできる Literate Haskell である。
「>」で始まる行がコード。それ以外は散文。
散文が論旨を述べ、コードがそれを証明する。


═══════════════════════════════════════════════════════════════
第1章: 漸化式
═══════════════════════════════════════════════════════════════

CogLog の核は漸化式 a_{n+1} = f(a_n, x_n) である。

f は「前のエントリ」と「今の入力」と「現在時刻」を受け取り、
「新しいエントリ」を返す。

Python 版や Node.js 版では、この f とファイル I/O が
一つの write() 関数に混在している。
Haskell では型システムがその混在を許さない。

advance は Entry を構築する。writeCoglog は Entry をファイルに書く。
両者は型によって分離され、混合はコンパイルエラーになる。
この分離は設計者の規律ではなく、型の強制である。

> module CogLog (
>     -- 型
>     NonEmptyText, unNonEmptyText,
>     Schema(..), Layers(..), Entry(..), WriteArgs(..), RawArgs(..),
>     ValidationError(..),
>     -- 構築
>     mkNonEmptyText, validateArgs,
>     -- 核
>     advance, coglogSchema, schemaVersion
>   ) where
>
> import Data.Time (UTCTime)


═══════════════════════════════════════════════════════════════
第2章: 型の世界
═══════════════════════════════════════════════════════════════

CogLog のデータ構造は三つの層で構成される。

  メタデータ層 (_schema) — このデータの読み方
  事実層 (layers)        — 何があったか
  解釈層 (4フィールド)   — それをどう読んだか

事実層と解釈層はバリデーション規則が異なる。
  事実層: 非空文字列必須
  解釈層: 文字列必須、空許容

Common Lisp 版では、この区別は validate-args の条件分岐が実行時に担う。
Haskell 版では、型の区別がコンパイル時に担う。

NonEmptyText と String。この型の違いが、
事実層と解釈層の違いそのものである。

> newtype NonEmptyText = NonEmptyText String
>   deriving (Show, Eq)
>
> unNonEmptyText :: NonEmptyText -> String
> unNonEmptyText (NonEmptyText s) = s

NonEmptyText のコンストラクタはモジュール外に公開しない。
外部から NonEmptyText を得る唯一の方法は mkNonEmptyText であり、
その関数は空文字列を拒否する。
コンストラクタの非公開が、型によるバリデーションの鍵である。

> data Layers = Layers
>   { lUser      :: NonEmptyText
>   , lThinking  :: NonEmptyText
>   , lAssistant :: NonEmptyText
>   } deriving (Show, Eq)
>
> data Schema = Schema
>   { sVersion    :: String
>   , sFactLayer  :: [(String, String)]
>   , sInterpLayer :: [(String, String)]
>   , sConstraints :: [(String, String)]
>   } deriving (Show, Eq)
>
> data Entry = Entry
>   { eSchema        :: Schema
>   , eTurnId        :: Int
>   , eTimestamp     :: UTCTime
>   , eLayers        :: Layers
>   , eCurrentFocus  :: String
>   , eTheoryOfMind  :: String
>   , eSelfNarrative :: String
>   , eAnnotation    :: String
>   } deriving (Show, Eq)

WriteArgs は「バリデーション済みの入力」を表す。
事実層のフィールドは NonEmptyText——
構築時点で非空であることが型によって保証されている。
解釈層のフィールドは String——空を許容する。

> data WriteArgs = WriteArgs
>   { wUser          :: NonEmptyText
>   , wThinking      :: NonEmptyText
>   , wAssistant     :: NonEmptyText
>   , wCurrentFocus  :: String
>   , wTheoryOfMind  :: String
>   , wSelfNarrative :: String
>   , wAnnotation    :: String
>   } deriving (Show, Eq)

RawArgs は「未検証の入力」を表す。全フィールドが String。
validateArgs が RawArgs から WriteArgs への変換を試みる。
この変換の成否が、バリデーションの結果そのものである。

> data RawArgs = RawArgs
>   { rawUser          :: String
>   , rawThinking      :: String
>   , rawAssistant     :: String
>   , rawCurrentFocus  :: String
>   , rawTheoryOfMind  :: String
>   , rawSelfNarrative :: String
>   , rawAnnotation    :: String
>   } deriving (Show, Eq)
>
> data ValidationError = ValidationError String
>   deriving (Show, Eq)


═══════════════════════════════════════════════════════════════
第3章: validate — 制約の宣言
═══════════════════════════════════════════════════════════════

mkNonEmptyText はゲートキーパーである。
空文字列を Left として拒否し、非空文字列を Right として通す。
この関数を通過した値は NonEmptyText に包まれ、
以後のコードは非空性を再検査する必要がない。

型がバリデーション結果を記憶する。これが Haskell の保証の形。

> mkNonEmptyText :: String -> Either ValidationError NonEmptyText
> mkNonEmptyText "" = Left (ValidationError "non-empty string required")
> mkNonEmptyText s  = Right (NonEmptyText s)

validateArgs は RawArgs から WriteArgs を構築する。
事実層の3フィールドが mkNonEmptyText を通過し、
解釈層の4フィールドは String のまま受け入れる。

Either モナドにより、最初の失敗で処理全体が中断する。
成功パスのみが WriteArgs の構築に到達する。

> validateArgs :: RawArgs -> Either ValidationError WriteArgs
> validateArgs raw = do
>   u <- withField "user"      $ mkNonEmptyText (rawUser raw)
>   t <- withField "thinking"  $ mkNonEmptyText (rawThinking raw)
>   a <- withField "assistant" $ mkNonEmptyText (rawAssistant raw)
>   Right (WriteArgs u t a
>     (rawCurrentFocus raw) (rawTheoryOfMind raw)
>     (rawSelfNarrative raw) (rawAnnotation raw))
>   where
>     withField name (Left _) =
>       Left (ValidationError ("missing required field: " ++ name))
>     withField _ (Right v) = Right v


═══════════════════════════════════════════════════════════════
第4章: _schema — データの自己記述
═══════════════════════════════════════════════════════════════

_schema は JSON に「このデータの読み方」を添付するための構造である。

Common Lisp 版では、S式のホモイコニシティにより
_schema が自明な帰結であることを示した。

Haskell 版では別の面を照射する。
coglogSchema が Schema 型を持つことで、
「これはメタデータである」という宣言が型レベルで行われる。
Entry の他のフィールド（String, Int, UTCTime, Layers）とは
型が異なり、取り違えはコンパイルエラーになる。

> schemaVersion :: String
> schemaVersion = "0.9.1"
>
> coglogSchema :: Schema
> coglogSchema = Schema
>   { sVersion = schemaVersion
>   , sFactLayer =
>       [ ("user",      "non-empty string required — user's original utterance")
>       , ("thinking",  "non-empty string required — AI's full thinking process")
>       , ("assistant", "non-empty string required — AI's original output")
>       ]
>   , sInterpLayer =
>       [ ("current_focus",  "string required, empty OK — present: what am I working on?")
>       , ("theory_of_mind", "string required, empty OK — other: what is the user's state?")
>       , ("self_narrative", "string required, empty OK — self: who am I in this moment?")
>       , ("annotation",     "string required, empty OK — future: what should I do next?")
>       ]
>   , sConstraints =
>       [ ("window_size",          "1 turn (overwritten each write)")
>       , ("interpretation_empty", "choosing not to write is itself a metacognitive act")
>       ]
>   }


═══════════════════════════════════════════════════════════════
第5章: advance — 純粋な核
═══════════════════════════════════════════════════════════════

advance は漸化式の f に対応する。型シグネチャを読む:

  advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry

  Maybe Entry  — 前のエントリ（初回は Nothing）
  WriteArgs    — 今の入力（バリデーション済み）
  UTCTime      — 現在時刻（外部から注入される）
  → Entry      — 新しいエントリ

IO はどこにも現れない。advance は純粋関数である。

これは設計者の意図ではなく、型システムによる証明である。
もし advance が現在時刻を自ら取得しようとすれば、
戻り値は IO Entry になり、型シグネチャがそれを暴露する。
もしファイルに書き込もうとすれば、同様に IO が現れる。
純粋性は隠せない。不純性も隠せない。型が両方を宣言する。

Python 版の advance() も事実上は純粋である。
しかし「事実上」と「型による保証」の間には、
テストと証明の間と同じくらいの距離がある。

> advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry
> advance prev args now = Entry
>   { eSchema        = coglogSchema
>   , eTurnId        = maybe 1 ((+ 1) . eTurnId) prev
>   , eTimestamp     = now
>   , eLayers        = Layers (wUser args) (wThinking args) (wAssistant args)
>   , eCurrentFocus  = wCurrentFocus args
>   , eTheoryOfMind  = wTheoryOfMind args
>   , eSelfNarrative = wSelfNarrative args
>   , eAnnotation    = wAnnotation args
>   }


═══════════════════════════════════════════════════════════════
補遺: このモジュールに IO がないことの意味
═══════════════════════════════════════════════════════════════

CogLog.lhs のどこにも IO という文字は現れない。
import するのは Data.Time から UTCTime 型ただ一つ。

このことは、CogLog.lhs のすべての関数が参照透過であることを意味する。
同じ引数で呼べば、何度呼んでも同じ結果が返る。
ファイルに何も書かない。ネットワークに何も送らない。

Adapter.hs で初めて IO が登場する。
readCoglog :: IO (Maybe Entry)
writeCoglog :: Entry -> IO ()

この分離は CogLog のアーキテクチャ全体に通底する。
Python 版の write() が advance + ファイル書き込みを兼ねているのに対し、
Haskell 版ではその兼任がコンパイラによって禁止されている。

分離は選択ではない。必然である。
