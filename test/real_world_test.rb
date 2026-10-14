require 'test_helper'

# Cases found by parsing real files (node_modules, viking, Rails guides)
class JSAnalyzer::RealWorldTest < Minitest::Test

  test 'comments anywhere whitespace is allowed' do
    assert_parse("const { a, /* b */ c } = o", "const { a, c } = o;")
    assert_parse("switch (x) { case 1: a(); // next\n case 2: b(); }", <<~JS)
        switch (x) {
            case 1:
                a();
            case 2:
                b();
        };
    JS
    assert_parse("// walk\nouter: while (x) { break outer; }", <<~JS)
        outer: while (x) {
            break outer;
        };
    JS
  end

  test 'hashbang' do
    assert_parse("#!/usr/bin/env node\nrun()", "run();")
  end

  test 'template literals' do
    assert_parse('x = `$5 and ${a} \` done`', 'x = `$5 and ${a} \` done`;')
    assert_parse('html`<p>${x}</p>`', 'html`<p>${x}</p>`;')
  end

  test 'dynamic import' do
    assert_parse('import(name).then((m) => m.default)', 'import(name).then((m) => m.default);')
  end

  test 'function and class expressions continue the expression' do
    assert_parse('x = function () { a(); }.apply(this)', <<~JS)
        x = function () {
            a();
        }.apply(this);
    JS
    assert_parse('const C = class {}.name', <<~JS)
        const C = class {
        }.name;
    JS
  end

  test 'async only applies to the function after it' do
    assert_parse('x = async (a) => a || b', 'x = async (a) => a || b;')
    assert_parse('async(x)', 'async(x);')
    assert_parse('o = { async: true, async }', 'o = {async: true, async};')
  end

  test 'destructuring' do
    assert_parse('const { a, b: { c }, d = 1, ...e } = o, f = 2', 'const { a, b: { c }, d = 1, ...e } = o, f = 2;')
    assert_parse('const a = 1, [, m, d] = p', 'const a = 1, [ , m, d ] = p;')
    assert_parse('let [x, [y, z] = [], ...r] = q', 'let [ x, [ y, z ] = [], ...r ] = q;')
    assert_parse('function f({ e = {} } = {}) {}', 'function f({e = {}} = {}) { };')
  end

  test 'arrays' do
    assert_parse('x = [[], [1, , 2], [3,], [,]]', 'x = [[], [1, , 2], [3], [,]];')
  end

  test 'object keys that are keywords' do
    assert_parse('o = { class: 1, if: 2, async() {} }', 'o = {class: 1, if: 2, async() { }};')
  end

  test 'class members named get, set, static and async' do
    assert_parse("class A { get(k) { return k; } static = 1; #x\n }", <<~JS)
        class A {
            get(k) {
                return k;
            };
            static = 1;
            #x;
        };
    JS
  end

  test 'return, yield and ++ end at a new line' do
    assert_parse("function f() { if (a) return\n b() }", <<~JS)
        function f() {
            if (a) {
                return;
            };
            b();
        };
    JS
    assert_parse("a\n++b", "a;\n++b;")
  end

  test 'for await' do
    assert_parse('async function f() { for await (const c of s) x(c); }', <<~JS)
        async function f() {
            for await (const c of s) {
                x(c);
            };
        };
    JS
  end

end
