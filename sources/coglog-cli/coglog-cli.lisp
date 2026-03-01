;;;; ═══════════════════════════════════════════════════════════════════
;;;; CogLog v0.9.1 — Common Lisp 純粋核
;;;;
;;;; このファイルは DESIGN-v0.9.1.md のホモイコニシティからの注釈である。
;;;; adapter.lisp なしで SBCL にロードできる。
;;;; JSON やファイルシステムへの依存は一切ない。
;;;; ═══════════════════════════════════════════════════════════════════

(defpackage :coglog
  (:use :cl)
  (:export #:make-schema
           #:validate-args
           #:advance
           #:+schema-version+))

(in-package :coglog)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; 第1章: S式としての漸化式
;;;; ═══════════════════════════════════════════════════════════════════

;;; CogLog の核は漸化式 a_{n+1} = f(a_n, x_n) である。
;;;
;;; 実用層の5実装（Python, Node.js, C++, Rust, MCP各種）では
;;; この漸化式は JSON の読み書きとして実装されている。
;;; f は「前のエントリを読み、新しいエントリを構築し、ファイルに書く」関数であり、
;;; 副作用（ファイル I/O, タイムスタンプ取得）と純粋な構築が混在している。
;;;
;;; Common Lisp において、f はデータ変換として記述される。
;;; 入力も出力も同じ S式（alist）であり、
;;; 「データの形式」と「コードの形式」の区別がない。
;;; これがホモイコニシティ——コードとデータの同質性——の意味するところである。


;;;; ═══════════════════════════════════════════════════════════════════
;;;; 第2章: 型の世界
;;;; ═══════════════════════════════════════════════════════════════════

;;; CogLog のデータ構造は三つの層で構成される。
;;;
;;;   メタデータ層 (_schema) — このデータの読み方
;;;   事実層 (layers)        — 何があったか
;;;   解釈層 (4フィールド)   — それをどう読んだか
;;;
;;; Haskell 版では、事実層と解釈層のバリデーション規則の違いを
;;; 型の違い（NonEmptyText vs String）として表現する。
;;; コンパイラが制約を強制する世界。
;;;
;;; Common Lisp では別のアプローチを取る。
;;; 内部表現に alist を使う。alist のキーがフィールド名であり、
;;; 値が文字列である。型の区別は実行時の validate-args が担う。
;;;
;;; この選択にはトレードオフがある。
;;; 型安全のコストを払わない代わりに、制約の記述が直接的で読みやすい。
;;; そして、alist は S式として印字・読み取り可能である——
;;; defstruct にはない性質。

;;; Entry は以下のキーを持つ alist として表現される:
;;;
;;;   :_schema       — メタデータ層（alist）
;;;   :turn-id       — 単調増加するターン番号（整数）
;;;   :timestamp     — 書き込み時刻（ISO 8601 文字列）
;;;   :layers        — 事実層（alist: :user, :thinking, :assistant）
;;;   :current-focus — 解釈層・現在方向（文字列）
;;;   :theory-of-mind — 解釈層・他者方向（文字列）
;;;   :self-narrative — 解釈層・自己方向（文字列）
;;;   :annotation    — 解釈層・未来方向（文字列）

;;; 事実層のキー。非空文字列を要求する。
(defparameter +fact-keys+ '(:user :thinking :assistant))

;;; 解釈層のキー。文字列を要求するが、空を許容する。
;;; 「書かないという判断もメタ認知的行為である。」
(defparameter +interpretation-keys+
  '(:current-focus :theory-of-mind :self-narrative :annotation))

;;; 全フィールドキー（事実層 + 解釈層）。
(defparameter +all-field-keys+ (append +fact-keys+ +interpretation-keys+))


;;;; ═══════════════════════════════════════════════════════════════════
;;;; 第3章: validate — 制約の宣言
;;;; ═══════════════════════════════════════════════════════════════════

;;; バリデーションは Entry の構築前に行われる。
;;;
;;; Haskell 版では NonEmptyText の構築関数がゲートキーパーとして機能する。
;;; 型の構築に成功した時点で、値が非空であることが保証される。
;;;
;;; Common Lisp 版では、validate-args が全フィールドを走査する。
;;; 事実層のフィールドが欠落または空文字列の場合、condition をシグナルする。
;;; 解釈層のフィールドが欠落している場合はエラーだが、空文字列は許容する。
;;;
;;; どちらのアプローチでも、validate が通過した args から構築された Entry は
;;; 制約を満たすことが保証される。保証の手段が型か条件分岐かという違いのみ。

(define-condition validation-error (simple-error) ()
  (:documentation "事実層の非空制約違反を示す。"))

(defun validate-args (args)
  "ARGS（plist）が CogLog のバリデーション規則を満たすか検査する。
   事実層: 非空文字列必須。解釈層: 文字列必須、空許容。
   違反時は validation-error をシグナルする。成功時は NIL を返す。"
  ;; 事実層: 存在 + 非空
  (dolist (key +fact-keys+)
    (let ((val (getf args key)))
      (unless (and (stringp val) (plusp (length val)))
        (error 'validation-error
               :format-control "missing required field: ~(~a~)"
               :format-arguments (list key)))))
  ;; 解釈層: 存在（文字列であること）
  (dolist (key +interpretation-keys+)
    (let ((val (getf args key)))
      (unless (stringp val)
        (error 'validation-error
               :format-control "missing required field: ~(~a~)"
               :format-arguments (list key)))))
  nil)


;;;; ═══════════════════════════════════════════════════════════════════
;;;; 第4章: _schema — なぜデータが自分を記述するか
;;;; ═══════════════════════════════════════════════════════════════════

;;; ここが Common Lisp 版の存在理由の核心である。
;;;
;;; 実用層の5実装では、_schema は「JSON オブジェクトの中に埋め込まれた説明文」
;;; である。それ自体はデータであり、コードではない。読むのは LLM であって
;;; 処理系ではない。
;;;
;;; Common Lisp では事情が異なる。
;;; make-schema が返す値は alist であり、それ自体が Lisp のリーダーで
;;; 読み込み可能なデータである。(read) で S式として取り込み、
;;; (eval) で評価し、(print) で出力できる。
;;; データを生成するコードと、そのコードが生成するデータに、
;;; 構造的な区別がない。
;;;
;;; ギブソンのアフォーダンスは「環境が行為者に行為の可能性を提供する」ことだった。
;;; S式は行為者（Lisp リーダー / 評価器）に対して、
;;; 読み取り・評価・変換の可能性を構文レベルで提供している。
;;; _schema は JSON にこの性質を部分的に持ち込む試みであり、
;;; S式の世界ではそもそも不要な工夫——だからこそ、
;;; JSON において _schema が必要である理由が S式との対比で明確になる。
;;;
;;; JSON はホモイコニックではない。
;;; {"key": "value"} は文字列であり、プログラムではない。
;;; だから _schema という「読み方の説明書」を添付する必要がある。
;;; S式なら (:key . "value") は読み込んだ瞬間にデータ構造になり、
;;; そのキーの名前自体がスキーマとして機能する。

(defparameter +schema-version+ "0.9.1")

(defun make-schema ()
  "CogLog v0.9.1 の _schema を生成する。
   返り値は alist であり、それ自体が S式として自己完結する。"
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
;;;; 第5章: advance — 変換
;;;; ═══════════════════════════════════════════════════════════════════

;;; advance は漸化式の f に対応する。
;;;
;;; Haskell 版では型シグネチャがこの関数の性質を宣言する:
;;;
;;;   advance :: Maybe Entry -> WriteArgs -> UTCTime -> Entry
;;;
;;; 「Maybe Entry と WriteArgs と UTCTime を受け取り、Entry を返す。
;;;  IO は型に現れない——つまり副作用がない。」
;;;
;;; Common Lisp にはこの宣言がない。
;;; しかし、advance の本体を見れば副作用がないことが読み取れる。
;;; setf, setq, write, format への副作用呼び出しがどこにもない。
;;; バッククォートテンプレートが新しい alist を構築して返すだけ。
;;;
;;; Haskell は「副作用がないことを型で保証する」。
;;; Common Lisp は「副作用がないことをコードで示す」。
;;; 保証の強度は異なるが、CogLog の規模では読み取り可能性で十分である。

(defun advance (prev args timestamp)
  "前のエントリ PREV（alist または NIL）と ARGS（plist）と TIMESTAMP（文字列）から
   新しいエントリ（alist）を構築する。純粋関数。副作用なし。
   ARGS は validate-args を通過済みでなければならない。"
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
;;;; 補遺: advance のテンプレートとしての読み方
;;;; ═══════════════════════════════════════════════════════════════════

;;; 上の advance を改めて見る。
;;;
;;; `((:_schema . ,(make-schema))
;;;   (:turn-id . ,turn-id)
;;;   ...)
;;;
;;; バッククォート (`) は「このS式をテンプレートとして使え」を意味する。
;;; カンマ (,) は「ここだけ評価しろ」を意味する。
;;; つまり advance の本体は
;;; 「Entry の構造をそのまま書き下ろし、動的な部分だけ穴を開けたもの」
;;; である。
;;;
;;; JSON で同じことをするには文字列テンプレートか、
;;; オブジェクトリテラルの構築が必要になる。
;;; Python: entry = {"_schema": SCHEMA, "turn_id": turn_id, ...}
;;; Rust:   Entry { _schema: make_schema(), turn_id, ... }
;;;
;;; いずれも「データの形」と「コードの形」が異なる。
;;; Python の辞書リテラルは Python の構文であり JSON ではない。
;;; Rust の構造体リテラルは Rust の構文であり JSON ではない。
;;;
;;; S式のバッククォートテンプレートでは、
;;; 出力されるデータの形と、それを生成するコードの形が同じである。
;;; これがホモイコニシティの具体的な意味である。

;;; ═══════════════════════════════════════════════════════════════════
;;; End of coglog.lisp
;;; ═══════════════════════════════════════════════════════════════════
