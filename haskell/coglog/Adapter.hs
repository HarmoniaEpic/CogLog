{-# LANGUAGE ScopedTypeVariables #-}
module Main where

import CogLog
import Data.Char (isSpace, isDigit, isHexDigit)
import Data.List (intercalate, isPrefixOf, isSuffixOf)
import Data.Time (UTCTime, getCurrentTime, formatTime, defaultTimeLocale)
import Data.Time.Format (parseTimeM)
import Control.Exception (IOException, catch)
import System.Directory (getHomeDirectory, getCurrentDirectory,
                         createDirectoryIfMissing, doesFileExist, removeFile)
import System.Environment (getArgs, lookupEnv)
import qualified System.FilePath as FP
import System.IO (hPutStrLn, hPutStr, hGetContents, stderr, hSetEncoding,
                   stdin, stdout, utf8, withFile, IOMode(..))

-- ═══════════════════════════════════════════════════════════
-- JSON serialization (hand-written)
-- ═══════════════════════════════════════════════════════════

-- | Escape a string for JSON serialization.
escapeJson :: String -> String
escapeJson = concatMap esc
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\t' = "\\t"
    esc c    = [c]

-- | Wrap a string as a JSON string literal.
jsonStr :: String -> String
jsonStr s = "\"" ++ escapeJson s ++ "\""

-- | Generate indentation spaces.
indent :: Int -> String
indent n = replicate (n * 2) ' '

-- | Convert a Schema to a JSON string.
schemaToJson :: Int -> Schema -> String
schemaToJson n s = unlines' $
  [ indent n ++ "\"_schema\": {"
  , indent (n+1) ++ "\"version\": " ++ jsonStr (sVersion s) ++ ","
  , indent (n+1) ++ "\"fact_layer\": {"
  ] ++ kvLines (n+2) (sFactLayer s) ++
  [ indent (n+1) ++ "},"
  , indent (n+1) ++ "\"interpretation_layer\": {"
  ] ++ kvLines (n+2) (sInterpLayer s) ++
  [ indent (n+1) ++ "},"
  , indent (n+1) ++ "\"constraints\": {"
  ] ++ kvLines (n+2) (sConstraints s) ++
  [ indent (n+1) ++ "}"
  , indent n ++ "}"
  ]
  where
    kvLines d kvs =
      let formatted = map (\(k,v) -> indent d ++ jsonStr k ++ ": " ++ jsonStr v) kvs
      in  addCommas formatted

-- | Append commas to all elements except the last.
addCommas :: [String] -> [String]
addCommas []     = []
addCommas [x]    = [x]
addCommas (x:xs) = (x ++ ",") : addCommas xs

-- | Like 'unlines' but without a trailing newline.
unlines' :: [String] -> String
unlines' = intercalate "\n"

-- | Convert Layers to JSON.
layersToJson :: Int -> Layers -> String
layersToJson n l = unlines'
  [ indent n ++ "\"layers\": {"
  , indent (n+1) ++ "\"user\": " ++ jsonStr (unNonEmptyText (lUser l)) ++ ","
  , indent (n+1) ++ "\"thinking\": " ++ jsonStr (unNonEmptyText (lThinking l)) ++ ","
  , indent (n+1) ++ "\"assistant\": " ++ jsonStr (unNonEmptyText (lAssistant l))
  , indent n ++ "}"
  ]

-- | Convert an Entry to a JSON string.
entryToJson :: Entry -> String
entryToJson e = unlines'
  [ "{"
  , schemaToJson 1 (eSchema e) ++ ","
  , indent 1 ++ "\"turn_id\": " ++ show (eTurnId e) ++ ","
  , indent 1 ++ "\"timestamp\": " ++ jsonStr (fmtTime (eTimestamp e)) ++ ","
  , layersToJson 1 (eLayers e) ++ ","
  , indent 1 ++ "\"current_focus\": " ++ jsonStr (eCurrentFocus e) ++ ","
  , indent 1 ++ "\"theory_of_mind\": " ++ jsonStr (eTheoryOfMind e) ++ ","
  , indent 1 ++ "\"self_narrative\": " ++ jsonStr (eSelfNarrative e) ++ ","
  , indent 1 ++ "\"annotation\": " ++ jsonStr (eAnnotation e)
  , "}"
  ]
  where
    fmtTime = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"


-- ═══════════════════════════════════════════════════════════
-- JSON parsing (hand-written, recursive descent)
-- ═══════════════════════════════════════════════════════════

-- | Simple JSON value type.
data JValue
  = JString String
  | JNumber Int
  | JObject [(String, JValue)]
  | JNull
  deriving (Show)

type Parser a = String -> Either String (a, String)

-- | Skip whitespace.
skipWS :: String -> String
skipWS = dropWhile isSpace

-- | Consume an expected character.
expect :: Char -> Parser ()
expect c s = case skipWS s of
  (x:xs) | x == c -> Right ((), xs)
  rest -> Left $ "expected '" ++ [c] ++ "' but got: " ++ take 20 rest
  
-- | Parse a JSON string.
parseJString :: Parser String
parseJString s0 = case skipWS s0 of
  ('"':rest) -> go rest ""
  other -> Left $ "expected '\"' but got: " ++ take 20 other
  where
    go [] _         = Left "unterminated string"
    go ('"':rest) acc = Right (reverse acc, rest)
    go ('\\':c:rest) acc = case c of
      '"'  -> go rest ('"' : acc)
      '\\' -> go rest ('\\' : acc)
      'n'  -> go rest ('\n' : acc)
      't'  -> go rest ('\t' : acc)
      'u'  -> parseUnicode rest acc
      _    -> go rest (c : acc)
    go (c:rest) acc = go rest (c : acc)
    parseUnicode rest acc =
      let (hex, rest') = splitAt 4 rest
      in if length hex == 4 && all isHexDigit hex
         then go rest' (toEnum (read ("0x" ++ hex)) : acc)
         else Left "invalid unicode escape"

-- | Parse a JSON number (integer).
parseJNumber :: Parser Int
parseJNumber s0 =
  let s = skipWS s0
      (neg, s') = if not (null s) && head s == '-' then (True, tail s) else (False, s)
      (digits, rest) = span isDigit s'
  in if null digits
     then Left $ "expected number but got: " ++ take 20 s
     else Right ((if neg then negate else id) (read digits), rest)

-- | Parse a JSON value.
parseJValue :: Parser JValue
parseJValue s0 = case skipWS s0 of
  ('"':_)  -> do (v, r) <- parseJString s0; Right (JString v, r)
  ('{':_)  -> do (v, r) <- parseJObject s0; Right (JObject v, r)
  ('n':'u':'l':'l':r) -> Right (JNull, r)
  _ -> do (v, r) <- parseJNumber s0; Right (JNumber v, r)

-- | Parse a JSON object.
parseJObject :: Parser [(String, JValue)]
parseJObject s0 = do
  (_, s1) <- expect '{' s0
  case skipWS s1 of
    ('}':rest) -> Right ([], rest)
    _ -> parsePairs s1
  where
    parsePairs s = do
      (k, s1) <- parseJString s
      (_, s2) <- expect ':' s1
      (v, s3) <- parseJValue s2
      case skipWS s3 of
        (',':rest) -> do
          (pairs, s4) <- parsePairs rest
          Right ((k,v) : pairs, s4)
        ('}':rest) -> Right ([(k,v)], rest)
        other -> Left $ "expected ',' or '}' but got: " ++ take 20 other

-- | Look up a field in a JValue object.
jLookup :: String -> [(String, JValue)] -> Either String JValue
jLookup k kvs = case lookup k kvs of
  Just v  -> Right v
  Nothing -> Left $ "missing field: " ++ k

-- | Extract a String from a JValue.
jStr :: String -> [(String, JValue)] -> Either String String
jStr k kvs = do
  v <- jLookup k kvs
  case v of
    JString s -> Right s
    _         -> Left $ k ++ " is not a string"

-- | Extract an Int from a JValue.
jInt :: String -> [(String, JValue)] -> Either String Int
jInt k kvs = do
  v <- jLookup k kvs
  case v of
    JNumber n -> Right n
    _         -> Left $ k ++ " is not a number"

-- | Extract an Object from a JValue.
jObj :: String -> [(String, JValue)] -> Either String [(String, JValue)]
jObj k kvs = do
  v <- jLookup k kvs
  case v of
    JObject o -> Right o
    _         -> Left $ k ++ " is not an object"

-- | Parse a timestamp, trying multiple formats.
parseTimestamp :: String -> Either String UTCTime
parseTimestamp s = tryFormats formats
  where
    -- Normalize +00:00 to Z
    normalized
      | "+00:00" `isSuffixOf` s = take (length s - 6) s ++ "Z"
      | otherwise = s
    -- Strip microseconds (.123456Z -> Z)
    stripped = case break (== '.') normalized of
      (pre, '.':rest) -> pre ++ dropWhile (\c -> isDigit c) rest
      _               -> normalized
    formats =
      [ ("%Y-%m-%dT%H:%M:%SZ", stripped)
      , ("%Y-%m-%dT%H:%M:%S%QZ", normalized)
      , ("%Y-%m-%dT%H:%M:%SZ", normalized)
      ]
    tryFormats [] = Left $ "invalid timestamp: " ++ s
    tryFormats ((fmt,inp):rest) =
      case parseTimeM True defaultTimeLocale fmt inp of
        Just t  -> Right t
        Nothing -> tryFormats rest

-- | Parse an Entry from a JSON string.
parseEntry :: String -> Either String Entry
parseEntry src = do
  (top, _) <- parseJObject src
  -- turn_id, timestamp
  tid <- jInt "turn_id" top
  tsStr <- jStr "timestamp" top
  ts <- parseTimestamp tsStr
  -- layers
  layersObj <- jObj "layers" top
  uStr <- jStr "user" layersObj
  tStr <- jStr "thinking" layersObj
  aStr <- jStr "assistant" layersObj
  u <- case mkNonEmptyText uStr of
    Right v -> Right v
    Left (ValidationError e) -> Left $ "layers.user: " ++ e
  t <- case mkNonEmptyText tStr of
    Right v -> Right v
    Left (ValidationError e) -> Left $ "layers.thinking: " ++ e
  a <- case mkNonEmptyText aStr of
    Right v -> Right v
    Left (ValidationError e) -> Left $ "layers.assistant: " ++ e
  -- interpretation
  cf <- jStr "current_focus" top
  tm <- jStr "theory_of_mind" top
  sn <- jStr "self_narrative" top
  an <- jStr "annotation" top
  Right Entry
    { eSchema        = coglogSchema
    , eTurnId        = tid
    , eTimestamp     = ts
    , eLayers        = Layers u t a
    , eCurrentFocus  = cf
    , eTheoryOfMind  = tm
    , eSelfNarrative = sn
    , eAnnotation    = an
    }

-- | Parse JSON input from stdin into RawArgs.
parseStdinArgs :: String -> Either String RawArgs
parseStdinArgs src = do
  (top, _) <- parseJObject src
  u  <- jStr "user" top
  t  <- jStr "thinking" top
  a  <- jStr "assistant" top
  cf <- jStr "current_focus" top
  tm <- jStr "theory_of_mind" top
  sn <- jStr "self_narrative" top
  an <- jStr "annotation" top
  Right RawArgs
    { rawUser = u, rawThinking = t, rawAssistant = a
    , rawCurrentFocus = cf, rawTheoryOfMind = tm
    , rawSelfNarrative = sn, rawAnnotation = an
    }


-- ═══════════════════════════════════════════════════════════
-- File I/O
-- ═══════════════════════════════════════════════════════════

-- | Return the default coglog file path.
-- Priority: COGLOG_DIR env > $HOME/.coglog > ./.coglog (final fallback)
defaultCoglogPath :: IO FilePath
defaultCoglogPath = do
  envDir <- lookupEnv "COGLOG_DIR"
  case envDir of
    Just d | not (null d) -> return (d FP.</> "current.json")
    _ -> do
      home <- getHomeDirectory `catch` (\(_ :: IOException) -> getCurrentDirectory)
      return (home FP.</> ".coglog" FP.</> "current.json")

-- | Read the coglog file.
readCoglog :: FilePath -> IO (Maybe Entry)
readCoglog path = do
  exists <- doesFileExist path
  if not exists
    then return Nothing
    else do
      content <- withFile path ReadMode $ \h -> do
        hSetEncoding h utf8
        c <- hGetContents h
        length c `seq` return c
      case parseEntry content of
        Right e -> return (Just e)
        Left _  -> return Nothing

-- | Write an entry to the coglog file.
writeCoglog :: FilePath -> Entry -> IO ()
writeCoglog path entry = do
  createDirectoryIfMissing True (FP.takeDirectory path)
  withFile path WriteMode $ \h -> do
    hSetEncoding h utf8
    hPutStr h (entryToJson entry ++ "\n")

-- | Clear (delete) the coglog file.
clearCoglog :: FilePath -> IO Bool
clearCoglog path = do
  exists <- doesFileExist path
  if exists
    then removeFile path >> return True
    else return False


-- ═══════════════════════════════════════════════════════════
-- CLI
-- ═══════════════════════════════════════════════════════════

main :: IO ()
main = do
  hSetEncoding stdin  utf8
  hSetEncoding stdout utf8
  allArgs <- getArgs
  -- Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
  (coglogPath, args) <- case allArgs of
    ("--coglog-dir":d:rest) -> return (d FP.</> "current.json", rest)
    _                       -> do { p <- defaultCoglogPath; return (p, allArgs) }
  case args of
    ["read"]  -> cmdRead  coglogPath
    ["write"] -> cmdWrite coglogPath
    ["clear"] -> cmdClear coglogPath
    _         -> putStrLn "usage: coglog-hs [--coglog-dir <path>] <read|write|clear>"

cmdRead :: FilePath -> IO ()
cmdRead path = do
  me <- readCoglog path
  case me of
    Nothing -> putStrLn "(no coglog found)"
    Just e  -> putStr (entryToJson e)

cmdWrite :: FilePath -> IO ()
cmdWrite path = do
  input <- getContents
  case parseStdinArgs input of
    Left err -> do
      hPutStrLn stderr ("coglog error: parse: " ++ err)
      fail ""
    Right raw ->
      case validateArgs raw of
        Left (ValidationError err) -> do
          hPutStrLn stderr ("coglog error: validation: " ++ err)
          fail ""
        Right wargs -> do
          prev <- readCoglog path
          now <- getCurrentTime
          let entry = advance prev wargs now
          writeCoglog path entry
          putStrLn ("coglog: turn " ++ show (eTurnId entry) ++ " written")

cmdClear :: FilePath -> IO ()
cmdClear path = do
  had <- clearCoglog path
  if had
    then putStrLn "coglog: cleared"
    else putStrLn "coglog: no existing coglog"
