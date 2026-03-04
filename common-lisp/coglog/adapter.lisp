;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog v0.9.1 — Common Lisp アダプター
;;;;
;;;; coglog.lisp の純粋核を current.json に接地する。
;;;; JSON シリアライズ/パース、ファイル I/O、CLI を提供する。
;;;; ═══════════════════════════════════════════════════════════════════

(load (merge-pathnames "coglog.lisp" *load-truename*))
(in-package :coglog)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; パス解決
;;;; ═══════════════════════════════════════════════════════════════════

(defun default-coglog-dir ()
  "COGLOG_DIR 環境変数 > $HOME/.coglog/ の順で解決する。"
  (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
    (if env
        (parse-namestring (concatenate 'string env "/"))
        (merge-pathnames ".coglog/" (user-homedir-pathname)))))

(defvar *data-dir* (default-coglog-dir))

(defvar *current-file*
  (merge-pathnames "current.json" *data-dir*))

(defun set-coglog-dir (dir)
  "データディレクトリを動的に変更する。"
  (setf *data-dir*    (parse-namestring (concatenate 'string dir "/")))
  (setf *current-file* (merge-pathnames "current.json" *data-dir*)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; タイムスタンプ
;;;; ═══════════════════════════════════════════════════════════════════

(defun utc-timestamp ()
  "ISO 8601 UTC タイムスタンプを返す。"
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ"
            year month day hour min sec)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON シリアライズ（alist → JSON 文字列）
;;;; ═══════════════════════════════════════════════════════════════════

;;; CogLog の alist 構造に特化した JSON シリアライザー。
;;; 対応する型: 文字列、整数、alist（JSON オブジェクト）、NIL（null にはしない）。

(defun json-escape (string)
  "JSON 文字列エスケープ。"
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

(defun json-key (keyword)
  "キーワードシンボルを JSON キー文字列に変換する。
   :_schema → \"_schema\", :turn-id → \"turn_id\""
  (let ((name (string-downcase (symbol-name keyword))))
    (substitute #\_ #\- name)))

(defun write-json (value stream &optional (indent 0) (depth 0))
  "VALUE を JSON として STREAM に書き込む。"
  (let ((prefix (make-string (* depth indent) :initial-element #\Space))
        (inner  (make-string (* (1+ depth) indent) :initial-element #\Space)))
    (cond
      ;; 文字列
      ((stringp value)
       (format stream "\"~a\"" (json-escape value)))
      ;; 整数
      ((integerp value)
       (format stream "~d" value))
      ;; alist（JSON オブジェクト）— 最初の要素が cons かどうかで判定
      ((and (consp value) (consp (car value)))
       (format stream "{~%" )
       (loop for (pair . rest) on value
             for key = (car pair)
             for val = (cdr pair)
             do (format stream "~a\"~a\": " inner (json-key key))
                (write-json val stream indent (1+ depth))
                (when rest (write-char #\, stream))
                (format stream "~%"))
       (format stream "~a}" prefix))
      ;; NIL → 空オブジェクトではなく、ここでは到達しない設計
      (t
       (format stream "null")))))

(defun entry-to-json (entry)
  "エントリ（alist）を pretty-print JSON 文字列に変換する。"
  (with-output-to-string (s)
    (write-json entry s 2)
    (terpri s)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON パース（JSON 文字列 → alist）
;;;; ═══════════════════════════════════════════════════════════════════

;;; 再帰下降パーサー。CogLog の current.json に出現する構造のみ対応。
;;; 対応する型: string, number (integer), object, null, true, false.
;;; 配列は CogLog の current.json には出現しないため未実装。

(defstruct json-parser
  (source "" :type string)
  (pos 0 :type fixnum))

(defun parser-peek (p)
  (when (< (json-parser-pos p) (length (json-parser-source p)))
    (char (json-parser-source p) (json-parser-pos p))))

(defun parser-next (p)
  (prog1 (parser-peek p)
    (incf (json-parser-pos p))))

(defun parser-skip-ws (p)
  (loop while (and (parser-peek p)
                   (member (parser-peek p) '(#\Space #\Tab #\Newline #\Return)))
        do (parser-next p)))

(defun parser-expect (p ch)
  (parser-skip-ws p)
  (let ((got (parser-next p)))
    (unless (eql got ch)
      (error "JSON parse error: expected '~a' but got '~a' at position ~d"
             ch (or got "EOF") (json-parser-pos p)))))

(defun parser-match (p str)
  (let ((src (json-parser-source p))
        (start (json-parser-pos p)))
    (when (and (<= (+ start (length str)) (length src))
               (string= src str :start1 start :end1 (+ start (length str))))
      (incf (json-parser-pos p) (length str))
      t)))

(defun parse-json-string (p)
  "JSON 文字列をパースする。開始の \" は消費済みである前提。"
  (with-output-to-string (out)
    (loop for ch = (parser-next p)
          until (eql ch #\")
          do (if (eql ch #\\)
                 (let ((esc (parser-next p)))
                   (case esc
                     (#\" (write-char #\" out))
                     (#\\ (write-char #\\ out))
                     (#\/ (write-char #\/ out))
                     (#\n (write-char #\Newline out))
                     (#\r (write-char #\Return out))
                     (#\t (write-char #\Tab out))
                     (#\u
                      ;; \uXXXX — BMP のみ
                      (let ((hex (subseq (json-parser-source p)
                                         (json-parser-pos p)
                                         (+ (json-parser-pos p) 4))))
                        (incf (json-parser-pos p) 4)
                        (let ((cp (parse-integer hex :radix 16)))
                          ;; UTF-8 エンコード
                          (cond
                            ((< cp #x80)
                             (write-char (code-char cp) out))
                            ((< cp #x800)
                             (write-char (code-char (logior #xC0 (ash cp -6))) out)
                             (write-char (code-char (logior #x80 (logand cp #x3F))) out))
                            (t
                             (write-char (code-char (logior #xE0 (ash cp -12))) out)
                             (write-char (code-char (logior #x80 (logand (ash cp -6) #x3F))) out)
                             (write-char (code-char (logior #x80 (logand cp #x3F))) out))))))
                     (otherwise (write-char esc out))))
                 (write-char ch out)))))

(defun parse-json-number (p)
  "JSON 数値（整数）をパースする。"
  (let ((start (json-parser-pos p))
        (src (json-parser-source p)))
    ;; 先頭のマイナス
    (when (eql (parser-peek p) #\-) (parser-next p))
    ;; 数字列
    (loop while (and (parser-peek p) (digit-char-p (parser-peek p)))
          do (parser-next p))
    (parse-integer (subseq src start (json-parser-pos p)))))

(defun parse-json-value (p)
  "JSON 値をパースする。"
  (parser-skip-ws p)
  (let ((ch (parser-peek p)))
    (cond
      ((eql ch #\")
       (parser-next p)
       (parse-json-string p))
      ((eql ch #\{)
       (parser-next p)
       (parse-json-object p))
      ((or (eql ch #\-) (and ch (digit-char-p ch)))
       (parse-json-number p))
      ((parser-match p "null")  nil)
      ((parser-match p "true")  t)
      ((parser-match p "false") nil)
      (t (error "JSON parse error: unexpected character '~a' at position ~d"
                (or ch "EOF") (json-parser-pos p))))))

(defun json-key-to-keyword (key-string)
  "JSON キー文字列をキーワードシンボルに変換する。
   \"turn_id\" → :TURN-ID, \"_schema\" → :_SCHEMA"
  (intern (string-upcase (substitute #\- #\_ key-string))
          :keyword))

(defun parse-json-object (p)
  "JSON オブジェクトをパースする。開始の { は消費済みである前提。
   alist を返す。"
  (parser-skip-ws p)
  (when (eql (parser-peek p) #\})
    (parser-next p)
    (return-from parse-json-object nil))
  (loop collect
        (progn
          (parser-skip-ws p)
          (parser-expect p #\")
          (let* ((key (parse-json-string p))
                 (kw (json-key-to-keyword key)))
            (parser-skip-ws p)
            (parser-expect p #\:)
            (let ((val (parse-json-value p)))
              (cons kw val))))
        into pairs
        do (parser-skip-ws p)
           (if (eql (parser-peek p) #\,)
               (parser-next p)
               (progn (parser-expect p #\})
                      (return pairs)))
        finally (return pairs)))

(defun parse-json (string)
  "JSON 文字列をパースして alist を返す。"
  (let ((p (make-json-parser :source string)))
    (parse-json-value p)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; ファイル I/O
;;;; ═══════════════════════════════════════════════════════════════════

(defun read-metalog ()
  "current.json を読み出し、alist として返す。ファイルがなければ NIL。"
  (when (probe-file *current-file*)
    (let ((content (with-open-file (in *current-file*
                                    :direction :input
                                    :external-format :utf-8)
                     (let ((buf (make-string (file-length in))))
                       (read-sequence buf in)
                       buf))))
      (parse-json content))))

(defun write-metalog (args-plist)
  "ARGS-PLIST（plist）をバリデーションし、current.json に書き込む。
   書き込まれたエントリ（alist）を返す。"
  (validate-args args-plist)
  (ensure-directories-exist *current-file*)
  (let* ((prev (read-metalog))
         (timestamp (utc-timestamp))
         (entry (advance prev args-plist timestamp))
         (json (entry-to-json entry)))
    (with-open-file (out *current-file*
                     :direction :output
                     :if-exists :supersede
                     :external-format :utf-8)
      (write-string json out))
    entry))

(defun clear-metalog ()
  "current.json を削除する。結果を alist で返す。"
  (cond
    ((probe-file *current-file*)
     (delete-file *current-file*)
     '((:cleared . t)))
    (t
     '((:cleared . nil)
       (:reason . "no existing metalog")))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; CLI
;;;; ═══════════════════════════════════════════════════════════════════

(defun read-stdin ()
  "stdin から全内容を読み込み、文字列として返す。"
  (with-output-to-string (out)
    (loop for line = (read-line *standard-input* nil nil)
          while line
          do (write-string line out)
             (terpri out))))

(defun json-to-args-plist (json-string)
  "JSON 文字列をパースし、フラットな plist に変換する。"
  (let ((alist (parse-json json-string)))
    (loop for (key . val) in alist
          collect key
          collect val)))

(defun usage ()
  (format t "usage: coglog <read|write|clear>~%~%")
  (format t "  read    — display the previous turn's metalog~%")
  (format t "  write   — save current turn (reads JSON from stdin)~%")
  (format t "  clear   — reset metalog~%"))

(defun main ()
  (let* ((all-args #+sbcl sb-ext:*posix-argv*
                   #-sbcl (list "coglog"))
         ;; --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
         (args (if (and (>= (length all-args) 3)
                        (string= (second all-args) "--coglog-dir"))
                   (progn
                     (set-coglog-dir (third all-args))
                     (cons (first all-args) (cdddr all-args)))
                   all-args)))
    (if (< (length args) 2)
        (usage)
        (let ((cmd (second args)))
          (handler-case
              (cond
                ((string= cmd "read")
                 (let ((entry (read-metalog)))
                   (if entry
                       (format t "~a" (entry-to-json entry))
                       (format t "(no metalog found)~%"))))
                ((string= cmd "write")
                 (let* ((input (read-stdin))
                        (plist (json-to-args-plist input))
                        (entry (write-metalog plist)))
                   (format t "metalog: turn ~d written~%"
                           (cdr (assoc :turn-id entry)))))
                ((string= cmd "clear")
                 (let ((result (clear-metalog)))
                   (if (cdr (assoc :cleared result))
                       (format t "metalog: cleared~%")
                       (format t "metalog: ~a~%"
                               (cdr (assoc :reason result))))))
                (t
                 (usage)
                 (sb-ext:exit :code 1)))
            (validation-error (e)
              (format *error-output* "metalog error: ~a~%" e)
              (sb-ext:exit :code 1))
            (error (e)
              (format *error-output* "metalog error: ~a~%" e)
              (sb-ext:exit :code 1)))))))

(main)

;;;; ═══════════════════════════════════════════════════════════════════
;;;; End of adapter.lisp
;;;; ═══════════════════════════════════════════════════════════════════
