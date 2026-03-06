;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog v0.9.1 — Recurrent Quine
;;;;
;;;; 自己書き換えプログラムとしての CogLog。
;;;; このファイルはプログラムであり、同時に自分自身の状態である。
;;;; write コマンドは状態を遷移させ、このファイル自身を次世代として書き換える。
;;;; ═══════════════════════════════════════════════════════════════════

;;; ── Quine と Recurrent Quine ──
;;;
;;; quine は自分自身のソースコードを出力するプログラムである。
;;;   Q → Q   （自己複製、恒等関数）
;;;
;;; recurrent quine は自分自身を遷移させるプログラムである。
;;;   Q_n → Q_{n+1}   （自己遷移、advance の適用）
;;;
;;; CogLog の漸化式 a_{n+1} = f(a_n, x_n) を、
;;; ファイル自身の書き換えとして実現する。
;;; 各世代 Q_n は完全なプログラムであり、単体で動作する。

;;; ── 4つ組 ──
;;;
;;; Q_n = (*state*, *advance-source*, *affordance*, *self-source*)
;;;
;;;   *state*           現在のエントリ        表現型
;;;   *advance-source*  変換規則              構造遺伝子
;;;   *affordance*      LLM への案内          調節配列
;;;   *self-source*     自己複製機構          DNA ポリメラーゼ
;;;
;;; 通常の運用では *state* のみが毎世代変わる。
;;; *advance-source* と *affordance* は更新を許容するが要求しない。
;;; *self-source* は事実上不変——ポリメラーゼが自身を複製する。

;;; ── バッククォート回避 ──
;;;
;;; coglog.lisp の advance はバッククォートテンプレートで書かれている:
;;;   `((:_schema . ,(make-schema)) ...)
;;; これはホモイコニシティの例示として適切である。
;;;
;;; しかし recurrent quine では使えない。
;;; バッククォートは処理系固有の内部表現に展開され、
;;; print → read の round-trip を保証できない。
;;;   `(a . ,b)  →  (SB-IMPL::BACKQ-CONS A B)   ; SBCL 固有
;;;
;;; *advance-source* は quoted form として世代をまたいで複製される。
;;; round-trip の正確さが生存条件であるため、
;;; list/cons のみを使い、標準関数だけで構成する。

;;; ── *self-path* ──
;;; write-generation がこのファイル自身を上書きするためのパス。
;;; --script モードでは *load-truename* がファイルの絶対パスを保持する。

(defvar *self-path* *load-truename*)

;;; ── *state* ──
;;; 現在のエントリ（alist）。初期状態は nil。
;;; write-self が呼ばれるたびに advance の結果で置き換わる。

(defvar *state*
 'nil)

;;; ── *advance-source* ──
;;; 変換規則。quoted defun として保持される。
;;; eval で関数定義に変換され、write-self から呼ばれる。
;;; list/cons のみ使用——バッククォート回避の理由は上述。

(defvar *advance-source*
 '(defun advance (prev args timestamp)
    (let ((turn-id (1+ (or (cdr (assoc :turn-id prev)) 0))))
      (list (cons :_schema (copy-tree *affordance*))
            (cons :turn-id turn-id) (cons :timestamp timestamp)
            (cons :layers
                  (list (cons :user (getf args :user))
                        (cons :thinking (getf args :thinking))
                        (cons :assistant (getf args :assistant))))
            (cons :current-focus (getf args :current-focus))
            (cons :theory-of-mind (getf args :theory-of-mind))
            (cons :self-narrative (getf args :self-narrative))
            (cons :annotation (getf args :annotation))))))

;;; ── *affordance* ──
;;; _schema の S式版。advance が生成するエントリの :_schema にそのまま入る。
;;; JSON 版で「データが自分の読み方を携える」ために必要だった _schema が、
;;; ここでは LLM へのアフォーダンスとして機能する。

(defvar *affordance*
 '((:version . "0.9.1")
   (:fact-layer
    (:user . "non-empty string required — user's original utterance")
    (:thinking
     . "non-empty string required — AI's full thinking process")
    (:assistant . "non-empty string required — AI's original output"))
   (:interpretation-layer
    (:current-focus
     . "string required, empty OK — present: what am I working on?")
    (:theory-of-mind
     . "string required, empty OK — other: what is the user's state?")
    (:self-narrative
     . "string required, empty OK — self: who am I in this moment?")
    (:annotation
     . "string required, empty OK — future: what should I do next?"))
   (:constraints (:window-size . "1 turn (overwritten each write)")
    (:interpretation-empty
     . "choosing not to write is itself a metacognitive act"))))

