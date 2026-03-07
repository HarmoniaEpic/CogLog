# frozen_string_literal: true

# CogLog — Minimal cognitive continuity for LLMs.
#
# A single-window (size 1) log that holds the previous turn's three-layer
# structure (user utterance, thinking process, assistant output) plus a
# four-axis interpretation layer (current_focus, theory_of_mind,
# self_narrative, annotation), making it available at the start of the
# next turn.

require 'json'
require 'time'
require 'fileutils'

module CogLog
  VERSION = '0.9.1'  # @coglog-version

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

  FACT_KEYS = %w[user thinking assistant].freeze
  INTERP_KEYS = %w[current_focus theory_of_mind self_narrative annotation].freeze

  class ValidationError < StandardError; end

  class CogLog
    attr_reader :data_dir, :current_file

    def initialize(data_dir: nil)
      env = ENV['COGLOG_DIR']
      env = nil if env&.empty?
      @data_dir = data_dir || env || File.join(Dir.home, '.coglog')
      @current_file = File.join(@data_dir, 'current.json')
    end

    def read
      return nil unless File.exist?(@current_file)

      JSON.parse(File.read(@current_file, encoding: 'UTF-8'))
    end

    def write(user:, thinking:, assistant:, current_focus:, theory_of_mind:, self_narrative:, annotation:)
      # Fact layer: required, non-empty
      { 'user' => user, 'thinking' => thinking, 'assistant' => assistant }.each do |key, val|
        unless val.is_a?(String) && !val.empty?
          raise ValidationError, "missing required field: #{key}"
        end
      end

      # Interpretation layer: required, empty string acceptable
      { 'current_focus' => current_focus, 'theory_of_mind' => theory_of_mind,
        'self_narrative' => self_narrative, 'annotation' => annotation }.each do |key, val|
        unless val.is_a?(String)
          raise ValidationError, "missing required field: #{key} (empty string is acceptable)"
        end
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

  # ── CLI ──────────────────────────────────────────────────────────

  USAGE = <<~TEXT
    usage: coglog-cli <read|write|clear>

      read    — display the previous turn's coglog
      write   — save current turn (reads JSON from stdin)
      clear   — reset coglog

    write expects JSON on stdin (all fields required):
      {
        "user": "user's message",
        "thinking": "AI thinking process",
        "assistant": "AI output",
        "current_focus": "what is happening right now",
        "theory_of_mind": "user intent/state inference",
        "self_narrative": "improvised self-story at this moment",
        "annotation": "note to future self"
      }

      fact layer (user, thinking, assistant): non-empty string required
      interpretation layer (current_focus, theory_of_mind,
        self_narrative, annotation): string required, empty string acceptable
  TEXT

  def self.cli(args = ARGV)
    # Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
    args = args.dup
    coglog_dir = nil
    if args[0] == '--coglog-dir' && args[1]
      coglog_dir = args[1]
      args.shift(2)
    end
    ml = CogLog.new(data_dir: coglog_dir)
    command = args[0]

    case command
    when 'read'
      entry = ml.read
      if entry.nil?
        puts '(no coglog found)'
      else
        puts JSON.pretty_generate(entry)
      end

    when 'write'
      data = JSON.parse($stdin.read)
      entry = ml.write(
        user:          data['user'],
        thinking:      data['thinking'],
        assistant:     data['assistant'],
        current_focus: data['current_focus'],
        theory_of_mind: data['theory_of_mind'],
        self_narrative: data['self_narrative'],
        annotation:    data['annotation']
      )
      puts "coglog: turn #{entry['turn_id']} written"

    when 'clear'
      result = ml.clear
      if result['cleared']
        puts 'coglog: cleared'
      else
        puts "coglog: #{result['reason']}"
      end

    else
      print USAGE
      exit(command ? 1 : 0)
    end
  rescue ValidationError => e
    warn "coglog error: #{e.message}"
    exit 1
  rescue JSON::ParserError => e
    warn "coglog error: invalid JSON: #{e.message}"
    exit 1
  rescue StandardError => e
    warn "coglog error: #{e.message}"
    exit 1
  end
end
