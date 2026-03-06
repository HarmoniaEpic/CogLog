module Main where

import CogLog
import Data.Char (isSpace, isDigit)
import Data.List (intercalate, isPrefixOf, isSuffixOf)
import Data.Time (UTCTime, getCurrentTime, formatTime, defaultTimeLocale)
import Data.Time.Format (parseTimeM)
import System.Directory (getHomeDirectory, createDirectoryIfMissing,
                         doesFileExist, removeFile)
import System.Environment (getArgs, lookupEnv)
import qualified System.FilePath as FP
import System.IO (hPutStrLn, hPutStr, hGetContents, stderr, hSetEncoding,
                   stdin, stdout, utf8, withFile, IOMode(..))

-- ═══════════════════════════════════════════════════════════
-- JSON シリアライズ（手書き）
-- ═══════════════════════════════════════════════════════════

-- | JSON 文字列のエスケープ
escapeJson :: String -> String
escapeJson = concatMap esc
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\t' = "\\t"
    esc c    = [c]

-- | インデント付き JSON 文字列
jsonStr :: String -> String
jsonStr s = "\"" ++ escapeJson s ++ "\""

-- | インデント用
indent :: Int -> String
indent n = replicate (n * 2) ' '

-- | Schema を JSON 文字列に変換
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

-- | 末尾カンマの付与（最後の要素以外）
addCommas :: [String] -> [String]
addCommas []     = []
addCommas [x]    = [x]
addCommas (x:xs) = (x ++ ",") : addCommas xs

-- | unlines の末尾改行なし版
unlines' :: [String] -> String
unlines' = intercalate "\n"

-- | Layers を JSON に変換
layersToJson :: Int -> Layers -> String
layersToJson n l = unlines'
  [ indent n ++ "\"layers\": {"
  , indent (n+1) ++ "\"user\": " ++ jsonStr (unNonEmptyText (lUser l)) ++ ","
  , indent (n+1) ++ "\"thinking\": " ++ jsonStr (unNonEmptyText (lThinking l)) ++ ","
  , indent (n+1) ++ "\"assistant\": " ++ jsonStr (unNonEmptyText (lAssistant l))
  , indent n ++ "}"
  ]

-- | Entry を JSON 文字列に変換
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
-- JSON パース（手書き、再帰下降）
-- ═══════════════════════════════════════════════════════════

-- | 簡易 JSON 値
data JValue
  = JString String
  | JNumber Int
  | JObject [(String, JValue)]
  | JNull
  deriving (Show)

type Parser a = String -> Either String (a, String)

-- | 空白を読み飛ばす
skipWS :: String -> String
skipWS = dropWhile isSpace

-- | 期待する文字を消費
expect :: Char -> Parser ()
expect c s = case skipWS s of
  (x:xs) | x == c -> Right ((), xs)
  rest -> Left $ "expected '" ++ [c] ++ "' but got: " ++ take 20 rest
  
-- | JSON 文字列をパース
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
      in if length hex == 4
         then go rest' (toEnum (read ("0x" ++ hex)) : acc)
         else Left "invalid unicode escape"

-- | JSON 数値をパース
parseJNumber :: Parser Int
parseJNumber s0 =
  let s = skipWS s0
      (neg, s') = if not (null s) && head s == '-' then (True, tail s) else (False, s)
      (digits, rest) = span isDigit s'
  in if null digits
     then Left $ "expected number but got: " ++ take 20 s
     else Right ((if neg then negate else id) (read digits), rest)

-- | JSON 値をパース
parseJValue :: Parser JValue
parseJValue s0 = case skipWS s0 of
  ('"':_)  -> do (v, r) <- parseJString s0; Right (JString v, r)
  ('{':_)  -> do (v, r) <- parseJObject s0; Right (JObject v, r)
  ('n':'u':'l':'l':r) -> Right (JNull, r)
  _ -> do (v, r) <- parseJNumber s0; Right (JNumber v, r)

-- | JSON オブジェクトをパース
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

-- | JValue からフィールドを取得
jLookup :: String -> [(String, JValue)] -> Either String JValue
jLookup k kvs = case lookup k kvs of
  Just v  -> Right v
  Nothing -> Left $ "missing field: " ++ k

-- | JValue から String を取得
jStr :: String -> [(String, JValue)] -> Either String String
jStr k kvs = do
  v <- jLookup k kvs
  case v of
    JString s -> Right s
    _         -> Left $ k ++ " is not a string"

-- | JValue から Int を取得
jInt :: String -> [(String, JValue)] -> Either String Int
jInt k kvs = do
  v <- jLookup k kvs
  case v of
    JNumber n -> Right n
    _         -> Left $ k ++ " is not a number"

-- | JValue から Object を取得
jObj :: String -> [(String, JValue)] -> Either String [(String, JValue)]
jObj k kvs = do
  v <- jLookup k kvs
  case v of
    JObject o -> Right o
    _         -> Left $ k ++ " is not an object"

-- | タイムスタンプを複数の形式で試行パース
parseTimestamp :: String -> Either String UTCTime
parseTimestamp s = tryFormats formats
  where
    -- +00:00 を Z に正規化
    normalized
      | "+00:00" `isSuffixOf` s = take (length s - 6) s ++ "Z"
      | otherwise = s
    -- マイクロ秒の除去（.123456Z → Z）
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

-- | JSON 文字列から Entry をパース
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

-- | stdin の plist 風入力を RawArgs にパース
parseStdinArgs :: String -> Either String RawArgs
parseStdinArgs src = do
  (top, _) <- parseJObject src
  u  <- jStr "user" top
  t  <- jStr "thinking" top
  a  <- jStr "assistant" top
  cf <- fieldOr "current_focus" top
  tm <- fieldOr "theory_of_mind" top
  sn <- fieldOr "self_narrative" top
  an <- fieldOr "annotation" top
  Right RawArgs
    { rawUser = u, rawThinking = t, rawAssistant = a
    , rawCurrentFocus = cf, rawTheoryOfMind = tm
    , rawSelfNarrative = sn, rawAnnotation = an
    }
  where
    fieldOr k kvs = case jStr k kvs of
      Right v -> Right v
      Left _  -> Right ""


-- ═══════════════════════════════════════════════════════════
-- ファイル I/O
-- ═══════════════════════════════════════════════════════════

-- | デフォルトの coglog パスを返す
-- 優先順位: COGLOG_DIR env > $HOME/.coglog > ./.coglog（最終フォールバック）
defaultCoglogPath :: IO FilePath
defaultCoglogPath = do
  envDir <- lookupEnv "COGLOG_DIR"
  case envDir of
    Just d  -> return (d FP.</> "current.json")
    Nothing -> do
      home <- getHomeDirectory
      return (home FP.</> ".coglog" FP.</> "current.json")

-- | コグログファイルを読む
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

-- | コグログファイルに書く
writeCoglog :: FilePath -> Entry -> IO ()
writeCoglog path entry = do
  createDirectoryIfMissing True (FP.takeDirectory path)
  withFile path WriteMode $ \h -> do
    hSetEncoding h utf8
    hPutStr h (entryToJson entry ++ "\n")

-- | コグログファイルをクリアする
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
  -- --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
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
