;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog v0.9.1 — Common Lisp Adapter
;;;;
;;;; Grounds the pure core from coglog.lisp to current.json.
;;;; Provides JSON serialization/parsing, file I/O, and CLI.
;;;; ═══════════════════════════════════════════════════════════════════

(load (merge-pathnames "coglog.lisp" *load-truename*))
(in-package :coglog)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Path resolution
;;;; ═══════════════════════════════════════════════════════════════════

(defun default-coglog-dir ()
  "Resolve in order: COGLOG_DIR env var > $HOME/.coglog/"
  (let ((env (sb-ext:posix-getenv "COGLOG_DIR")))
    (if env
        (parse-namestring (concatenate 'string env "/"))
        (merge-pathnames ".coglog/" (user-homedir-pathname)))))

(defvar *data-dir* (default-coglog-dir))

(defvar *current-file*
  (merge-pathnames "current.json" *data-dir*))

(defun set-coglog-dir (dir)
  "Dynamically change the data directory."
  (setf *data-dir*    (parse-namestring (concatenate 'string dir "/")))
  (setf *current-file* (merge-pathnames "current.json" *data-dir*)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Timestamp
;;;; ═══════════════════════════════════════════════════════════════════

(defun utc-timestamp ()
  "Return an ISO 8601 UTC timestamp."
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time (get-universal-time) 0)
    (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ"
            year month day hour min sec)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON serialization (alist -> JSON string)
;;;; ═══════════════════════════════════════════════════════════════════

;;; JSON serializer specialized for CogLog's alist structure.
;;; Supported types: string, integer, alist (JSON object), NIL (not mapped to null).

(defun json-escape (string)
  "JSON string escape."
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
  "Convert a keyword symbol to a JSON key string.
   :_schema -> \"_schema\", :turn-id -> \"turn_id\""
  (let ((name (string-downcase (symbol-name keyword))))
    (substitute #\_ #\- name)))

(defun write-json (value stream &optional (indent 0) (depth 0))
  "Write VALUE as JSON to STREAM."
  (let ((prefix (make-string (* depth indent) :initial-element #\Space))
        (inner  (make-string (* (1+ depth) indent) :initial-element #\Space)))
    (cond
      ;; String
      ((stringp value)
       (format stream "\"~a\"" (json-escape value)))
      ;; Integer
      ((integerp value)
       (format stream "~d" value))
      ;; alist (JSON object) — determined by whether the first element is a cons
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
      ;; NIL -> not an empty object; by design, this branch is not reached
      (t
       (format stream "null")))))

(defun entry-to-json (entry)
  "Convert an entry (alist) to a pretty-printed JSON string."
  (with-output-to-string (s)
    (write-json entry s 2)
    (terpri s)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; JSON parsing (JSON string -> alist)
;;;; ═══════════════════════════════════════════════════════════════════

;;; Recursive descent parser. Supports only structures appearing in CogLog's current.json.
;;; Supported types: string, number (integer), object, null, true, false.
;;; Arrays are not implemented as they do not appear in CogLog's current.json.

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
  "Parse a JSON string. Assumes the opening \" has already been consumed."
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
                      ;; \uXXXX — BMP only
                      (let ((hex (subseq (json-parser-source p)
                                         (json-parser-pos p)
                                         (+ (json-parser-pos p) 4))))
                        (incf (json-parser-pos p) 4)
                        (let ((cp (parse-integer hex :radix 16)))
                          ;; UTF-8 encoding
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
  "Parse a JSON number (integer)."
  (let ((start (json-parser-pos p))
        (src (json-parser-source p)))
    ;; Leading minus
    (when (eql (parser-peek p) #\-) (parser-next p))
    ;; Digit sequence
    (loop while (and (parser-peek p) (digit-char-p (parser-peek p)))
          do (parser-next p))
    (parse-integer (subseq src start (json-parser-pos p)))))

(defun parse-json-value (p)
  "Parse a JSON value."
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
  "Convert a JSON key string to a keyword symbol.
   \"turn_id\" -> :TURN-ID, \"_schema\" -> :_SCHEMA"
  (intern (string-upcase (substitute #\- #\_ key-string))
          :keyword))

(defun parse-json-object (p)
  "Parse a JSON object. Assumes the opening { has already been consumed.
   Returns an alist."
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
  "Parse a JSON string and return an alist."
  (let ((p (make-json-parser :source string)))
    (parse-json-value p)))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; File I/O
;;;; ═══════════════════════════════════════════════════════════════════

(defun read-coglog ()
  "Read current.json and return it as an alist. Returns NIL if the file does not exist."
  (when (probe-file *current-file*)
    (let ((content (with-open-file (in *current-file*
                                    :direction :input
                                    :external-format :utf-8)
                     (let ((buf (make-string (file-length in))))
                       (read-sequence buf in)
                       buf))))
      (parse-json content))))

(defun write-coglog (args-plist)
  "Validate ARGS-PLIST (plist) and write to current.json.
   Returns the written entry (alist)."
  (validate-args args-plist)
  (ensure-directories-exist *current-file*)
  (let* ((prev (read-coglog))
         (timestamp (utc-timestamp))
         (entry (advance prev args-plist timestamp))
         (json (entry-to-json entry)))
    (with-open-file (out *current-file*
                     :direction :output
                     :if-exists :supersede
                     :external-format :utf-8)
      (write-string json out))
    entry))

(defun clear-coglog ()
  "Delete current.json. Returns the result as an alist."
  (cond
    ((probe-file *current-file*)
     (delete-file *current-file*)
     '((:cleared . t)))
    (t
     '((:cleared . nil)
       (:reason . "no existing coglog")))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; CLI
;;;; ═══════════════════════════════════════════════════════════════════

(defun read-stdin ()
  "Read all content from stdin and return it as a string."
  (with-output-to-string (out)
    (loop for line = (read-line *standard-input* nil nil)
          while line
          do (write-string line out)
             (terpri out))))

(defun json-to-args-plist (json-string)
  "Parse a JSON string and convert it to a flat plist."
  (let ((alist (parse-json json-string)))
    (loop for (key . val) in alist
          collect key
          collect val)))

(defun usage ()
  (format t "usage: coglog <read|write|clear>~%~%")
  (format t "  read    — display the previous turn's coglog~%")
  (format t "  write   — save current turn (reads JSON from stdin)~%")
  (format t "  clear   — reset coglog~%"))

(defun main ()
  (let* ((all-args #+sbcl sb-ext:*posix-argv*
                   #-sbcl (list "coglog"))
         ;; Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
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
                 (let ((entry (read-coglog)))
                   (if entry
                       (format t "~a" (entry-to-json entry))
                       (format t "(no coglog found)~%"))))
                ((string= cmd "write")
                 (let* ((input (read-stdin))
                        (plist (json-to-args-plist input))
                        (entry (write-coglog plist)))
                   (format t "coglog: turn ~d written~%"
                           (cdr (assoc :turn-id entry)))))
                ((string= cmd "clear")
                 (let ((result (clear-coglog)))
                   (if (cdr (assoc :cleared result))
                       (format t "coglog: cleared~%")
                       (format t "coglog: ~a~%"
                               (cdr (assoc :reason result))))))
                (t
                 (usage)
                 (sb-ext:exit :code 1)))
            (validation-error (e)
              (format *error-output* "coglog error: ~a~%" e)
              (sb-ext:exit :code 1))
            (error (e)
              (format *error-output* "coglog error: ~a~%" e)
              (sb-ext:exit :code 1)))))))

(main)

;;;; ═══════════════════════════════════════════════════════════════════
;;;; End of adapter.lisp
;;;; ═══════════════════════════════════════════════════════════════════
