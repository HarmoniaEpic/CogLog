;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog MCP Server v0.9.1 — Common Lisp
;;;;
;;;; Exposes CogLog read/write/clear as MCP tools over stdio transport.
;;;; Loads coglog.lisp (pure core) and adapter JSON/IO functions.
;;;;
;;;; Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
;;;; Transport: stdio (newline-delimited JSON)
;;;; ═══════════════════════════════════════════════════════════════════

(load (merge-pathnames "coglog.lisp" *load-truename*))
(in-package :coglog)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Path resolution
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-default-coglog-dir ()
  "COGLOG_DIR 環境変数 > $HOME/.coglog/ の順で解決する。"
  (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
    (if env
        (parse-namestring (concatenate 'string env "/"))
        (merge-pathnames ".coglog/" (user-homedir-pathname)))))

(defvar *mcp-data-dir* (mcp-default-coglog-dir))

(defvar *mcp-current-file*
  (merge-pathnames "current.json" *mcp-data-dir*))

(defun mcp-set-coglog-dir (dir)
  "データディレクトリを動的に変更する。"
  (setf *mcp-data-dir*    (parse-namestring (concatenate 'string dir "/")))
  (setf *mcp-current-file* (merge-pathnames "current.json" *mcp-data-dir*)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Timestamp
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-utc-timestamp ()
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ"
            year month day hour min sec)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON serialization (same as adapter.lisp)
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-json-escape (string)
  (with-output-to-string (out)
    (loop for ch across string do
      (case ch
        (#\" (write-string "\\\"" out))
        (#\\ (write-string "\\\\" out))
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (otherwise
         (if (< (char-code ch) #x20)
             (format out "\\u~4,'0x" (char-code ch))
             (write-char ch out)))))))

(defun mcp-json-key (keyword)
  (let ((name (string-downcase (symbol-name keyword))))
    (substitute #\_ #\- name)))

(defun mcp-write-json (value stream &optional (indent 0) (depth 0))
  (let ((prefix (make-string (* depth indent) :initial-element #\Space))
        (inner  (make-string (* (1+ depth) indent) :initial-element #\Space)))
    (cond
      ((stringp value)
       (format stream "\"~a\"" (mcp-json-escape value)))
      ((integerp value)
       (format stream "~d" value))
      ((eq value t)
       (write-string "true" stream))
      ((and (consp value) (consp (car value)))
       (format stream "{~%" )
       (loop for (pair . rest) on value
             for key = (car pair)
             for val = (cdr pair)
             do (format stream "~a\"~a\": " inner (mcp-json-key key))
                (mcp-write-json val stream indent (1+ depth))
                (when rest (write-char #\, stream))
                (format stream "~%"))
       (format stream "~a}" prefix))
      (t
       (format stream "null")))))

(defun mcp-entry-to-json (entry)
  (with-output-to-string (s)
    (mcp-write-json entry s 2)
    (terpri s)))

(defun mcp-compact-json (value)
  "Write VALUE as compact (no whitespace) JSON."
  (with-output-to-string (s)
    (mcp-write-json-compact value s)))

(defun mcp-write-json-compact (value stream)
  (cond
    ((stringp value)
     (format stream "\"~a\"" (mcp-json-escape value)))
    ((integerp value)
     (format stream "~d" value))
    ((eq value t)
     (write-string "true" stream))
    ((and (consp value) (consp (car value)))
     (write-char #\{ stream)
     (loop for (pair . rest) on value
           for key = (car pair)
           for val = (cdr pair)
           do (format stream "\"~a\":" (mcp-json-key key))
              (mcp-write-json-compact val stream)
              (when rest (write-char #\, stream)))
     (write-char #\} stream))
    (t
     (write-string "null" stream))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON parsing (same as adapter.lisp)
;;;; ═══════════════════════════════════════════════════════════════════

(defstruct mcp-json-parser
  (source "" :type string)
  (pos 0 :type fixnum))

(defun mcp-parser-peek (p)
  (when (< (mcp-json-parser-pos p) (length (mcp-json-parser-source p)))
    (char (mcp-json-parser-source p) (mcp-json-parser-pos p))))

(defun mcp-parser-next (p)
  (prog1 (mcp-parser-peek p)
    (incf (mcp-json-parser-pos p))))

(defun mcp-parser-skip-ws (p)
  (loop while (and (mcp-parser-peek p)
                   (member (mcp-parser-peek p) '(#\Space #\Tab #\Newline #\Return)))
        do (mcp-parser-next p)))

(defun mcp-parser-expect (p ch)
  (mcp-parser-skip-ws p)
  (let ((got (mcp-parser-next p)))
    (unless (eql got ch)
      (error "JSON parse error: expected '~a' but got '~a'" ch (or got "EOF")))))

(defun mcp-parser-match (p str)
  (let ((src (mcp-json-parser-source p))
        (start (mcp-json-parser-pos p)))
    (when (and (<= (+ start (length str)) (length src))
               (string= src str :start1 start :end1 (+ start (length str))))
      (incf (mcp-json-parser-pos p) (length str))
      t)))

(defun mcp-parse-json-string (p)
  (with-output-to-string (out)
    (loop for ch = (mcp-parser-next p)
          until (eql ch #\")
          do (if (eql ch #\\)
                 (let ((esc (mcp-parser-next p)))
                   (case esc
                     (#\" (write-char #\" out))
                     (#\\ (write-char #\\ out))
                     (#\/ (write-char #\/ out))
                     (#\n (write-char #\Newline out))
                     (#\r (write-char #\Return out))
                     (#\t (write-char #\Tab out))
                     (#\u
                      (let ((hex (subseq (mcp-json-parser-source p)
                                         (mcp-json-parser-pos p)
                                         (+ (mcp-json-parser-pos p) 4))))
                        (incf (mcp-json-parser-pos p) 4)
                        (write-char (code-char (parse-integer hex :radix 16)) out)))
                     (otherwise (write-char esc out))))
                 (write-char ch out)))))

(defun mcp-parse-json-number (p)
  (let ((start (mcp-json-parser-pos p))
        (src (mcp-json-parser-source p)))
    (when (eql (mcp-parser-peek p) #\-) (mcp-parser-next p))
    (loop while (and (mcp-parser-peek p) (digit-char-p (mcp-parser-peek p)))
          do (mcp-parser-next p))
    (parse-integer (subseq src start (mcp-json-parser-pos p)))))

(defun mcp-parse-json-value (p)
  (mcp-parser-skip-ws p)
  (let ((ch (mcp-parser-peek p)))
    (cond
      ((eql ch #\")
       (mcp-parser-next p)
       (mcp-parse-json-string p))
      ((eql ch #\{)
       (mcp-parser-next p)
       (mcp-parse-json-object p))
      ((eql ch #\[)
       (mcp-parser-next p)
       (mcp-parse-json-array p))
      ((or (eql ch #\-) (and ch (digit-char-p ch)))
       (mcp-parse-json-number p))
      ((mcp-parser-match p "null")  nil)
      ((mcp-parser-match p "true")  t)
      ((mcp-parser-match p "false") nil)
      (t (error "JSON parse error: unexpected character '~a'" (or ch "EOF"))))))

(defun mcp-json-key-to-keyword (key-string)
  (intern (string-upcase (substitute #\- #\_ key-string)) :keyword))

(defun mcp-parse-json-object (p)
  (mcp-parser-skip-ws p)
  (when (eql (mcp-parser-peek p) #\})
    (mcp-parser-next p)
    (return-from mcp-parse-json-object nil))
  (loop collect
        (progn
          (mcp-parser-skip-ws p)
          (mcp-parser-expect p #\")
          (let* ((key (mcp-parse-json-string p))
                 (kw (mcp-json-key-to-keyword key)))
            (mcp-parser-skip-ws p)
            (mcp-parser-expect p #\:)
            (let ((val (mcp-parse-json-value p)))
              (cons kw val))))
        into pairs
        do (mcp-parser-skip-ws p)
           (if (eql (mcp-parser-peek p) #\,)
               (mcp-parser-next p)
               (progn (mcp-parser-expect p #\})
                      (return pairs)))
        finally (return pairs)))

(defun mcp-parse-json-array (p)
  (mcp-parser-skip-ws p)
  (when (eql (mcp-parser-peek p) #\])
    (mcp-parser-next p)
    (return-from mcp-parse-json-array nil))
  (loop collect (mcp-parse-json-value p)
        into items
        do (mcp-parser-skip-ws p)
           (if (eql (mcp-parser-peek p) #\,)
               (mcp-parser-next p)
               (progn (mcp-parser-expect p #\])
                      (return items)))
        finally (return items)))

(defun mcp-parse-json (string)
  (let ((p (make-mcp-json-parser :source string)))
    (mcp-parse-json-value p)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; File I/O
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-read-metalog ()
  (when (probe-file *mcp-current-file*)
    (let ((content (with-open-file (in *mcp-current-file*
                                    :direction :input
                                    :external-format :utf-8)
                     (let ((buf (make-string (file-length in))))
                       (read-sequence buf in)
                       buf))))
      (mcp-parse-json content))))

(defun mcp-write-metalog (args-plist)
  (validate-args args-plist)
  (ensure-directories-exist *mcp-current-file*)
  (let* ((prev (mcp-read-metalog))
         (timestamp (mcp-utc-timestamp))
         (entry (advance prev args-plist timestamp))
         (json (mcp-entry-to-json entry)))
    (with-open-file (out *mcp-current-file*
                     :direction :output
                     :if-exists :supersede
                     :external-format :utf-8)
      (write-string json out))
    entry))

(defun mcp-clear-metalog ()
  (cond
    ((probe-file *mcp-current-file*)
     (delete-file *mcp-current-file*)
     '((:cleared . t)))
    (t
     '((:cleared . nil)
       (:reason . "no existing metalog")))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON-RPC helpers
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-send (json-string)
  (write-string json-string *standard-output*)
  (terpri *standard-output*)
  (force-output *standard-output*))

(defun mcp-send-result (msg-id result-json)
  (mcp-send (format nil "{\"jsonrpc\":\"2.0\",\"id\":~a,\"result\":~a}"
                    msg-id result-json)))

(defun mcp-send-error (msg-id code message)
  (mcp-send (format nil "{\"jsonrpc\":\"2.0\",\"id\":~a,\"error\":{\"code\":~d,\"message\":\"~a\"}}"
                    msg-id code (mcp-json-escape message))))

(defun mcp-send-tool-result (msg-id text &optional (is-error nil))
  (let ((err-field (if is-error ",\"isError\":true" "")))
    (mcp-send-result msg-id
      (format nil "{\"content\":[{\"type\":\"text\",\"text\":\"~a\"}]~a}"
              (mcp-json-escape text) err-field))))

(defun mcp-log (msg)
  (format *error-output* "metalog-mcp: ~a~%" msg)
  (force-output *error-output*))

(defun format-id (id-value)
  "Format the JSON-RPC id field for embedding in response."
  (cond
    ((integerp id-value) (format nil "~d" id-value))
    ((stringp id-value) (format nil "\"~a\"" (mcp-json-escape id-value)))
    (t "null")))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; MCP tool definitions
;;;; ═══════════════════════════════════════════════════════════════════

(defvar *tool-definitions*
  "[{\"name\":\"metalog_read\",\"description\":\"Read the previous turn's metalog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no metalog exists.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}},{\"name\":\"metalog_write\",\"description\":\"Write the current turn's metalog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings \\u2014 choosing not to write is itself a metacognitive act.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"user\":{\"type\":\"string\",\"description\":\"User's original utterance (non-empty)\"},\"thinking\":{\"type\":\"string\",\"description\":\"AI's full thinking process (non-empty)\"},\"assistant\":{\"type\":\"string\",\"description\":\"AI's original output (non-empty)\"},\"current_focus\":{\"type\":\"string\",\"description\":\"Present direction: what am I working on?\"},\"theory_of_mind\":{\"type\":\"string\",\"description\":\"Other direction: what is the user's state?\"},\"self_narrative\":{\"type\":\"string\",\"description\":\"Self direction: who am I in this moment?\"},\"annotation\":{\"type\":\"string\",\"description\":\"Future direction: what should I do next?\"}},\"required\":[\"user\",\"thinking\",\"assistant\",\"current_focus\",\"theory_of_mind\",\"self_narrative\",\"annotation\"],\"additionalProperties\":false}},{\"name\":\"metalog_clear\",\"description\":\"Clear the metalog, removing the stored turn data. Returns whether the clear was successful.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{},\"additionalProperties\":false}}]")


;;;; ═══════════════════════════════════════════════════════════════════
;;;; MCP handlers
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-handle-initialize (msg-id)
  (mcp-send-result msg-id
    "{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"metalog\",\"version\":\"0.9.1\"}}"))

(defun mcp-handle-tools-list (msg-id)
  (mcp-send-result msg-id
    (format nil "{\"tools\":~a}" *tool-definitions*)))

(defun mcp-handle-tools-call (msg-id params)
  (let* ((name (cdr (assoc :name params)))
         (args (cdr (assoc :arguments params))))
    (cond
      ((string= name "metalog_read")
       (let ((entry (mcp-read-metalog)))
         (if entry
             (mcp-send-tool-result msg-id (mcp-entry-to-json entry))
             (mcp-send-tool-result msg-id "(no metalog found)"))))
      ((string= name "metalog_write")
       (handler-case
           (let* ((plist (loop for (key . val) in (if (consp args) args nil)
                               collect key collect val))
                  (entry (mcp-write-metalog plist)))
             (mcp-send-tool-result msg-id (mcp-entry-to-json entry)))
         (error (e)
           (mcp-send-tool-result msg-id (format nil "Error: ~a" e) t))))
      ((string= name "metalog_clear")
       (let ((result (mcp-clear-metalog)))
         (mcp-send-tool-result msg-id (mcp-compact-json result))))
      (t
       (mcp-send-tool-result msg-id (format nil "Error: unknown tool: ~a" name) t)))))

(defun mcp-handle-ping (msg-id)
  (mcp-send-result msg-id "{}"))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Main loop
;;;; ═══════════════════════════════════════════════════════════════════

(defun mcp-main ()
  ;; --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
  (let ((argv #+sbcl sb-ext:*posix-argv* #-sbcl nil))
    (let ((pos (position "--coglog-dir" argv :test #'string=)))
      (when (and pos (< (1+ pos) (length argv)))
        (mcp-set-coglog-dir (nth (1+ pos) argv)))))
  (mcp-log "server started")
  (loop for line = (read-line *standard-input* nil nil)
        while line
        do (let ((trimmed (string-trim '(#\Space #\Tab #\Return) line)))
             (when (plusp (length trimmed))
               (handler-case
                   (let* ((msg (mcp-parse-json trimmed))
                          (method (cdr (assoc :method msg)))
                          (raw-id (cdr (assoc :id msg)))
                          (msg-id (format-id raw-id))
                          (params (or (cdr (assoc :params msg)) nil))
                          (has-id (assoc :id msg)))
                     ;; Notification (no id) — never respond
                     (unless has-id
                       (when (string= method "notifications/initialized")
                         (mcp-log "initialized")))
                     ;; Request (has id) — must respond
                     (when has-id
                       (cond
                         ((string= method "initialize")
                          (mcp-handle-initialize msg-id))
                         ((string= method "tools/list")
                          (mcp-handle-tools-list msg-id))
                         ((string= method "tools/call")
                          (mcp-handle-tools-call msg-id params))
                         ((string= method "ping")
                          (mcp-handle-ping msg-id))
                         (t
                          (mcp-send-error msg-id -32601
                                          (format nil "Method not found: ~a" method))))))
                 (error (e)
                   (mcp-send-error "null" -32700
                                   (format nil "Parse error: ~a" e)))))))
  (mcp-log "server stopped"))

(mcp-main)

;;;; ═══════════════════════════════════════════════════════════════════
;;;; End of mcp-server.lisp
;;;; ═══════════════════════════════════════════════════════════════════
