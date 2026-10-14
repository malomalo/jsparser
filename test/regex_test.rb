require 'test_helper'

# More regex cases (character classes, regexes after a `)` or in argument
# lists, and `/` as division) are oracle fixtures in test/oracle/fixtures
class JSParser::RegexTest < Minitest::Test

  test 'a regex after a function call or for loop' do
    assert_parse('for(const s in r)/^(request|service)$/i.test(s)&&delete r[s];', <<~JS)
        for (const s in r) {
            /^(request|service)$/i.test(s) && delete r[s];
        };
    JS
  end

end
