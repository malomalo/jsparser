require 'test_helper'

class JSParser::StatementTest < Minitest::Test

  test 'while and do while' do
    assert_parse("while (i < 3) i++;", <<~JS)
        while (i < 3) {
            i++;
        };
    JS
    assert_parse("do { i++; } while (i < 3);", <<~JS)
        do {
            i++;
        } while (i < 3);
    JS
  end

  test 'try catch finally' do
    assert_parse("try { a(); } catch (e) { b(e); } finally { c(); }", <<~JS)
        try {
            a();
        } catch (e) {
            b(e);
        } finally {
            c();
        };
    JS
    assert_parse("try { a() } catch { }", <<~JS)
        try {
            a();
        } catch { };
    JS
  end

  test 'switch' do
    assert_parse("switch (x) { case 1: a(); break; case 2: default: b(); }", <<~JS)
        switch (x) {
            case 1:
                a();
                break;
            case 2:
            default:
                b();
        };
    JS
  end

  test 'throw' do
    assert_parse('throw new Error("x");', 'throw new Error("x");')
  end

  test 'block statements' do
    assert_parse("{ let a = 1; }", <<~JS)
        {
            let a = 1;
        };
    JS
  end

  test 'empty statements and bare return' do
    assert_parse("function f() { a();; b(); return; }", <<~JS)
        function f() {
            a();
            b();
            return;
        };
    JS
  end

  test 'labels' do
    assert_parse("outer: for (;;) { break outer; }", <<~JS)
        outer: for (;;) {
            break outer;
        };
    JS
  end

  test 'await' do
    assert_parse("const f = async (x) => await g(x);", "const f = async (x) => await g(x);")
    assert_parse("async function f() { await g(); }", <<~JS)
        async function f() {
            await g();
        };
    JS
  end

  test 'using declarations' do
    assert_parse("{ using a = f(), b = g() }", <<~JS)
        {
            using a = f(), b = g();
        };
    JS
    assert_parse("async function f() { await using a = g(); for (await using b of c) {} }", <<~JS)
        async function f() {
            await using a = g();
            for (await using b of c) { };
        };
    JS
    assert_parse("for (using a of b) {}", "for (using a of b) { };")

    block = JSParser.parse("{ using a = f(); a.x }").scopes.find { it.kind == :block }
    assert_equal 'using', block.variables.first.kind
    assert_equal 1, block.variables.first.references.size
  end

  test 'using is a name unless a name follows it on the same line' do
    assert_parse("using(x)", "using(x);")
    assert_parse("using[0] = 1", "using[0] = 1;")
    assert_parse("for (using of xs) {}", "for (using of xs) { };")
    assert_parse("{ using\n x = 1 }", <<~JS)
        {
            using;
            x = 1;
        };
    JS
    assert_parse("async function f() { await using(x) }", <<~JS)
        async function f() {
            await using(x);
        };
    JS
  end

  test 'using declarations need a name, an initializer and a block' do
    ['{ using a }', '{ using { a } = b }', 'using a = b',
     'switch (x) { case 1: using a = b }'].each do |source|
      assert_raises(JSParser::SyntaxError, source) { JSParser.parse(source) }
    end
    assert_parse("{ using a = b }", "{\n    using a = b;\n};")
    assert_equal "using a = b;", JSParser.parse("using a = b", source_type: :module).to_js.rstrip
  end

end
