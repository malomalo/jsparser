# To make testing/debugging easier, test within this source tree versus an
# installed gem
$LOAD_PATH << File.expand_path('../lib', __FILE__)

# require 'simplecov'
# SimpleCov.start do
#   add_group 'lib', 'condenser/lib'
#   add_group 'ext', 'condenser/ext'
# end

require 'jsanalyzer'

require "minitest/autorun"
require 'minitest/unit'
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
end