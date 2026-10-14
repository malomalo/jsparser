# frozen_string_literal: true

require 'stream_parser'

class JSAnalyzer
  
  autoload :Node, 'js_analyzer/node'

  class SyntaxError < StandardError; end

  def self.parse(source)
    JSAnalyzer::Parser.parse(source)
  end

end

require 'js_analyzer/version'
require 'js_analyzer/parser'



__END__

  def call(environment, input)
    last_postion = nil
    last_stack = nil
    while !eos?
      ...
      if last_postion == @index && last_stack == @stack.last
        syntax_error = Condenser::SyntaxError.new("Error parsing JS file with JSAnalyzer")
        syntax_error.instance_variable_set(:@path, @sourcefile)
        raise Condenser::SyntaxError, "Error parsing JS file with JSAnalyzer"
      else
        last_postion = @index
        last_stack = @stack.last
      end
    end
    
    raise Condenser::SyntaxError, "Unexpected EOF" if !@stack.empty? && @stack.last != :main
  end
  
  def unexptected_token(token)
    start = (@source.rindex("\n", @old_index) || 0) + 1
    uptop = @source.index("\n", @index) || (@old_index + @matched.length)
    lineno = @source[0..start].count("\n") + 1

    message = "Unexpected token #{token} #{@sourcefile} #{lineno.to_s.rjust(4)}:#{(@index-start)}"
    message << "\n#{lineno.to_s.rjust(4)}: " << @source[start..uptop]
    message << "\n      #{'-'* ([@index-1-start,1].max)}#{'^'*([@matched.length,1].max)}"
    message << "\n"
    
    syntax_error = Condenser::SyntaxError.new(message)
    syntax_error.instance_variable_set(:@path, @sourcefile)
    syntax_error
  end
end