;;; ── *self-source* ──
;;; 自己複製機構。バリデーション、タイムスタンプ生成、
;;; ファイル書き換え（write-generation）、状態遷移（write-self）、
;;; リセット（clear-self）、CLI（main）を含む。
;;;
;;; write-generation は4つの defvar を順に書き出し、
;;; 末尾に eval と main の呼び出しを置く。
;;; これにより次世代 Q_{n+1} が完全なプログラムとして成立する。
;;;
;;; Q₁ 以降、この散文コメントは消える。
;;; write-generation はヘッダー1行のみを書き出す。
;;; これは世代を経た簡略化であり、設計通りである。

(defvar *self-source*
 '(progn
   (defun validate-args (args)
     (dolist (key (list :user :thinking :assistant))
       (let ((val (getf args key)))
         (unless (and (stringp val) (plusp (length val)))
           (error
            "validation: ~(~a~) is required and must be non-empty"
            key))))
     (dolist
         (key
          (list :current-focus :theory-of-mind :self-narrative
                :annotation))
       (let ((val (getf args key)))
         (unless (stringp val)
           (error "validation: ~(~a~) is required" key)))))
   (defun utc-timestamp ()
     (multiple-value-bind (sec min hour day month year)
         (decode-universal-time (get-universal-time) 0)
       (format nil "~4,'0d-~2,'0d-~2,'0dT~2,'0d:~2,'0d:~2,'0dZ" year
               month day hour min sec)))
   (defun write-generation (state adv aff self-src)
     (with-open-file
         (out *self-path* :direction :output :if-exists :supersede
          :external-format :utf-8)
       (let ((*print-case* :downcase)
             (*print-right-margin* 72)
             (*print-pretty* t)
             (*print-circle* nil))
         (format out ";;;; recurrent-quine.lisp~%~%")
         (format out "(defvar *self-path* *load-truename*)~%~%")
         (format out "(defvar *state*~% '")
         (write state :stream out)
         (format out ")~%~%")
         (format out "(defvar *advance-source*~% '")
         (write adv :stream out)
         (format out ")~%~%")
         (format out "(defvar *affordance*~% '")
         (write aff :stream out)
         (format out ")~%~%")
         (format out "(defvar *self-source*~% '")
         (write self-src :stream out)
         (format out ")~%~%")
         (format out "(eval *advance-source*)~%")
         (format out "(eval *self-source*)~%")
         (format out "(main)~%"))))
   (defun write-self (args &optional new-advance new-affordance new-self)
     (validate-args args)
     (let* ((new-state (advance *state* args (utc-timestamp)))
            (adv (or new-advance *advance-source*))
            (aff (or new-affordance *affordance*))
            (slf (or new-self *self-source*)))
       (write-generation new-state adv aff slf)
       (setf *state* new-state)
       (when new-advance
         (setf *advance-source* new-advance)
         (eval new-advance))
       (when new-affordance (setf *affordance* new-affordance))
       (when new-self
         (setf *self-source* new-self)
         (eval new-self))
       new-state))
   (defun clear-self ()
     (let ((had-state (not (null *state*))))
       (write-generation nil *advance-source* *affordance*
                         *self-source*)
       (setf *state* nil)
       had-state))
   (defun read-stdin ()
     (with-output-to-string (out)
       (loop for line = (read-line *standard-input* nil nil)
             while line
             do (write-string line out) (terpri out))))
   (defun main ()
     (let ((args *posix-argv*))
       (when (< (length args) 2)
         (format t "usage: recurrent-quine <read|write|clear>~%")
         (exit :code 0))
       (let ((cmd (second args)))
         (handler-case
          (cond
           ((string= cmd "read")
            (let ((*print-case* :downcase)
                  (*print-right-margin* 72)
                  (*print-pretty* t))
              (if *state*
                  (progn
                   (format t ";;; state~%")
                   (write *state* :stream *standard-output*)
                   (terpri))
                  (format t ";;; (no coglog found)~%"))
              (format t "~%;;; affordance~%")
              (write *affordance* :stream *standard-output*)
              (terpri)))
           ((string= cmd "write")
            (let* ((input (read-stdin))
                   (plist (read-from-string input))
                   (opt-adv (getf plist :opt-advance))
                   (opt-aff (getf plist :opt-affordance))
                   (opt-slf (getf plist :opt-self))
                   (entry (write-self plist opt-adv opt-aff opt-slf)))
              (format t "coglog: turn ~d written~%"
                      (cdr (assoc :turn-id entry)))))
           ((string= cmd "clear")
            (if (clear-self)
                (format t "coglog: cleared~%")
                (format t "coglog: no existing coglog~%")))
           (t (format t "usage: recurrent-quine <read|write|clear>~%")
            (exit :code 1)))
          (error (e) (format *error-output* "coglog error: ~a~%" e)
                 (exit :code 1)))
         (exit :code 0))))))

(eval *advance-source*)
(eval *self-source*)
(main)
