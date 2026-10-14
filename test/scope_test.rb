require 'test_helper'

class JSParser::ScopeTest < Minitest::Test

  # Every declaration named `name` anywhere in the program, other than
  # implicit globals
  def declarations(program, name)
    program.scopes.flat_map(&:variables).select { it.name == name && it.kind != 'global' }
  end

  def declaration(program, name)
    found = declarations(program, name)
    assert_equal 1, found.size, "expected one declaration of #{name}, found #{found.inspect}"
    found.first
  end

  test 'references resolve to their declaration' do
    program = JSParser.parse("let a = 1;\nconst b = a + a;")
    a = declaration(program, 'a')

    assert_equal 'let', a.kind
    assert_equal 2, a.references.size
    assert(a.references.all? { it.declaration.equal?(a) })
    assert(a.references.all? { it.identifier.equal?(a.identifier) })
    assert_empty declaration(program, 'b').references
  end

  test 'renaming the identifier renames the declaration and every reference' do
    program = JSParser.parse("let a = 1; function f(a) { return a; } a + a;")
    outer = program.declarations['a']
    outer.identifier.name = 'renamed'

    assert_equal <<~JS, program.to_js
        let renamed = 1;
        function f(a) {
            return a;
        };
        renamed + renamed;
    JS
  end

  test 'positions and original text' do
    program = JSParser.parse("let a = 1;\n  a;")
    a = program.declarations['a']
    reference = a.references.first

    assert_equal 'a', a.text
    assert_equal 4...5, a.range
    assert_equal [1, 5], a.location
    assert_equal [2, 3], reference.location

    a.identifier.name = 'b'
    assert_equal 'a', a.text, "text is the name as written"
  end

  test 'var is declared in the function, let in the block' do
    program = JSParser.parse("function f() { { var v = 1; let l = 2; } v; l; }")
    v = declaration(program, 'v')
    l = declaration(program, 'l')

    assert_equal :function, v.scope.kind
    assert_equal :block, l.scope.kind
    assert_equal 1, v.references.size
    assert_empty l.references
    assert_equal 'global', program.declarations['l'].kind, "the l outside the block is a global"
  end

  test 'a variable can be used before it is declared' do
    program = JSParser.parse("f(); function f() {}")
    f = declaration(program, 'f')
    assert_equal 'function', f.kind
    assert_equal 1, f.references.size
  end

  test 'inner declarations hide outer ones' do
    program = JSParser.parse("let x = 1; function f() { let x = 2; return x; } x;")
    inner, outer = declarations(program, 'x').partition { it.scope.kind == :function }

    assert_equal 1, inner.first.references.size
    assert_equal 1, outer.first.references.size
  end

  test 'function parameters, including defaults and patterns' do
    program = JSParser.parse("function f(a, b = a, { c, d: e }, [g], ...h) { return a + c + e + g + h; }")
    names = program.scopes.find { it.kind == :function }.variables.map { [it.name, it.kind] }

    assert_equal [%w(a param), %w(b param), %w(c param), %w(e param), %w(g param), %w(h param)], names.sort
    assert_equal 2, declaration(program, 'a').references.size, "a in b's default and the body"
    assert_empty declarations(program, 'd'), "d is a property name, not a variable"
  end

  test 'arrow function parameters' do
    program = JSParser.parse("const f = (a, b = a, { c }) => a + c; const g = x => x;")
    arrow_scopes = program.scopes.select { it.kind == :arrow }

    assert_equal [%w(a b c), %w(x)], arrow_scopes.map { it.variables.map(&:name).sort }
    assert_equal 2, declaration(program, 'a').references.size
    assert_equal 1, declaration(program, 'x').references.size
    assert_nil program.declarations['a'], "a is not a global"
  end

  test 'catch parameters and for loop variables are scoped to them' do
    program = JSParser.parse("try {} catch (e) { e; } for (let i = 0; i < 1; i++) i; e; i;")

    assert_equal :catch, declaration(program, 'e').scope.kind
    assert_equal 1, declaration(program, 'e').references.size
    assert_equal 3, declaration(program, 'i').references.size
    assert_equal %w(e i), program.variables.select(&:implicit?).map(&:name).sort
  end

  test 'a function expression name is only visible inside it' do
    program = JSParser.parse("const f = function g() { g; }; g;")
    g = declaration(program, 'g')

    assert_equal :function, g.scope.kind
    assert_equal 1, g.references.size
    assert program.declarations['g'].implicit?
  end

  test 'imports and class names' do
    program = JSParser.parse("import a, { b as c } from 'm';\nclass K extends a {}\nnew K(c);")

    assert_equal 'import', declaration(program, 'a').kind
    assert_equal 'import', declaration(program, 'c').kind
    assert_equal 'class', declaration(program, 'K').kind
    assert_equal 1, declaration(program, 'K').references.size
    assert_equal 1, declaration(program, 'a').references.size
  end

  test 'undeclared variables are implicit globals, arguments belongs to the function' do
    program = JSParser.parse("console.log(x); function f() { return arguments; }")

    assert_equal %w(console x), program.variables.select(&:implicit?).map(&:name).sort
    assert_equal 'arguments', declaration(program, 'arguments').kind
    assert_equal :function, declaration(program, 'arguments').scope.kind
  end

  test 'this, super and null are not variables' do
    program = JSParser.parse("class A extends B { m() { return this.x ?? super.y ?? null; } }")
    assert_equal %w(B), program.variables.select(&:implicit?).map(&:name)
  end

  test 'variables in scope' do
    program = JSParser.parse("let a; function f(b) { let c; { let d; } }")
    function = program.scopes.find { it.kind == :function }
    block = function.children.find { it.kind == :block }

    assert_equal %w(a b c f), function.variables_in_scope.keys.sort
    assert_equal %w(a b c d f), block.variables_in_scope.keys.sort
  end

  test 'references are resolved as each scope closes' do
    # Later declarations in an outer scope, used by a closure parsed first
    program = JSParser.parse("function f() { return () => later + early; } let early = 1; var later = 2;")
    assert_equal 1, declaration(program, 'early').references.size
    assert_equal 1, declaration(program, 'later').references.size
    assert(program.scopes.all? { it.pending.empty? }, "nothing is left unresolved")
  end

  test 'a function in an arrow default value sees the arrow parameters' do
    program = JSParser.parse("const f = (a, b = () => a) => b;")
    assert_equal 1, declaration(program, 'a').references.size
    assert_nil program.declarations['a']
  end

  test 'arguments in an arrow function belongs to the enclosing function' do
    program = JSParser.parse("function f() { return () => arguments; }")
    assert_equal :function, declaration(program, 'arguments').scope.kind
  end

  test 'ranges are byte offsets and locations count characters' do
    source = "const café = 'naïve ✓';\nlet x = café;"
    program = JSParser.parse(source)
    cafe = program.declarations['café']
    x = program.declarations['x']

    assert_equal 'café', source.byteslice(cafe.range)
    assert_equal [1, 7], cafe.location
    assert_equal 'x', source.byteslice(x.range)
    assert_equal [2, 5], x.location
    assert_equal [2, 9], cafe.references.first.location
    assert_equal "const café = 'naïve ✓';\nlet x = café;\n", program.to_js
  end

  test 'syntax errors point at the right column after multibyte characters' do
    error = assert_raises(JSParser::SyntaxError) { JSParser.parse("x = 'ü✓' )") }
    assert_match(/at 1:10/, error.message)
  end

  # [read?, write?] for each reference to `name`, in source order
  def access(program, name)
    declaration(program, name).references.sort_by { it.range.begin }.map { [it.read?, it.write?] }
  end

  test 'references know whether they read or write' do
    program = JSParser.parse("let a = 1, b, c; a = 2; a += 1; b = a; c++; --c; f(a);")

    assert_equal [[false, true], [true, true], [true, false], [true, false]], access(program, 'a')
    assert_equal [[false, true]], access(program, 'b')
    assert_equal [[true, true], [true, true]], access(program, 'c')
    assert_equal 3, declaration(program, 'a').reads.size
    assert_equal 2, declaration(program, 'a').writes.size
  end

  test 'destructuring assignments and for loops write their targets' do
    program = JSParser.parse("let a, b, c, d, e; [a, { b, x: c }, ...d] = v; ({ e = 1 } = w); for (a of xs) {}")

    %w(b c d e).each { assert_equal [[false, true]], access(program, it), it }
    assert_equal [[false, true], [false, true]], access(program, 'a')
  end

  test 'a variable that is never reassigned has no writes' do
    program = JSParser.parse("let a = 1, b = 2; b = a;")
    assert_empty declaration(program, 'a').writes
    refute_empty declaration(program, 'b').writes
  end

  test 'default parameters are in their own scope, apart from the body' do
    program = JSParser.parse("let x = 1; function f(a = x, b = a) { var x = 2; return x + b; }")
    outer_x, body_x = declarations(program, 'x').sort_by { it.range.begin }

    assert_equal :program, outer_x.scope.kind
    assert_equal :function_body, body_x.scope.kind
    assert_equal 1, outer_x.references.size, "the x in a's default is the outer x"
    assert_equal 1, body_x.references.size
    assert_equal 1, declaration(program, 'a').references.size
  end

  test 'simple parameters share the body scope' do
    program = JSParser.parse("function f(a) { var a; return a; }")
    a = declarations(program, 'a')
    assert(a.all? { it.scope.kind == :function })
    assert program.scopes.none? { it.kind == :function_body }
  end

  test 'arguments in a default value belongs to the function' do
    program = JSParser.parse("function f(a = arguments, { b }) { return arguments; }")
    assert_equal 2, declaration(program, 'arguments').references.size
    assert_equal :function, declaration(program, 'arguments').scope.kind
  end

  test 'in non-strict code a function declared in a block is also a var' do
    program = JSParser.parse("{ function f() {} } f();")
    block_f = declarations(program, 'f').find { it.scope.kind == :block }
    var_f = program.declarations['f']

    assert var_f.block_function?
    assert_equal 1, var_f.references.size
    assert block_f.identifier.equal?(var_f.identifier), "renaming one renames both"

    block_f.identifier.name = 'g'
    assert_equal "{\n    function g() { };\n};\ng();\n", program.to_js
  end

  test 'inside a function, the var belongs to the function' do
    program = JSParser.parse("function g() { if (x) { function h() {} } return h; }")
    h = declarations(program, 'h').find(&:block_function?)
    assert_equal :function, h.scope.kind
    assert_equal 1, h.references.size
  end

  test 'in strict code a function declared in a block stays in the block' do
    ['"use strict"; { function f() {} } f();',
     'function o() { "use strict"; { function f() {} } f(); }',
     'class A { m() { { function f() {} } f(); } }'].each do |source|
      program = JSParser.parse(source)
      assert program.declarations['f'].implicit?, source
    end

    program = JSParser.parse("{ function f() {} } f();", source_type: :module)
    assert program.declarations['f'].implicit?
  end

  test 'a let, const or class of the same name means the function stays in the block' do
    ["let f; { function f() {} } f();", "{ function f() {} } let f; f();"].each do |source|
      program = JSParser.parse(source)
      assert_equal 'let', program.declarations['f'].kind, source
      assert_equal 1, program.declarations['f'].references.size, source
    end
  end

  test 'a var of the same name is the same variable' do
    program = JSParser.parse("var f; { function f() {} } f();")
    assert_equal 'var', program.declarations['f'].kind
    assert_equal 1, program.declarations['f'].references.size
    assert declarations(program, 'f').map(&:identifier).uniq.one?
  end

  test 'references in a superclass expression are in the enclosing scope' do
    program = JSParser.parse("const ns = {}; class A extends ns.Base {}")
    assert_equal 1, declaration(program, 'ns').references.size
  end

  test 'destructuring with string, number and computed keys' do
    source = "const k = 'z'; const { 'a-b': x, 0: y, [k]: z = 1, w } = o; function f({ 'q': p }) { return p; }"
    program = JSParser.parse(source)

    assert_equal "const k = 'z';\nconst { 'a-b': x, 0: y, [k]: z = 1, w } = o;\nfunction f({ 'q': p }) {\n    return p;\n};\n", program.to_js
    %w(x y z w).each { assert_equal 'const', declaration(program, it).kind, it }
    assert_equal 'param', declaration(program, 'p').kind
    assert_equal 1, declaration(program, 'k').references.size, "the computed key reads k"
    assert_empty declarations(program, 'a-b')
  end

  test 're-exported names are not variables here' do
    program = JSParser.parse('const b = 1; export { b, b as c }; export { a, x as y, default } from "m";', source_type: :module)

    assert_empty program.variables.select(&:implicit?), "a, x and default aren't globals"
    assert_equal 2, declaration(program, 'b').references.size
  end

  test 'a quoted name can only be re-exported' do
    assert_parse('export { "a-b" as c } from "m";', 'export { "a-b" as c } from "m";')
    assert_raises(JSParser::SyntaxError) { JSParser.parse('export { "a-b" };') }
  end

end
