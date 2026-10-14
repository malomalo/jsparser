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

end
