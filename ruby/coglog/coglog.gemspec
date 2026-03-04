Gem::Specification.new do |s|
  s.name        = "coglog"
  s.version     = "0.9.1"
  s.summary     = "CogLog — a meta-cognition log for LLMs"
  s.description = "CogLog provides scaffolding for temporal cognition mimicry in LLMs."
  s.authors     = ["HarmoniaEpic"]
  s.license     = "MIT"
  s.homepage    = "https://github.com/HarmoniaEpic/coglog"
  s.metadata    = { "source_code_uri" => "https://github.com/HarmoniaEpic/coglog/tree/main/ruby/coglog" }

  s.required_ruby_version = ">= 3.0"
  s.files       = ["lib/coglog.rb"]
  s.executables = ["coglog-cli"]
  s.require_paths = ["lib"]
end
