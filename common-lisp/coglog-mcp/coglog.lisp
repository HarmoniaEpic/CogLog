;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog — Common Lisp Pure Core
;;;;
;;;; This file is an annotation from the homoiconicity perspective in DESIGN-v0.9.1.md.
;;;; It can be loaded into SBCL without adapter.lisp.
;;;; It has no dependencies on JSON or the filesystem.
;;;; ═══════════════════════════════════════════════════════════════════

(defpackage :coglog
  (:use :cl)
  (:export #:make-schema
           #:validate-args
           #:advance
           #:+schema-version+))

(in-package :coglog)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Chapter 1: The Recurrence Relation as S-Expressions
;;;; ═══════════════════════════════════════════════════════════════════

;;; The core of CogLog is the recurrence relation a_{n+1} = f(a_n, x_n).
;;;
;;; In the 5 practical-layer implementations (Python, Node.js, C++, Rust, various MCPs),
;;; this recurrence relation is implemented as JSON reading and writing.
;;; f is a function that "reads the previous entry, constructs a new entry, and writes it to a file,"
;;; mixing side effects (file I/O, timestamp retrieval) with pure construction.
;;;
;;; In Common Lisp, f is described as a data transformation.
;;; Both input and output are the same S-expressions (alists),
;;; with no distinction between "data format" and "code format."
;;; This is what homoiconicity — the identity of code and data — means.


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Chapter 2: The World of Types
;;;; ═══════════════════════════════════════════════════════════════════

;;; CogLog's data structure is composed of three layers.
;;;
;;;   Metadata layer (_schema) — how to read this data
;;;   Fact layer (layers)      — what happened
;;;   Interpretation layer (4 fields) — how it was interpreted
;;;
;;; In the Haskell version, the difference in validation rules between
;;; the fact and interpretation layers is expressed as a type difference
;;; (NonEmptyText vs String).
;;; A world where the compiler enforces constraints.
;;;
;;; Common Lisp takes a different approach.
;;; It uses alists for internal representation. The alist keys are field names,
;;; and the values are strings. The type distinction is handled at runtime by validate-args.
;;;
;;; This choice has trade-offs.
;;; Instead of paying the cost of type safety, constraint descriptions are direct and readable.
;;; And alists can be printed and read as S-expressions —
;;; a property that defstruct does not have.

;;; An Entry is represented as an alist with the following keys:
;;;
;;;   :_schema       — metadata layer (alist)
;;;   :turn-id       — monotonically increasing turn number (integer)
;;;   :timestamp     — write time (ISO 8601 string)
;;;   :layers        — fact layer (alist: :user, :thinking, :assistant)
;;;   :current-focus — interpretation layer, present direction (string)
;;;   :theory-of-mind — interpretation layer, other direction (string)
;;;   :self-narrative — interpretation layer, self direction (string)
;;;   :annotation    — interpretation layer, future direction (string)

;;; Fact layer keys. Require non-empty strings.
(defparameter +fact-keys+ '(:user :thinking :assistant))

;;; Interpretation layer keys. Require strings, but accept empty.
;;; "Choosing not to write is itself a metacognitive act."
(defparameter +interpretation-keys+
  '(:current-focus :theory-of-mind :self-narrative :annotation))

;;; All field keys (fact layer + interpretation layer).
(defparameter +all-field-keys+ (append +fact-keys+ +interpretation-keys+))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Chapter 3: validate — Declaring Constraints
;;;; ═══════════════════════════════════════════════════════════════════

;;; Validation is performed before Entry construction.
;;;
;;; In the Haskell version, the NonEmptyText constructor function acts as a gatekeeper.
;;; Once the type is successfully constructed, the value is guaranteed to be non-empty.
;;;
;;; In the Common Lisp version, validate-args traverses all fields.
;;; If a fact layer field is missing or an empty string, it signals a condition.
;;; If an interpretation layer field is missing, it is an error, but empty strings are accepted.
;;;
;;; In both approaches, an Entry constructed from args that passed validate
;;; is guaranteed to satisfy the constraints. The only difference is whether
;;; the guarantee comes from types or conditional branches.

(define-condition validation-error (simple-error) ()
  (:documentation "Indicates a non-empty constraint violation in the fact layer."))

(defun validate-args (args)
  "Check that ARGS (plist) satisfies CogLog's validation rules.
   Fact layer: non-empty string required. Interpretation layer: string required, empty OK.
   Signals validation-error on violation. Returns NIL on success."
  ;; Fact layer: existence + non-empty
  (dolist (key +fact-keys+)
    (let ((val (getf args key)))
      (unless (and (stringp val) (plusp (length val)))
        (error 'validation-error
               :format-control "missing required field: ~(~a~)"
               :format-arguments (list key)))))
  ;; Interpretation layer: existence (must be a string)
  (dolist (key +interpretation-keys+)
    (let ((val (getf args key)))
      (unless (stringp val)
        (error 'validation-error
               :format-control "missing required field: ~(~a~)"
               :format-arguments (list key)))))
  nil)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Chapter 4: _schema — Why Data Describes Itself
;;;; ═══════════════════════════════════════════════════════════════════

;;; This is the heart of the Common Lisp version's reason for existence.
;;;
;;; In the 5 practical-layer implementations, _schema is "a description
;;; embedded within a JSON object." It is data, not code. It is read by LLMs,
;;; not by language runtimes.
;;;
;;; In Common Lisp, the situation is different.
;;; The value returned by make-schema is an alist, which is itself
;;; data readable by the Lisp reader. It can be taken in as an S-expression with (read),
;;; evaluated with (eval), and output with (print).
;;; There is no structural distinction between the code that generates data
;;; and the data that code generates.
;;;
;;; Gibson's affordance was "the environment providing possibilities for action to the agent."
;;; S-expressions provide possibilities of reading, evaluation, and transformation
;;; at the syntactic level to the agent (Lisp reader / evaluator).
;;; _schema is an attempt to partially bring this property to JSON,
;;; and is an unnecessary device in the world of S-expressions — which is precisely why
;;; the contrast with S-expressions clarifies why _schema is necessary in JSON.
;;;
;;; JSON is not homoiconic.
;;; {"key": "value"} is a string, not a program.
;;; That is why a "reading guide" called _schema must be attached.
;;; With S-expressions, (:key . "value") becomes a data structure the moment it is read,
;;; and the key name itself functions as a schema.

(defparameter +schema-version+ "0.9.1")  ; @coglog-version

(defun make-schema ()
  "Generate the CogLog _schema.
   The return value is an alist that is self-contained as an S-expression."
  `((:version . ,+schema-version+)
    (:fact-layer
     . ((:user . "non-empty string required — user's original utterance")
        (:thinking . "non-empty string required — AI's full thinking process")
        (:assistant . "non-empty string required — AI's original output")))
    (:interpretation-layer
     . ((:current-focus . "string required, empty OK — present: what am I working on?")
        (:theory-of-mind . "string required, empty OK — other: what is the user's state?")
        (:self-narrative . "string required, empty OK — self: who am I in this moment?")
        (:annotation . "string required, empty OK — future: what should I do next?")))
    (:constraints
     . ((:window-size . "1 turn (overwritten each write)")
        (:interpretation-empty . "choosing not to write is itself a metacognitive act")))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Chapter 5: advance — Transformation
;;;; ═══════════════════════════════════════════════════════════════════

;;; advance corresponds to f in the recurrence relation.
;;;
;;; In the Haskell version, the type signature declares this function's properties:
;;;
;;;   advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry
;;;
;;; "Takes a Maybe Entry, WriteArgs, and UTCTime, and returns an Entry.
;;;  IO does not appear in the type — meaning there are no side effects."
;;;
;;; Common Lisp has no such declaration.
;;; However, reading the body of advance reveals the absence of side effects.
;;; There are no side-effecting calls to setf, setq, write, or format.
;;; The backquote template simply constructs and returns a new alist.
;;;
;;; Haskell "guarantees the absence of side effects through types."
;;; Common Lisp "demonstrates the absence of side effects through code."
;;; The strength of the guarantee differs, but at CogLog's scale, readability suffices.

(defun advance (prev args timestamp)
  "Construct a new entry (alist) from the previous entry PREV (alist or NIL),
   ARGS (plist), and TIMESTAMP (string). Pure function. No side effects.
   ARGS must have already passed through validate-args."
  (let ((turn-id (1+ (or (cdr (assoc :turn-id prev)) 0))))
    `((:_schema    . ,(make-schema))
      (:turn-id    . ,turn-id)
      (:timestamp  . ,timestamp)
      (:layers     . ((:user      . ,(getf args :user))
                      (:thinking  . ,(getf args :thinking))
                      (:assistant . ,(getf args :assistant))))
      (:current-focus   . ,(getf args :current-focus))
      (:theory-of-mind  . ,(getf args :theory-of-mind))
      (:self-narrative   . ,(getf args :self-narrative))
      (:annotation      . ,(getf args :annotation)))))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; Appendix: Reading advance as a Template
;;;; ═══════════════════════════════════════════════════════════════════

;;; Look again at advance above.
;;;
;;; `((:_schema . ,(make-schema))
;;;   (:turn-id . ,turn-id)
;;;   ...)
;;;
;;; The backquote (`) means "use this S-expression as a template."
;;; The comma (,) means "evaluate only this part."
;;; In other words, the body of advance is
;;; "the Entry structure written out directly, with holes opened only for dynamic parts."
;;;
;;; To do the same in JSON, you need string templates or object literal construction.
;;; Python: entry = {"_schema": SCHEMA, "turn_id": turn_id, ...}
;;; Rust:   Entry { _schema: make_schema(), turn_id, ... }
;;;
;;; In both cases, "the shape of data" and "the shape of code" differ.
;;; Python's dictionary literal is Python syntax, not JSON.
;;; Rust's struct literal is Rust syntax, not JSON.
;;;
;;; In S-expression backquote templates,
;;; the shape of the output data and the shape of the code that generates it are the same.
;;; This is the concrete meaning of homoiconicity.

;;; ═══════════════════════════════════════════════════════════════════
;;; End of coglog.lisp
;;; ═══════════════════════════════════════════════════════════════════
