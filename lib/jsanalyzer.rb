# frozen_string_literal: true

class JSAnalyzer
  
  autoload :Node, 'js_analyzer/node'

  class SyntaxError < StandardError; end

  # source_type: :script (the default, as in acorn) or :module. Module code
  # is strict, which changes how functions declared in blocks are scoped.
  def self.parse(source, source_type: :script)
    JSAnalyzer::Parser.parse(source, source_type: source_type)
  end

end

require 'js_analyzer/version'
require 'js_analyzer/tokenizer'
require 'js_analyzer/parser'
