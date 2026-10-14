require 'test_helper'

class JSAnalyzer::ForLoopTest < Minitest::Test

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
  
  test "initializtion block with in syntax not accepted" do
    input = <<~JS
        // Parenthesize the whole initializer
        for (let a = ("start" in window ? window.start : 0); i < 9; i++) {
            console.log(i);
        }
        
        // Parenthesize the `in` expression
        for (let b = ("start" in window) ? window.start : 0; i < 9; i++) {
            console.log(i);
        }
    JS
    
    assert_parse(input, <<~JS)
        // Parenthesize the whole initializer
        for (let a = ("start" in window ? window.start : 0); i < 9; i++) {
            console.log(i);
        };
        // Parenthesize the `in` expression
        for (let b = ("start" in window) ? window.start : 0; i < 9; i++) {
            console.log(i);
        };
    JS
  end
  
  test "optional expressions" do
    input = <<~JS
        for (let j = 0; ; j++) {
            console.log(j);
            if (j > 3) break;
            // more statements
        }

        let i = 0;
        for (;;) {
            if (i > 3) break;
            console.log(i);
            i++;
        }
    JS
    
    assert_parse(input, <<~JS)
        for (let j = 0; ; j++) {
            console.log(j);
            if (j > 3) {
                break;
            };
            // more statements
        };
        let i = 0;
        for (;;) {
            if (i > 3) {
                break;
            };
            console.log(i);
            i++;
        };
    JS
  end

  test "for in and for of" do
    input = <<~JS
        for (const key in object) {
            console.log(key);
        }
        for (const value of [1, 2]) console.log(value);
        for (x of xs) continue;
    JS

    assert_parse(input, <<~JS)
        for (const key in object) {
            console.log(key);
        };
        for (const value of [1, 2]) {
            console.log(value);
        };
        for (x of xs) {
            continue;
        };
    JS
  end

  test "body without braces" do
    assert_parse("for (let i = 0; i < 3; i++) total += i;", <<~JS)
        for (let i = 0; i < 3; i++) {
            total += i;
        };
    JS
  end

end
