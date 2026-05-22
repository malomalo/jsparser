require 'test_helper'

class JSAnalyzer::OptionalChainingTest < Minitest::Test
 
  test 'arrow function with parens and without block' do
    input = <<~JS
        obj?.prop
        obj?.[expr]
        func?.(args)
    JS
    
    assert_parse(input, <<~JS)
        obj?.prop;
        obj?.[expr];
        func?.(args);
    JS
  end
  
end