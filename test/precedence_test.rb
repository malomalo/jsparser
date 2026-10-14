require 'test_helper'

class JSAnalyzer::PrecedenceTest < Minitest::Test

  test 'higher precedence binds tighter' do
    assert_tree('a * b + c', '((a * b) + c)')
    assert_tree('a + b * c', '(a + (b * c))')
    assert_tree('a || b && c', '(a || (b && c))')
    assert_tree('a < b == c < d', '((a < b) == (c < d))')
    assert_tree('a ?? b | c ^ d & e', '(a ?? (b | (c ^ (d & e))))')
    assert_tree('a >>> 1 << 2', '((a >>> 1) << 2)')
    assert_tree('x instanceof Y || k in o', '((x instanceof Y) || (k in o))')
  end

  test 'left associative operators' do
    assert_tree('a - b - c', '((a - b) - c)')
    assert_tree('a / b / c', '((a / b) / c)')
  end

  test 'right associative operators' do
    assert_tree('a ** b ** c', '(a ** (b ** c))')
    assert_tree('a = b = c + 1', '(a = (b = (c + 1)))')
    assert_tree('x += y * 2', '(x += (y * 2))')
  end

  test 'ternary' do
    assert_tree('a + b ? c : d', '((a + b) ? c : d)')
    assert_tree('x = a ? b : c ? d : e', '(x = (a ? b : (c ? d : e)))')
  end

  test 'prefix operators bind to their operand' do
    assert_tree('!a && b', '(!a && b)')
    assert_tree('typeof x === "string"', '(typeof x === "string")')
    assert_tree('-a + b', '(-a + b)')
    assert_tree('++i * 2', '(++i * 2)')
  end

  test 'member access and calls' do
    assert_parse('o.a.b[c].d(e)[f]', 'o.a.b[c].d(e)[f];')
    assert_parse('let p = 1, q = a + b * 2;', 'let p = 1, q = a + b * 2;')
    assert_parse('f(a, b + c, d)', 'f(a, b + c, d);')
  end

  test 'comma operator' do
    assert_tree('a, b', '(a , b)')
    assert_tree('a = 1, b = 2', '((a = 1) , (b = 2))')
    assert_parse('x = (a, b)', 'x = (a, b);')
    assert_parse('for (i = 0, j = 10; i < j; i++, j--) x();', <<~JS)
        for (i = 0, j = 10; i < j; i++, j--) {
            x();
        };
    JS
  end

  test 'commas separate list items' do
    assert_parse('let a = 1, b = [1, 2], c = {k: 1, j: 2};', 'let a = 1, b = [1, 2], c = {k: 1, j: 2};')
    assert_parse('f(a, (b, c))', 'f(a, (b, c));')
    assert_parse('f(x => x * 2, 3)', 'f((x) => x * 2, 3);')
    assert_tree('y => y + 1, z', '((y) => y + 1 , z)')
  end

  test 'a stray token raises instead of hanging' do
    assert_raises(JSAnalyzer::SyntaxError) { JSAnalyzer.parse('a )') }
  end

end
