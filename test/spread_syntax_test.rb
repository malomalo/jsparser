require 'test_helper'

class JSParser::SpreadSyntaxTest < Minitest::Test
 
  test 'spread in function calls arrays and objects' do
    # Without the semicolons each line would continue the one before (no
    # semicolon is inserted before `[` or `(`)
    input = <<~JS
        myFunction(a, ...iterableObj, b);
        [1, ...iterableObj, '4', 'five', 6];
        ({ ...obj, key: 'value' })
    JS

    # A `{` that starts a statement is a block, so the object is wrapped in parens
    assert_parse(input, <<~JS)
        myFunction(a, ...iterableObj, b);
        [1, ...iterableObj, '4', 'five', 6];
        ({...obj, key: 'value'});
    JS
  end
  
end