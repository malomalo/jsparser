require 'test_helper'

class JSParser::ArrowFunctionTest < Minitest::Test
 
  test 'arrow function with parens and without block' do
    input = <<~JS
        () => expression;
        (param) => expression;
        (param1, paramN) => expression
        async () => expression
        async (param3) => expression
        async (param4, param5) => expression
    JS
    
    assert_parse(input, <<~JS)
        () => expression;
        (param) => expression;
        (param1, paramN) => expression;
        async () => expression;
        async (param3) => expression;
        async (param4, param5) => expression;
    JS
  end
  
  test 'arrow function with parens and with block' do
    input = <<~JS
        () => { statementa; statementb }
        (param1) => { statementa; statementb }
        (param1, paramN) => { statementa; statementb }
    JS
    
    assert_parse(input, <<~JS)
        () => {
            statementa;
            statementb;
        };
        (param1) => {
            statementa;
            statementb;
        };
        (param1, paramN) => {
            statementa;
            statementb;
        };
    JS
  end
  
  test 'arrow function without parens and without block ' do
    input = <<~JS
        param => expression
    JS
    
    assert_parse(input, <<~JS)
        (param) => expression;
    JS
  end
  
  test 'arrow function without parens and with block ' do
    input = <<~JS
        param => { statements }
    JS
    
    assert_parse(input, <<~JS)
        (param) => {
            statements;
        };
    JS
  end
 
end