Gem::Specification.new do |s|
  s.name        = "coglog-mcp"
  s.version     = "0.9.1"
  s.summary     = "CogLog MCP server — a meta-cognition log for LLMs"
  s.description = "MCP (Model Context Protocol) server for CogLog."
  s.authors     = ["HarmoniaEpic"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/HarmoniaEpic/coglog"
  s.metadata    = { "source_code_uri" => "https://github.com/HarmoniaEpic/coglog/tree/main/ruby/coglog-mcp" }

  s.required_ruby_version = ">= 3.0"
  s.files       = ["lib/coglog_mcp.rb", "bin/coglog-mcp"]
  s.executables = ["coglog-mcp"]
  s.require_paths = ["lib"]
end
