(defsystem :coglog
  :version "0.9.1"
  :description "CogLog — a meta-cognition log for LLMs"
  :author "HarmoniaEpic"
  :license "MIT"
  :components ((:file "coglog")
               (:file "adapter" :depends-on ("coglog"))))
