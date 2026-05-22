require 'test_helper'

class JSAnalyzer::ImportTest < Minitest::Test

  test 'import statments' do
    input = <<~JS
        import defaultExport from "module-name";
        import * as name from "module-name";
        import { export1 } from "module-name";
        import { export1 as alias1 } from "module-name";
        import { default as alias } from "module-name";
        import { export1, export2 } from "module-name";
        import { export1, export2 as alias2, /* … */ } from "module-name";
        import { "string name" as alias } from "module-name";
        import defaultExport, { export1, /* … */ } from "module-name";
        import defaultExport, * as name from "module-name";
        import "module-name";
    JS
    
    assert_parse(input, <<~JS)
        import defaultExport from "module-name";
        import * as name from "module-name";
        import { export1 } from "module-name";
        import { export1 as alias1 } from "module-name";
        import { default as alias } from "module-name";
        import { export1, export2 } from "module-name";
        import { export1, export2 as alias2 } from "module-name";
        import { "string name" as alias } from "module-name";
        import defaultExport, { export1 } from "module-name";
        import defaultExport, * as name from "module-name";
        import "module-name";
    JS
  end

end