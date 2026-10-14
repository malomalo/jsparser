require 'test_helper'

class JSParserTest < Minitest::Test

  test 'literals and parentheses' do
    # Parens are kept; dropping them can change the meaning, e.g. (1 + 2) * 3
    assert_parse("(1 + (2+3))", "(1 + (2 + 3));")

    assert_parse("var t = true", "var t = true;")

    assert_parse("true", "true;")

    assert_parse('"true"', '"true";')

    assert_parse("'true'", "'true';")
  end

end
