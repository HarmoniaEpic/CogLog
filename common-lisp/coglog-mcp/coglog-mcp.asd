(defsystem :coglog-mcp
  :version "0.9.1"
  :description "CogLog MCP server — a meta-cognition log for LLMs"
  :author "HarmoniaEpic"
  :license "MIT"
  :components ((:file "coglog")
               (:file "mcp-server" :depends-on ("coglog"))))
