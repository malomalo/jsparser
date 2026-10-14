require 'test_helper'

class JSParser::ModuleTest < Minitest::Test

  SOURCE = <<~JS
    import render, { html as h, "x-y" as xy } from "./view.js";
    import * as utils from "./utils.js";
    import "./styles.css";
    export const { a, b: [c] } = o, d = 1;
    export function go() {}
    export class Widget {}
    export { render as default, utils };
    export * from "./more.js";
    export * as all from "./all.js";
    export { x as y } from "./view.js";
    h();
  JS

  def program
    @program ||= JSParser.parse(SOURCE)
  end

  test 'imports' do
    view, utils, styles = program.imports

    assert_equal %w(./view.js ./utils.js ./styles.css), program.imports.map(&:source)
    assert_equal [%w(default render), %w(html h), %w(x-y xy)], view.specifiers.map { [it.imported, it.local.name] }
    assert_equal [%w(* utils)], utils.specifiers.map { [it.imported, it.local.name] }
    assert_empty styles.specifiers
    assert(view.specifiers.all? { it.local.kind == 'import' })
  end

  test 'unused imports have no references' do
    unused = program.imports.flat_map(&:specifiers).map(&:local).select { it.references.empty? }
    assert_equal %w(xy), unused.map(&:name)
  end

  test 'exports' do
    names = program.exports.map(&:exported_names)
    assert_equal [%w(a c d), %w(go), %w(Widget), %w(default utils), [], %w(all), %w(y)], names
    assert_equal [nil, nil, nil, nil, './more.js', './all.js', './view.js'], program.exports.map(&:source)
    assert_equal [false, false, false, false, true, false, false], program.exports.map(&:star?)
    assert_equal %w(VariableStatement Method Class), program.exports.first(3).map { it.declaration.class.name.split('::').last }
  end

  test 'the program as a module' do
    assert program.module?
    assert program.default_export?
    assert_equal %w(a c d go Widget default utils all y), program.exported_names
    assert_equal %w(./view.js ./utils.js ./styles.css ./more.js ./all.js), program.dependencies
  end

  test 'default exports' do
    assert JSParser.parse('export default 1').default_export?
    assert JSParser.parse('export default function () {}').default_export?
    assert JSParser.parse('export { default } from "m"').default_export?
    refute JSParser.parse('export const a = 1').default_export?
  end

  test 'scripts' do
    refute JSParser.parse('let a = import("m")').module?, "dynamic import doesn't make a module"
    assert JSParser.parse('let a', source_type: :module).module?
  end

end
