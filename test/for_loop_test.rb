require 'test_helper'

class JSAnalyzer::ExportTest < Minitest::Test

  test 'for loop' do
    input = <<~JS
        for (let i = 0; i < 9; i++) {
            str += i;
        }
    JS
    
    assert_parse(input, <<~JS)
        for (let i = 0; i < 9; i++) {
            str += i;
        };
    JS
  end
  
  # test "initializtion block with in syntax not accepted" do
  #   input = <<~JS
  #       // Parenthesize the whole initializer
  #       for (let a = ("start" in window ? window.start : 0); i < 9; i++) {
  #           console.log(i);
  #       }
        
  #       // Parenthesize the `in` expression
  #       for (let b = ("start" in window) ? window.start : 0; i < 9; i++) {
  #           console.log(i);
  #       }
  #   JS
    
  #   assert_parse(input, <<~JS)
  #       for (let a = ("start" in window ? window.start : 0); i < 9; i++) {
  #           console.log(i);
  #       };
  #       for (let b = ("start" in window) ? window.start : 0; i < 9; i++) {
  #           console.log(i);
  #       };
  #   JS
  # end
  
  # test "optional expressions" do
  #   input = <<~JS
  #       for (let j = 0; ; j++) {
  #           console.log(j);
  #           if (j > 3) break;
  #           // more statements
  #       }

  #       let i = 0;
  #       for (;;) {
  #           if (i > 3) break;
  #           console.log(i);
  #           i++;
  #       }
  #   JS
    
  #   assert_parse(input, <<~JS)
  #       for (let j = 0; ; j++) {
  #           console.log(j);
  #           if (j > 3) break;
  #           // more statements
  #       }
    
  #       let i = 0;
  #       for (;;) {
  #           if (i > 3) break;
  #           console.log(i);
  #           i++;
  #       }
  #   JS
  # end
  

end
