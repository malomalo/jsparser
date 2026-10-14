require 'test_helper'

class JSParser::ExportTest < Minitest::Test

  test 'export statments' do
    input = <<~JS
        // Exporting declarations
        export let name1, name2/*, … */; // also var
        export const name1 = 1, name2 = 2/*, … */; // also var, let
        export function functionName() { /* … */ }
        //export class ClassName { /* … */ }
        export function* generatorFunctionName() { /* … */ }
        export const { name1, name2: bar } = o;
        export const [ name1, name2 ] = array;
        
        // Export list
        export { name1, /* …, */ nameN };
        export { variable1 as name1, variable2 as name2, /* …, */ nameN };
        export { variable1 as "string name" };
        export { name1 as default /*, … */ };
        
        // Default exports
        export default expression;
        export default function functionName() { /* … */ }
        // export default class ClassName { /* … */ }
        export default function* generatorFunctionName() { /* … */ }
        export default function () { /* … */ }
        // export default class { /* … */ }
        export default function* () { /* … */ }
        
        // Aggregating modules
        export * from "module-name";
        export * as name1 from "module-name";
        export { name1, /* …, */ nameN } from "module-name";
        export { import1 as name1, import2 as name2, /* …, */ nameN } from "module-name";
        export { default, /* …, */ } from "module-name";
        export { default as name1 } from "module-name";
    JS
    
    assert_parse(input, <<~JS)
        // Exporting declarations
        export let name1, name2; // also var
        export const name1 = 1, name2 = 2; // also var, let
        export function functionName() {
            /* … */
        };
        //export class ClassName { /* … */ }
        export function *generatorFunctionName() {
            /* … */
        };
        export const { name1, name2: bar } = o;
        export const [ name1, name2 ] = array;
        // Export list
        export { name1, nameN };
        export { variable1 as name1, variable2 as name2, nameN };
        export { variable1 as "string name" };
        export { name1 as default };
        // Default exports
        export default expression;
        export default function functionName() {
            /* … */
        };
        // export default class ClassName { /* … */ }
        export default function *generatorFunctionName() {
            /* … */
        };
        export default function () {
            /* … */
        };
        // export default class { /* … */ }
        export default function *() {
            /* … */
        };
        // Aggregating modules
        export * from "module-name";
        export * as name1 from "module-name";
        export { name1, nameN } from "module-name";
        export { import1 as name1, import2 as name2, nameN } from "module-name";
        export { default } from "module-name";
        export { default as name1 } from "module-name";
    JS
  end

  test 'export needs a declaration, list, * or default' do
    ['export v from "m"', 'export v', 'export const a = 1 from "m"'].each do |source|
      assert_raises(JSParser::SyntaxError, source) { JSParser.parse(source, source_type: :module) }
    end
    assert_parse('export async function f() {}', 'export async function f() { };')
  end

end
