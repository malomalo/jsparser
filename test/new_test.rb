require 'test_helper'

class JSAnalyzer::NewTest < Minitest::Test

  test 'new with and without arguments' do
    assert_parse('new X', 'new X();')
    assert_parse('new X()', 'new X();')
    assert_parse('new Map([[1, 2]])', 'new Map([[1, 2]]);')
  end

  test 'new with a member expression callee' do
    assert_parse('new a.b.C(1, 2).go()', 'new a.b.C(1, 2).go();')
    assert_parse('new types[name]()', 'new types[name]();')
    assert_parse('new (getClass())()', 'new (getClass())();')
  end

end
