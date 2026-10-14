require 'test_helper'

class JSAnalyzer::SpreadSyntaxTest < Minitest::Test
 
  test 'spread in function calls arrays and objects' do
    input = <<~JS
        myFunction(a, ...iterableObj, b)
        [1, ...iterableObj, '4', 'five', 6]
        { ...obj, key: 'value' }
    JS
    
    assert_parse(input, <<~JS)
        myFunction(a, ...iterableObj, b);
        [1, ...iterableObj, '4', 'five', 6];
        {...obj, key: 'value'};
    JS
  end
  
end