require 'test_helper'

class JSParser::CommentTest < Minitest::Test

  test 'comments on their own line and after code' do
    assert_parse(<<~JS, <<~JS)
        // Section
        const a = 1; // the answer
        /* before b */ let b;
    JS
        // Section
        const a = 1; // the answer
        /* before b */
        let b;
    JS
  end

  test 'block comments are reindented' do
    assert_parse(<<~JS, <<~JS)
        if (x) {
              /**
                 * Adds.
                 * @param {number} x
                 */
          add(x);
        }
    JS
        if (x) {
            /**
             * Adds.
             * @param {number} x
             */
            add(x);
        };
    JS
  end

  test 'comments at the end of blocks, class bodies and the program' do
    assert_parse(<<~JS, <<~JS)
        function f() {
          a();
          // last
        }
        class A {
          m() {} // m
          // end of class
        }
        // end of file
    JS
        function f() {
            a();
            // last
        };
        class A {
            m() { }; // m
            // end of class
        };
        // end of file
    JS
  end

  test 'a comment-only block or program' do
    assert_parse("{ /* nothing */ }", "{\n    /* nothing */\n};")
    assert_parse("// just a comment", "// just a comment")
  end

  test 'comments inside expressions are not kept' do
    assert_parse("f(a, /* b */ c); o = { k: /* v */ 1 };", "f(a, c);\no = {k: 1};")
  end

  test 'comments are Comment nodes in statement lists' do
    program = JSParser.parse("a(); // why\n// next\nb();")
    comments = program.statements.grep(JSParser::Node::Comment)

    assert_equal ["// why", "// next"], comments.map(&:text)
    assert_equal [true, false], comments.map(&:trailing?)
    assert_equal 5...11, comments.first.range
  end

  test 'directives and the hashbang are kept' do
    assert_parse("#!/usr/bin/env node\n'use strict';\nrun()", "#!/usr/bin/env node\n'use strict';\nrun();")
  end

end
