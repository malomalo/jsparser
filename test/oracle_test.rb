require 'test_helper'
require_relative 'oracle/oracle'

# Checks every file in test/oracle/fixtures with acorn: JSParser's output is
# valid, has the same tree as the original, and prints the same when parsed
# again. Needs node and acorn (npm install in test/oracle).
class JSParser::OracleTest < Minitest::Test

  FIXTURES = File.expand_path('oracle/fixtures', __dir__)

  test 'fixtures match acorn' do
    unless JSParser::Oracle.available?
      # CI sets REQUIRE_ORACLE so a missing install fails instead of passing
      flunk "node and acorn aren't installed (npm install in test/oracle)" if ENV['REQUIRE_ORACLE']
      skip "needs node and acorn (npm install in test/oracle)"
    end

    files = Dir.glob(File.join(FIXTURES, '**', '*.js')).sort
    failures = JSParser::Oracle.results(files).reject { it['status'] == 'ok' }

    assert_empty failures, failures.map { |f|
      "#{f['source'].delete_prefix(FIXTURES + '/')}: #{f['status']}\n    #{f['detail']}"
    }.join("\n")
  end

end
