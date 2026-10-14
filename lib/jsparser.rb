# frozen_string_literal: true

class JSParser
  
  autoload :Node, 'jsparser/node'

  class SyntaxError < StandardError; end

  # source_type: :script (the default, as in acorn) or :module. Module code
  # is strict, which changes how functions declared in blocks are scoped.
  def self.parse(source, source_type: :script)
    JSParser::Parser.parse(source, source_type: source_type)
  end

end

require 'jsparser/version'
require 'jsparser/tokenizer'
require 'jsparser/parser'
