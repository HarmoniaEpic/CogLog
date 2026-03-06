# frozen_string_literal: true

# CogLog MCP Server v0.9.1
#
# Exposes CogLog read/write/clear as MCP tools over stdio transport.
# Single-file, zero external dependencies. Contains a complete copy of
# the CogLog class for standalone operation.
#
# Protocol: JSON-RPC 2.0 over stdio (MCP 2024-11-05)
# Transport: stdio (newline-delimited JSON)

require 'json'
require 'time'
require 'fileutils'

module CogLogMCP
  VERSION = '0.9.1'

  SCHEMA = {
    'version' => VERSION,
    'fact_layer' => {
      'user'      => "non-empty string required \u2014 user's original utterance",
      'thinking'  => "non-empty string required \u2014 AI's full thinking process",
      'assistant' => "non-empty string required \u2014 AI's original output"
    },
    'interpretation_layer' => {
      'current_focus'  => "string required, empty OK \u2014 present: what am I working on?",
      'theory_of_mind' => "string required, empty OK \u2014 other: what is the user's state?",
      'self_narrative'  => "string required, empty OK \u2014 self: who am I in this moment?",
      'annotation'     => "string required, empty OK \u2014 future: what should I do next?"
    },
    'constraints' => {
      'window_size'          => '1 turn (overwritten each write)',
      'interpretation_empty' => 'choosing not to write is itself a metacognitive act'
    }
  }.freeze

  class ValidationError < StandardError; end

  class CogLog
    def initialize(data_dir: nil)
      @data_dir = data_dir || (ENV['COGLOG_DIR'] || File.join(Dir.home, '.coglog'))
      @current_file = File.join(@data_dir, 'current.json')
    end

    def read
      return nil unless File.exist?(@current_file)
      JSON.parse(File.read(@current_file, encoding: 'UTF-8'))
    end

    def write(user:, thinking:, assistant:, current_focus:, theory_of_mind:, self_narrative:, annotation:)
      { 'user' => user, 'thinking' => thinking, 'assistant' => assistant }.each do |key, val|
        raise ValidationError, "missing required field: #{key}" unless val.is_a?(String) && !val.empty?
      end
      { 'current_focus' => current_focus, 'theory_of_mind' => theory_of_mind,
        'self_narrative' => self_narrative, 'annotation' => annotation }.each do |key, val|
        raise ValidationError, "missing required field: #{key} (empty string is acceptable)" unless val.is_a?(String)
      end
      FileUtils.mkdir_p(@data_dir)
      prev = self.read
      turn_id = prev ? prev['turn_id'] + 1 : 1
      entry = {
        '_schema'        => SCHEMA,
        'turn_id'        => turn_id,
        'timestamp'      => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        'layers'         => { 'user' => user, 'thinking' => thinking, 'assistant' => assistant },
        'current_focus'  => current_focus,
        'theory_of_mind' => theory_of_mind,
        'self_narrative'  => self_narrative,
        'annotation'     => annotation
      }
      File.write(@current_file, JSON.pretty_generate(entry) + "\n", encoding: 'UTF-8')
      entry
    end

    def clear
      if File.exist?(@current_file)
        File.delete(@current_file)
        { 'cleared' => true }
      else
        { 'cleared' => false, 'reason' => 'no existing coglog' }
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════
  # MCP tool definitions
  # ═══════════════════════════════════════════════════════════════

  TOOLS = [
    {
      'name' => 'coglog_read',
      'description' => "Read the previous turn's coglog. Returns the three-layer structure (user/thinking/assistant) plus four-axis interpretation layer (current_focus/theory_of_mind/self_narrative/annotation). Returns null if no coglog exists.",
      'inputSchema' => { 'type' => 'object', 'properties' => {}, 'additionalProperties' => false }
    },
    {
      'name' => 'coglog_write',
      'description' => "Write the current turn's coglog, overwriting the previous one. Fact layer fields (user, thinking, assistant) require non-empty strings. Interpretation layer fields (current_focus, theory_of_mind, self_narrative, annotation) require strings but accept empty strings \u2014 choosing not to write is itself a metacognitive act.",
      'inputSchema' => {
        'type' => 'object',
        'properties' => {
          'user'            => { 'type' => 'string', 'description' => "User's original utterance (non-empty)" },
          'thinking'        => { 'type' => 'string', 'description' => "AI's full thinking process (non-empty)" },
          'assistant'       => { 'type' => 'string', 'description' => "AI's original output (non-empty)" },
          'current_focus'   => { 'type' => 'string', 'description' => 'Present direction: what am I working on?' },
          'theory_of_mind'  => { 'type' => 'string', 'description' => "Other direction: what is the user's state?" },
          'self_narrative'  => { 'type' => 'string', 'description' => 'Self direction: who am I in this moment?' },
          'annotation'      => { 'type' => 'string', 'description' => 'Future direction: what should I do next?' }
        },
        'required' => %w[user thinking assistant current_focus theory_of_mind self_narrative annotation],
        'additionalProperties' => false
      }
    },
    {
      'name' => 'coglog_clear',
      'description' => 'Clear the coglog, removing the stored turn data. Returns whether the clear was successful.',
      'inputSchema' => { 'type' => 'object', 'properties' => {}, 'additionalProperties' => false }
    }
  ].freeze

  # ═══════════════════════════════════════════════════════════════
  # JSON-RPC helpers
  # ═══════════════════════════════════════════════════════════════

  def self.send_json(obj)
    $stdout.puts(JSON.generate(obj))
    $stdout.flush
  end

  def self.send_result(msg_id, result)
    send_json({ 'jsonrpc' => '2.0', 'id' => msg_id, 'result' => result })
  end

  def self.send_error(msg_id, code, message)
    send_json({ 'jsonrpc' => '2.0', 'id' => msg_id, 'error' => { 'code' => code, 'message' => message } })
  end

  def self.send_tool_result(msg_id, text, is_error: false)
    result = { 'content' => [{ 'type' => 'text', 'text' => text }] }
    result['isError'] = true if is_error
    send_result(msg_id, result)
  end

  def self.log(msg)
    $stderr.puts("coglog-mcp: #{msg}")
    $stderr.flush
  end

  # ═══════════════════════════════════════════════════════════════
  # MCP handlers
  # ═══════════════════════════════════════════════════════════════

  def self.handle_initialize(msg_id)
    send_result(msg_id, {
      'protocolVersion' => '2024-11-05',
      'capabilities' => { 'tools' => {} },
      'serverInfo' => { 'name' => 'coglog', 'version' => VERSION }
    })
  end

  def self.handle_tools_list(msg_id)
    send_result(msg_id, { 'tools' => TOOLS })
  end

  def self.handle_tools_call(msg_id, params, ml)
    name = params['name']
    args = params['arguments'] || {}

    case name
    when 'coglog_read'
      entry = ml.read
      if entry.nil?
        send_tool_result(msg_id, '(no coglog found)')
      else
        send_tool_result(msg_id, JSON.pretty_generate(entry))
      end

    when 'coglog_write'
      begin
        entry = ml.write(
          user:          args['user'],
          thinking:      args['thinking'],
          assistant:     args['assistant'],
          current_focus: args['current_focus'],
          theory_of_mind: args['theory_of_mind'],
          self_narrative: args['self_narrative'],
          annotation:    args['annotation']
        )
        send_tool_result(msg_id, JSON.pretty_generate(entry))
      rescue StandardError => e
        send_tool_result(msg_id, "Error: #{e.message}", is_error: true)
      end

    when 'coglog_clear'
      result = ml.clear
      send_tool_result(msg_id, JSON.generate(result))

    else
      send_tool_result(msg_id, "Error: unknown tool: #{name}", is_error: true)
    end
  end

  def self.handle_ping(msg_id)
    send_result(msg_id, {})
  end

  # ═══════════════════════════════════════════════════════════════
  # Main loop
  # ═══════════════════════════════════════════════════════════════

  def self.run(args = ARGV)
    # --coglog-dir <path> の解析（優先順位: 引数 > COGLOG_DIR env > デフォルト）
    args = args.dup
    coglog_dir = nil
    if args[0] == '--coglog-dir' && args[1]
      coglog_dir = args[1]
      args.shift(2)
    end
    ml = CogLog.new(data_dir: coglog_dir)
    log('server started')

    $stdin.each_line do |line|
      line = line.strip
      next if line.empty?

      begin
        msg = JSON.parse(line)
      rescue JSON::ParserError => e
        send_error(nil, -32_700, "Parse error: #{e.message}")
        next
      end

      method = msg['method']
      msg_id = msg['id']
      params = msg['params'] || {}

      # Notification (no id) — never respond
      if msg_id.nil?
        log('initialized') if method == 'notifications/initialized'
        next
      end

      # Request (has id) — must respond
      case method
      when 'initialize'    then handle_initialize(msg_id)
      when 'tools/list'    then handle_tools_list(msg_id)
      when 'tools/call'    then handle_tools_call(msg_id, params, ml)
      when 'ping'          then handle_ping(msg_id)
      else send_error(msg_id, -32_601, "Method not found: #{method}")
      end
    end

    log('server stopped')
  end
end
