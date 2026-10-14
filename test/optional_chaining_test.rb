require 'test_helper'

class JSAnalyzer::OptionalChainingTest < Minitest::Test
 
  test 'optional chaining on properties brackets and calls' do
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