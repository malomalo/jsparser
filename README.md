# jsparser

A JavaScript parser in Ruby. It parses JavaScript into a tree of nodes that
prints back as JavaScript, and resolves every variable reference to its
declaration, so you can see what's in scope, tell reads from writes, and
rename a variable everywhere it's used.

Requires Ruby 3.4 or newer.

```ruby
gem 'jsparser'
```

## Parsing and printing

```ruby
require 'jsparser'

program = JSParser.parse(<<~JS)
  import { render } from "./view.js";
  let count = 0; // clicks
  function increment(step = 1) {
    count += step;
    return render(count);
  }
JS

puts program.to_js
```

```js
import { render } from "./view.js";
let count = 0; // clicks
function increment(step = 1) {
    count += step;
    return render(count);
};
```

Output is normalized: four-space indentation, a `;` after each statement, and
braces around single-statement bodies (`if (a) b()` prints as a block).
Parentheses are kept as written.

Comments between statements and class members are kept (as
`JSParser::Node::Comment` nodes in statement lists), as are directives like
`"use strict"` and a `#!` line. Comments inside expressions, such as between
arguments, are dropped.

`program.statements` is the top level of the tree:

```ruby
program.statements.map(&:class)
# => [JSParser::Node::ImportStatement, JSParser::Node::VariableStatement,
#     JSParser::Node::Comment, JSParser::Node::Method]
```

### Scripts and modules

Code is parsed as a script unless you say otherwise. Module code is strict,
which changes how a function declared in a block is scoped:

```ruby
JSParser.parse(source, source_type: :module)
```

### Syntax errors

```ruby
JSParser.parse("let x = 1 2")
# JSParser::SyntaxError: unexpected "2" at 1:11
#   let x = 1 2
#             ^
```

## Variables and scopes

Each declaration of a variable is a `JSParser::Node::VariableDeclaration`, and
each use of it a `JSParser::Node::VariableReference` that points at it.
References are resolved as each scope closes, so a variable can be used before
it's declared (`f(); function f() {}`).

```ruby
count = program.declarations['count']
count.kind              # => "let"
count.location          # => [2, 5], line and column
count.references.size   # => 2
count.writes.size       # => 1, `count += step`
count.reads.size        # => 2, `count += step` and `render(count)`
```

The kinds are `var`, `let`, `const`, `param`, `function`, `class`, `import`
and `catch`. A variable that's used but never declared gets an implicit
declaration of kind `global` in the program scope (or `arguments`, in a
function), so every reference has a declaration.

A reference's `read?` is false only for the target of a plain assignment
(`x = 1`); `write?` is true for assignments, `++`/`--`, destructuring
assignment targets and `for (x of xs)`.

Scopes form a tree from the program down. Each has a `kind` (`:program`,
`:function`, `:arrow`, `:block`, `:class`, `:catch`, ...):

```ruby
program.variables.map { [it.name, it.kind] }
# => [["render", "import"], ["count", "let"], ["increment", "function"]]

function = program.scopes.find { it.kind == :function }
function.variables_in_scope.keys.sort
# => ["count", "increment", "render", "step"]
```

`variables` lists what's declared in a scope; `variables_in_scope` everything
visible from it, inner declarations hiding outer ones.

### Renaming

A declaration and all of its references share one `JSParser::Node::Identifier`,
so renaming it renames the variable everywhere:

```ruby
count.identifier.name = 'clicks'
puts program.to_js
```

```js
import { render } from "./view.js";
let clicks = 0; // clicks
function increment(step = 1) {
    clicks += step;
    return render(clicks);
};
```

`text` on a declaration or reference keeps the name as written, and `range` is
where it is in the source, as byte offsets (`source.byteslice(range)`).

## Modules

```ruby
program = JSParser.parse(<<~JS)
  import render, { html as h } from "./view.js";
  import * as utils from "./utils.js";
  export function go() {}
  export { render as default };
  export * from "./more.js";
JS

program.module?          # => true
program.dependencies     # => ["./view.js", "./utils.js", "./more.js"]
program.exported_names   # => ["go", "default"]
program.default_export?  # => true

view = program.imports.first
view.source                                      # => "./view.js"
view.specifiers.map { [it.imported, it.local.name] }
# => [["default", "render"], ["html", "h"]]
```

Each specifier's `local` is the import's `VariableDeclaration`, so
`local.references.empty?` finds unused imports. Export statements have
`exported_names`, `source` (for a re-export), `star?` (`export * from`),
`default?` and `declaration` (an exported `const`, function or class).
`exported_names` doesn't include the names of `export * from` modules.

## Speed

On a sample of 13 files from npm packages (377 KB), parsing ran at 3.6 MB/s on
Ruby 4.0.5, and 7.3–7.5 MB/s with YJIT (`ruby --yjit`), on arm64 macOS. acorn
8.19 on Node 26 parsed the same files at 29.2 MB/s.

## Development

```sh
bundle install
bundle exec rake test
```

`rake test` includes a check of every file in `test/oracle/fixtures` against
[acorn](https://github.com/acornjs/acorn), which needs Node and
`npm install` in `test/oracle` (it's skipped otherwise).

To check any folder of JavaScript the same way:

```sh
bundle exec rake oracle DIR=path/to/js
```

It parses and prints each file, then uses acorn to check that the output is
valid, has the same tree as the original, and prints the same when parsed
again.

## License

MIT
