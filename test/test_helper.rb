# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../../lib', __FILE__)

# require 'simplecov'
# SimpleCov.start do
#   add_group 'lib', 'condenser/lib'
#   add_group 'ext', 'condenser/ext'
# end

require 'jsanalyzer'

require 'timeout'
require "minitest/autorun"
require 'minitest/reporters'
# require "mocha/setup"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# File 'lib/active_support/testing/declarative.rb', somewhere in rails....
class Minitest::Test
  def self.test(name, &block)
    test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
    defined = instance_method(test_name) rescue false
    raise "#{test_name} is already defined in #{self}" if defined
    if block_given?
      define_method(test_name, &block)
    else
      define_method(test_name) do
        flunk "No implementation provided for #{name}"
      end
    end
  end
  
  # The parser can loop forever on input it doesn't understand; fail the test
  # instead of hanging the suite.
  PARSE_TIMEOUT = Float(ENV.fetch('PARSE_TIMEOUT', 5))

  def assert_parse(input, output)
    js = Timeout.timeout(PARSE_TIMEOUT) { JSAnalyzer.parse(input).to_js }
    assert_equal output.rstrip, js.rstrip
  end

  # Asserts how an expression is grouped by rendering binary and ternary
  # operators fully parenthesized, e.g. "a + b * c" => "(a + (b * c))"
  def assert_tree(input, output)
    program = Timeout.timeout(PARSE_TIMEOUT) { JSAnalyzer.parse(input) }
    assert_equal output, program.statements.map { tree_js(it) }.join("; ")
  end

  def tree_js(node)
    case node
    when JSAnalyzer::Node::BinaryOperator
      "(#{tree_js(node.left)} #{node.operation} #{tree_js(node.right)})"
    when JSAnalyzer::Node::Ternary
      "(#{tree_js(node.condition)} ? #{tree_js(node.a)} : #{tree_js(node.b)})"
    else
      node.to_js
    end
  end


end