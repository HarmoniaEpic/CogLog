module Main where

import CogLog
import Data.Char (isSpace, isDigit)
import Data.List (intercalate, isPrefixOf, isSuffixOf)
import Data.Time (UTCTime, getCurrentTime, formatTime, defaultTimeLocale)
import Data.Time.Format (parseTimeM)
import System.IO (hPutStrLn, hPutStr, hGetContents, hGetLine, hFlush,
                   hIsEOF,
                   stderr, stdin, stdout, hSetEncoding, hSetBuffering,
                   utf8, withFile, IOMode(..), BufferMode(..))
import System.Directory (doesFileExist, createDirectoryIfMissing,
                         removeFile, getHomeDirectory)
import System.Environment (getArgs, lookupEnv)
import qualified System.FilePath as FP


-- ═══════════════════════════════════════════════════════════
-- JSON serialization (hand-written, same as Adapter.hs)
-- ═══════════════════════════════════════════════════════════

escapeJson :: String -> String
escapeJson = concatMap esc
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc '\n' = "\\n"
    esc '\t' = "\\t"
    esc c    = [c]

jsonStr :: String -> String
jsonStr s = "\"" ++ escapeJson s ++ "\""

ind :: Int -> String
ind n = replicate (n * 2) ' '

addCommas :: [String] -> [String]
addCommas []     = []
addCommas [x]    = [x]
addCommas (x:xs) = (x ++ ",") : addCommas xs

unlines' :: [String] -> String
unlines' = intercalate "\n"

schemaToJson :: Int -> Schema -> String
schemaToJson n s = unlines' $
  [ ind n ++ "\"_schema\": {"
  , ind (n+1) ++ "\"version\": " ++ jsonStr (sVersion s) ++ ","
  , ind (n+1) ++ "\"fact_layer\": {"
  ] ++ kvLines (n+2) (sFactLayer s) ++
  [ ind (n+1) ++ "},"
  , ind (n+1) ++ "\"interpretation_layer\": {"
  ] ++ kvLines (n+2) (sInterpLayer s) ++
  [ ind (n+1) ++ "},"
  , ind (n+1) ++ "\"constraints\": {"
  ] ++ kvLines (n+2) (sConstraints s) ++
  [ ind (n+1) ++ "}"
  , ind n ++ "}"
  ]
  where
    kvLines d kvs =
      let formatted = map (\(k,v) -> ind d ++ jsonStr k ++ ": " ++ jsonStr v) kvs
      in  addCommas formatted

layersToJson :: Int -> Layers -> String
layersToJson n l = unlines'
  [ ind n ++ "\"layers\": {"
  , ind (n+1) ++ "\"user\": " ++ jsonStr (unNonEmptyText (lUser l)) ++ ","
  , ind (n+1) ++ "\"thinking\": " ++ jsonStr (unNonEmptyText (lThinking l)) ++ ","
  , ind (n+1) ++ "\"assistant\": " ++ jsonStr (unNonEmptyText (lAssistant l))
  , ind n ++ "}"
  ]

entryToJson :: Entry -> String
entryToJson e = unlines'
  [ "{"
  , schemaToJson 1 (eSchema e) ++ ","
  , ind 1 ++ "\"turn_id\": " ++ show (eTurnId e) ++ ","
  , ind 1 ++ "\"timestamp\": " ++ jsonStr (fmtTime (eTimestamp e)) ++ ","
  , layersToJson 1 (eLayers e) ++ ","
  , ind 1 ++ "\"current_focus\": " ++ jsonStr (eCurrentFocus e) ++ ","
  , ind 1 ++ "\"theory_of_mind\": " ++ jsonStr (eTheoryOfMind e) ++ ","
  , ind 1 ++ "\"self_narrative\": " ++ jsonStr (eSelfNarrative e) ++ ","
  , ind 1 ++ "\"annotation\": " ++ jsonStr (eAnnotation e)
  , "}"
  ]
  where
    fmtTime = formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

clearResultToJson :: Bool -> String -> String
clearResultToJson True  _ = "{\"cleared\":true}"
clearResultToJson False r = "{\"cleared\":false,\"reason\":" ++ jsonStr r ++ "}"


