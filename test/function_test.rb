require 'test_helper'

class JSAnalyzer::FunctionTest < Minitest::Test

  test 'regular function definintions' do
    input = <<~JS
        function property(parameters) {}
    JS
    
    assert_parse(input, <<~JS)
        function property(parameters) { };
    JS
  end
  
  test 'generator function definintions' do
    input = <<~JS
        function* property(parameters) {}
        function *property2(parameters) {}
    JS
    
    assert_parse(input, <<~JS)
        function *property(parameters) { };
        function *property2(parameters) { };
    JS
  end

  test 'async function definintions' do
    input = <<~JS
        async function property(parameters) {}
    JS
    
    assert_parse(input, <<~JS)
        async function property(parameters) { };
    JS
  end

  test 'async generator function definintions' do
    input = <<~JS
        async function* property(parameters) {}
        async function *property2(parameters) {}
    JS
    
    assert_parse(input, <<~JS)
        async function *property(parameters) { };
        async function *property2(parameters) { };
    JS
  end
  
end


