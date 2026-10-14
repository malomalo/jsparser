require 'test_helper'

class JSAnalyzer::ExpressionTest < Minitest::Test

  test 'spread of any expression' do
    assert_parse('f(...a.b)', 'f(...a.b);')
    assert_parse('x = [...xs, ...f()]', 'x = [...xs, ...f()];')
    assert_parse('o = {...a.b, c}', 'o = {...a.b, c};')
  end

  test 'parameters with defaults, destructuring and rest' do
    assert_parse('function f({ a, b }, [c, d], e = 1, ...rest) { return a; }', <<~JS)
        function f({ a, b }, [ c, d ], e = 1, ...rest) {
            return a;
        };
    JS
  end

  test 'private member access' do
    assert_parse('x = this.#p ?? o?.#q', 'x = this.#p ?? o?.#q;')
  end

  test 'object getters, setters and methods' do
    assert_parse('o = { get x() { return 1; }, set x(v) {}, get: 1, get }', <<~JS)
        o = {get x() {
            return 1;
        }, set x(v) { }, get: 1, get};
    JS
    assert_parse('o = { async n() {}, *g() {} }', 'o = {async n() { }, *g() { }};')
  end

  test 'string escapes are kept' do
    assert_parse(%q{s = "a\"b" + 'it\'s' + "\\\\"}, %q{s = "a\"b" + 'it\'s' + "\\\\";})
    assert_parse('o = { "a-b": 1, 2: 3 }', 'o = {"a-b": 1, 2: 3};')
  end

end