-- ═══════════════════════════════════════════════════════════
-- JSON parsing (hand-written, same as Adapter.hs)
-- ═══════════════════════════════════════════════════════════

data JValue
  = JString String
  | JNumber Int
  | JObject [(String, JValue)]
  | JBool Bool
  | JNull
  deriving (Show)

type Parser a = String -> Either String (a, String)

skipWS :: String -> String
skipWS = dropWhile isSpace

expect :: Char -> Parser ()
expect c s = case skipWS s of
  (x:xs) | x == c -> Right ((), xs)
  rest -> Left $ "expected '" ++ [c] ++ "' but got: " ++ take 20 rest

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
      'u'  -> let (hex, rest') = splitAt 4 rest
              in if length hex == 4
                 then go rest' (toEnum (read ("0x" ++ hex)) : acc)
                 else Left "invalid unicode escape"
      _    -> go rest (c : acc)
    go (c:rest) acc = go rest (c : acc)

parseJNumber :: Parser Int
parseJNumber s0 =
  let s = skipWS s0
      (neg, s') = if not (null s) && head s == '-' then (True, tail s) else (False, s)
      (digits, rest) = span isDigit s'
  in if null digits
     then Left $ "expected number but got: " ++ take 20 s
     else Right ((if neg then negate else id) (read digits), rest)

parseJValue :: Parser JValue
parseJValue s0 = case skipWS s0 of
  ('"':_)  -> do (v, r) <- parseJString s0; Right (JString v, r)
  ('{':_)  -> do (v, r) <- parseJObject s0; Right (JObject v, r)
  ('t':'r':'u':'e':r) -> Right (JBool True, r)
  ('f':'a':'l':'s':'e':r) -> Right (JBool False, r)
  ('n':'u':'l':'l':r) -> Right (JNull, r)
  _ -> do (v, r) <- parseJNumber s0; Right (JNumber v, r)

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

jLookup :: String -> [(String, JValue)] -> Either String JValue
jLookup k kvs = case lookup k kvs of
  Just v  -> Right v
  Nothing -> Left $ "missing field: " ++ k

jStr :: String -> [(String, JValue)] -> Either String String
jStr k kvs = do
  v <- jLookup k kvs
  case v of
    JString s -> Right s
    _         -> Left $ k ++ " is not a string"

jInt :: String -> [(String, JValue)] -> Either String Int
jInt k kvs = do
  v <- jLookup k kvs
  case v of
    JNumber n -> Right n
    _         -> Left $ k ++ " is not a number"

jObj :: String -> [(String, JValue)] -> Either String [(String, JValue)]
jObj k kvs = do
  v <- jLookup k kvs
  case v of
    JObject o -> Right o
    _         -> Left $ k ++ " is not an object"

parseTimestamp :: String -> Either String UTCTime
parseTimestamp s = tryFormats formats
  where
    normalized
      | "+00:00" `isSuffixOf` s = take (length s - 6) s ++ "Z"
      | otherwise = s
    stripped = case break (== '.') normalized of
      (pre, '.':rest) -> pre ++ dropWhile isDigit rest
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

parseEntry :: String -> Either String Entry
parseEntry src = do
  (top, _) <- parseJObject src
  tid <- jInt "turn_id" top
  tsStr <- jStr "timestamp" top
  ts <- parseTimestamp tsStr
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


-- ═══════════════════════════════════════════════════════════
-- File I/O
-- ═══════════════════════════════════════════════════════════

defaultCoglogPath :: IO FilePath
defaultCoglogPath = do
  envDir <- lookupEnv "COGLOG_DIR"
  case envDir of
    Just d  -> return (d FP.</> "current.json")
    Nothing -> do
      home <- getHomeDirectory
      return (home FP.</> ".coglog" FP.</> "current.json")

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

writeCoglog :: FilePath -> Entry -> IO ()
writeCoglog path entry = do
  createDirectoryIfMissing True (FP.takeDirectory path)
  withFile path WriteMode $ \h -> do
    hSetEncoding h utf8
    hPutStr h (entryToJson entry ++ "\n")

clearCoglog :: FilePath -> IO Bool
clearCoglog path = do
  exists <- doesFileExist path
  if exists
    then removeFile path >> return True
    else return False


-- ═══════════════════════════════════════════════════════════
-- MCP tool definitions (JSON strings)
-- ═══════════════════════════════════════════════════════════

toolDefinitions :: String
toolDefinitions = "[" ++ intercalate "," [readTool, writeTool, clearTool] ++ "]"
  where
    readTool = "{\"name\":\"coglog_read\",\"description\":\"Read the previous turn's coglog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no coglog exists.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}}"
    writeTool = "{\"name\":\"coglog_write\",\"description\":\"Write the current turn's coglog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings \\u2014 choosing not to write is itself a metacognitive act.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"user\":{\"type\":\"string\",\"description\":\"User's original utterance (non-empty)\"},\"thinking\":{\"type\":\"string\",\"description\":\"AI's full thinking process (non-empty)\"},\"assistant\":{\"type\":\"string\",\"description\":\"AI's original output (non-empty)\"},\"current_focus\":{\"type\":\"string\",\"description\":\"Present direction: what am I working on?\"},\"theory_of_mind\":{\"type\":\"string\",\"description\":\"Other direction: what is the user's state?\"},\"self_narrative\":{\"type\":\"string\",\"description\":\"Self direction: who am I in this moment?\"},\"annotation\":{\"type\":\"string\",\"description\":\"Future direction: what should I do next?\"}},\"required\":[\"user\",\"thinking\",\"assistant\",\"current_focus\",\"theory_of_mind\",\"self_narrative\",\"annotation\"],\"additionalProperties\":false}}"
    clearTool = "{\"name\":\"coglog_clear\",\"description\":\"Clear the coglog, removing the stored turn data. Returns whether the clear was successful.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}}"


-- ═══════════════════════════════════════════════════════════
-- JSON-RPC helpers
-- ═══════════════════════════════════════════════════════════

sendLine :: String -> IO ()
sendLine s = do
  hPutStr stdout s
  hPutStr stdout "\n"
  hFlush stdout

sendResult :: String -> String -> IO ()
sendResult msgId result =
  sendLine $ "{\"jsonrpc\":\"2.0\",\"id\":" ++ msgId ++ ",\"result\":" ++ result ++ "}"

sendError :: String -> Int -> String -> IO ()
sendError msgId code message =
  sendLine $ "{\"jsonrpc\":\"2.0\",\"id\":" ++ msgId
    ++ ",\"error\":{\"code\":" ++ show code
    ++ ",\"message\":" ++ jsonStr message ++ "}}"

sendToolResult :: String -> String -> Bool -> IO ()
sendToolResult msgId text isErr =
  let errField = if isErr then ",\"isError\":true" else ""
      result = "{\"content\":[{\"type\":\"text\",\"text\":" ++ jsonStr text ++ "}]" ++ errField ++ "}"
  in sendResult msgId result

logMsg :: String -> IO ()
logMsg msg = hPutStrLn stderr ("coglog-mcp: " ++ msg)

-- Extract the raw JSON string for an "id" field (preserves type: number or string)
extractId :: [(String, JValue)] -> String
extractId kvs = case lookup "id" kvs of
  Just (JNumber n) -> show n
  Just (JString s) -> jsonStr s
  Just JNull       -> "null"
  Nothing          -> "null"
  _                -> "null"


-- ═══════════════════════════════════════════════════════════
-- MCP handlers
-- ═══════════════════════════════════════════════════════════

handleInitialize :: String -> IO ()
handleInitialize msgId =
  sendResult msgId $ "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"coglog\",\"version\":\"0.9.1\"}}"

handleToolsList :: String -> IO ()
handleToolsList msgId =
  sendResult msgId $ "{\"tools\":" ++ toolDefinitions ++ "}"

handleToolsCall :: FilePath -> String -> [(String, JValue)] -> IO ()
handleToolsCall coglogPath msgId params = do
  let name = case lookup "name" params of
               Just (JString s) -> s
               _                -> ""
  let args = case lookup "arguments" params of
               Just (JObject o) -> o
               _                -> []
  case name of
    "coglog_read"  -> handleRead  coglogPath msgId
    "coglog_write" -> handleWrite coglogPath msgId args
    "coglog_clear" -> handleClear coglogPath msgId
    _               -> sendToolResult msgId ("Error: unknown tool: " ++ name) True

handleRead :: FilePath -> String -> IO ()
handleRead coglogPath msgId = do
  me <- readCoglog coglogPath
  case me of
    Nothing -> sendToolResult msgId "(no coglog found)" False
    Just e  -> sendToolResult msgId (entryToJson e) False

handleWrite :: FilePath -> String -> [(String, JValue)] -> IO ()
handleWrite coglogPath msgId args = do
  let rawArgs = do
        u  <- jStr "user" args
        t  <- jStr "thinking" args
        a  <- jStr "assistant" args
        cf <- orEmpty "current_focus" args
        tm <- orEmpty "theory_of_mind" args
        sn <- orEmpty "self_narrative" args
        an <- orEmpty "annotation" args
        Right RawArgs
          { rawUser = u, rawThinking = t, rawAssistant = a
          , rawCurrentFocus = cf, rawTheoryOfMind = tm
          , rawSelfNarrative = sn, rawAnnotation = an
          }
  case rawArgs of
    Left err -> sendToolResult msgId ("Error: " ++ err) True
    Right raw -> case validateArgs raw of
      Left (ValidationError err) -> sendToolResult msgId ("Error: " ++ err) True
      Right wargs -> do
        prev <- readCoglog coglogPath
        now <- getCurrentTime
        let entry = advance prev wargs now
        writeCoglog coglogPath entry
        sendToolResult msgId (entryToJson entry) False
  where
    orEmpty k kvs = case jStr k kvs of
      Right v -> Right v
      Left _  -> Right ""

handleClear :: FilePath -> String -> IO ()
handleClear coglogPath msgId = do
  had <- clearCoglog coglogPath
  if had
    then sendToolResult msgId (clearResultToJson True "") False
    else sendToolResult msgId (clearResultToJson False "no existing coglog") False

handlePing :: String -> IO ()
handlePing msgId = sendResult msgId "{}"


-- ═══════════════════════════════════════════════════════════
-- Main loop
-- ═══════════════════════════════════════════════════════════

main :: IO ()
main = do
  hSetEncoding stdin  utf8
  hSetEncoding stdout utf8
  hSetEncoding stderr utf8
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  -- Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
  allArgs <- getArgs
  coglogPath <- case allArgs of
    ("--coglog-dir":d:_) -> return (d FP.</> "current.json")
    _                    -> defaultCoglogPath
  logMsg "server started"
  loop coglogPath
  where
    loop coglogPath = do
      eof <- hIsEOF stdin
      if eof
        then logMsg "server stopped"
        else do
          line <- hGetLine stdin
          let trimmed = dropWhile isSpace line
          if null trimmed
            then loop coglogPath
            else do
              processMessage coglogPath trimmed
              loop coglogPath

    processMessage coglogPath line =
      case parseJObject line of
        Left err -> sendError "null" (-32700) ("Parse error: " ++ err)
        Right (top, _) -> do
          let msgId = extractId top
          let method = case lookup "method" top of
                         Just (JString s) -> Just s
                         _                -> Nothing
          let params = case lookup "params" top of
                         Just (JObject o) -> o
                         _                -> []
          let hasId = case lookup "id" top of
                        Nothing          -> False
                        Just JNull       -> False
                        _                -> True

          if not hasId
            then do
              case method of
                Just "notifications/initialized" -> logMsg "initialized"
                _ -> return ()
            else case method of
              Just "initialize"  -> handleInitialize msgId
              Just "tools/list"  -> handleToolsList msgId
              Just "tools/call"  -> handleToolsCall coglogPath msgId params
              Just "ping"        -> handlePing msgId
              Just m             -> sendError msgId (-32601) ("Method not found: " ++ m)
              Nothing            -> sendError msgId (-32600) "Invalid Request: missing method"
