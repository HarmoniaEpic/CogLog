CogLog — Haskell Pure Core

Annotations from the pure/impure separation in DESIGN-v0.9.1.md.
This file is Literate Haskell that GHC can compile directly.
Lines beginning with ">" are code. Everything else is prose.
The prose states the argument; the code proves it.


═══════════════════════════════════════════════════════════════
Chapter 1: The Recurrence Relation
═══════════════════════════════════════════════════════════════

The core of CogLog is the recurrence relation a_{n+1} = f(a_n, x_n).

f takes "the previous entry," "the current input," and "the current time,"
and returns "a new entry."

In the Python and Node.js versions, this f and file I/O
are conflated in a single write() function.
In Haskell, the type system does not permit that conflation.

advance constructs an Entry. writeCoglog writes an Entry to a file.
The two are separated by types; mixing them is a compile error.
This separation is not the designer's discipline — it is type enforcement.

> module CogLog (
>     -- Types
>     NonEmptyText, unNonEmptyText,
>     Schema(..), Layers(..), Entry(..), WriteArgs(..), RawArgs(..),
>     ValidationError(..),
>     -- Construction
>     mkNonEmptyText, validateArgs,
>     -- Core
>     advance, coglogSchema, schemaVersion
>   ) where
>
> import Data.Time (UTCTime)


═══════════════════════════════════════════════════════════════
Chapter 2: The World of Types
═══════════════════════════════════════════════════════════════

CogLog's data structure is composed of three layers.

  Metadata layer (_schema) — how to read this data
  Fact layer (layers)      — what happened
  Interpretation layer (4 fields) — how it was interpreted

The fact layer and interpretation layer have different validation rules.
  Fact layer: non-empty string required
  Interpretation layer: string required, empty acceptable

In the Common Lisp version, this distinction is enforced at runtime
by conditional branches in validate-args.
In the Haskell version, the type distinction enforces it at compile time.

NonEmptyText and String. The difference between these types
is the difference between the fact layer and the interpretation layer itself.

> newtype NonEmptyText = NonEmptyText String
>   deriving (Show, Eq)
>
> unNonEmptyText :: NonEmptyText -> String
> unNonEmptyText (NonEmptyText s) = s

The NonEmptyText constructor is not exported outside the module.
The only way to obtain a NonEmptyText from outside is mkNonEmptyText,
and that function rejects empty strings.
Non-export of the constructor is the key to type-driven validation.

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

WriteArgs represents "validated input."
The fact layer fields are NonEmptyText —
their non-emptiness is guaranteed by the type at construction time.
The interpretation layer fields are String — empty is acceptable.

> data WriteArgs = WriteArgs
>   { wUser          :: NonEmptyText
>   , wThinking      :: NonEmptyText
>   , wAssistant     :: NonEmptyText
>   , wCurrentFocus  :: String
>   , wTheoryOfMind  :: String
>   , wSelfNarrative :: String
>   , wAnnotation    :: String
>   } deriving (Show, Eq)

RawArgs represents "unvalidated input." All fields are String.
validateArgs attempts the conversion from RawArgs to WriteArgs.
The success or failure of this conversion is the validation result itself.

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
Chapter 3: validate — Declaring Constraints
═══════════════════════════════════════════════════════════════

mkNonEmptyText is the gatekeeper.
It rejects empty strings as Left and passes non-empty strings as Right.
Values that pass through this function are wrapped in NonEmptyText,
and subsequent code never needs to re-check for non-emptiness.

The type remembers the validation result. This is how Haskell guarantees.

> mkNonEmptyText :: String -> Either ValidationError NonEmptyText
> mkNonEmptyText "" = Left (ValidationError "non-empty string required")
> mkNonEmptyText s  = Right (NonEmptyText s)

validateArgs constructs WriteArgs from RawArgs.
The 3 fact layer fields pass through mkNonEmptyText,
while the 4 interpretation layer fields are accepted as plain Strings.

Through the Either monad, the entire computation short-circuits on first failure.
Only the success path reaches the construction of WriteArgs.

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
Chapter 4: _schema — Self-Describing Data
═══════════════════════════════════════════════════════════════

_schema is a structure for attaching "how to read this data" to the JSON.

In the Common Lisp version, the homoiconicity of S-expressions
showed that _schema is a natural consequence.

The Haskell version illuminates a different facet.
Because coglogSchema has the Schema type,
the declaration "this is metadata" is made at the type level.
It differs in type from Entry's other fields (String, Int, UTCTime, Layers),
and any mix-up becomes a compile error.

> schemaVersion :: String
> schemaVersion = "0.9.1"  -- @coglog-version
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
Chapter 5: advance — The Pure Core
═══════════════════════════════════════════════════════════════

advance corresponds to f in the recurrence relation. Reading the type signature:

  advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry

  Maybe Entry  — the previous entry (Nothing on the first call)
  WriteArgs    — the current input (already validated)
  UTCTime      — the current time (injected from outside)
  -> Entry     — the new entry

IO appears nowhere. advance is a pure function.

This is not the designer's intent — it is a proof by the type system.
If advance tried to obtain the current time on its own,
its return type would become IO Entry, and the type signature would expose it.
If it tried to write to a file, IO would similarly appear.
Purity cannot be hidden. Impurity cannot be hidden either. Types declare both.

The Python version's advance() is also pure in practice.
However, between "in practice" and "guaranteed by types"
lies the same distance as between testing and proof.

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
Appendix: The Significance of No IO in This Module
═══════════════════════════════════════════════════════════════

The letters "IO" appear nowhere in CogLog.lhs.
The only import is the UTCTime type from Data.Time.

This means that every function in CogLog.lhs is referentially transparent.
Call it with the same arguments, and it returns the same result every time.
It writes nothing to files. It sends nothing over the network.

IO first appears in Adapter.hs.
readCoglog :: IO (Maybe Entry)
writeCoglog :: Entry -> IO ()

This separation runs through CogLog's entire architecture.
While the Python version's write() combines advance + file writing,
in the Haskell version that combination is forbidden by the compiler.

Separation is not a choice. It is a necessity.
