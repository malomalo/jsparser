# frozen_string_literal: true

require 'set'

# Parses JavaScript into JSAnalyzer::Node trees, reading tokens from a
# JSAnalyzer::Tokenizer. Positions (the ranges on declarations and
# references) are byte offsets into the source.
class JSAnalyzer::Parser

  attr_reader :scope

  def self.parse(source, **options)
    new(source).parse(**options)
  end

  def initialize(source)
    @source = source
    @tokens = JSAnalyzer::Tokenizer.new(source)
  end

  ASSIGNMENT_OPERATORS = %w(= += -= *= /= %= **= <<= >>= >>>= &= |= ^= &&= ||= ??=)

  # Binding power of binary operators, higher binds tighter. See
  # https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Operator_precedence
  PRECEDENCE = {
    ',' => 1, # comma operator
    **ASSIGNMENT_OPERATORS.to_h { [it, 2] },
    '?' => 3, # ternary
    '||' => 4, '??' => 4,
    '&&' => 5,
    '|' => 6,
    '^' => 7,
    '&' => 8,
    '==' => 9, '!=' => 9, '===' => 9, '!==' => 9,
    '<' => 10, '>' => 10, '<=' => 10, '>=' => 10, 'in' => 10, 'instanceof' => 10,
    '<<' => 11, '>>' => 11, '>>>' => 11,
    '+' => 12, '-' => 12,
    '*' => 13, '/' => 13, '%' => 13,
    '**' => 14
  }
  PREFIX_PRECEDENCE = 15
  RIGHT_ASSOCIATIVE = ASSIGNMENT_OPERATORS + %w(**)

  ACCESSORS = %w(get set).freeze
  IMPORT_ATTRIBUTE_KEYWORDS = %w(with assert).freeze
  THIS_OR_SUPER = %w(this super).freeze
  FOR_IN_OF = %w(in of).freeze
  SWITCH_CASES = %w(case default).freeze

  # Keywords that start a statement, so after a complete expression they
  # start the next one
  STATEMENT_KEYWORDS = Set.new(%w(break class const continue debugger do export for function if import let return switch throw try var while with)).freeze

  # Things that can be called: f(), a.b(), a[b](), f()(), (f)(), new A()(),
  # tag`x`(), import(), super()
  CALLABLE = [
    JSAnalyzer::Node::Method, JSAnalyzer::Node::VariableReference,
    JSAnalyzer::Node::DotAccessor, JSAnalyzer::Node::BracketAccessor,
    JSAnalyzer::Node::FunctionCall, JSAnalyzer::Node::Group,
    JSAnalyzer::Node::Instantiation, JSAnalyzer::Node::TaggedTemplate,
    JSAnalyzer::Node::Keyword
  ].freeze

  def parse(source_type: :script)
    @scope = JSAnalyzer::Node::Program.new
    @scope.strict = source_type == :module || use_strict?

    parse_statement_list.each { @scope << it }
    raise syntax_error("unexpected #{peek.value.inspect}") unless peek.eof?

    @scope.source = @source
    @scope.close!
    @scope
  end

  # Tokens

  def peek(regex: false)
    @tokens.peek(regex: regex)
  end

  def advance(regex: false)
    @tokens.next(regex: regex)
  end

  def unread(token)
    @tokens.unread(token)
  end

  # Consumes the next token if it's the punctuator `value`
  def accept(value)
    advance if peek.punctuator?(value)
  end

  # Consumes the next token if it's the name (keyword) `value`
  def accept_name(value)
    advance if peek.name?(value)
  end

  # Consumes the next token if it's one of the names
  def accept_name_in(values)
    advance if peek.name_in?(values)
  end

  def at?(value)
    peek.punctuator?(value)
  end

  def expect(value)
    accept(value) || raise(syntax_error("expected #{value.inspect}"))
  end

  # Consumes a name, or with value, that name
  def expect_name(value = nil)
    token = peek
    return advance if value ? token.name?(value) : token.name?
    raise syntax_error("expected #{value ? value.inspect : 'a name'}")
  end

  def expect_string
    token = peek
    raise syntax_error("expected a string") unless token.type == :string
    string_node(advance)
  end

  def string_node(token)
    JSAnalyzer::Node::String.new(token.value[1...-1], token.value[0])
  end

  def syntax_error(message, token = peek)
    @tokens.syntax_error(message, token.start)
  end

  # Whether the last token consumed was a `;`. Statements consume the `;` that
  # ends them, so the clauses of a for loop check this before expecting one.
  def terminated?
    @tokens.last&.punctuator?(';')
  end

  # Whether a "use strict" directive is next, as at the start of a program or
  # function body
  def use_strict?
    token = peek
    token.type == :string && token.value[1...-1] == 'use strict'
  end

  # Statements

  # Parses statements until a `}`, the end of the source, or one of
  # stop_names (`case` and `default` in a switch), without consuming it
  def parse_statement_list(stop_names = nil)
    statements = []
    loop do
      token = peek(regex: true)
      break if token.eof? || token.punctuator?('}') || (stop_names && token.name_in?(stop_names))

      st = statement_list_item
      statements << st if st
      raise syntax_error("unexpected #{token.value.inspect}", token) if peek(regex: true).start == token.start
    end
    statements
  end

  # A statement where one may begin: here `{` starts a block rather than an
  # object, `;` is an empty statement (returns nil), and `name:` is a label
  def statement_list_item
    token = peek(regex: true)
    if token.punctuator?('{')
      advance
      statements, scope = with_scope(:block) { parse_statement_list }
      expect('}')
      JSAnalyzer::Node::Block.new(statements).tap { it.scope = scope }
    elsif token.punctuator?(';')
      advance
      nil
    elsif token.name? && (advance; at?(':'))
      advance
      JSAnalyzer::Node::LabeledStatement.new(token.value, statement_list_item)
    else
      unread(token) if token.name?
      statement(top: true)
    end
  end

  # Parses a required `{ ... }` block, in a new scope, returning its
  # statements
  def parse_block
    expect('{')
    statements, _ = with_scope(:block) { parse_statement_list }
    expect('}')
    statements
  end

  # Parses the body of an if, for, etc.: either a `{ ... }` block or a single
  # statement. Returns an array of statements.
  def parse_body
    at?('{') ? parse_block : [statement_list_item].compact
  end

  # Parses `( expression )`, as in `if (...)`
  def parse_condition
    expect('(')
    condition = statement
    expect(')')
    condition
  end

  # Whether the statement ends here, for keywords like `return` whose value
  # must start on the same line: a `;`, `}`, the end of the source, or a new
  # line (automatic semicolon insertion). Consumes a `;`.
  def statement_ends?
    token = peek(regex: true)
    return !!advance if token.punctuator?(';')
    token.newline_before || token.punctuator?('}') || token.eof?
  end

  # Runs the block with a new scope of `kind` as the current scope. Returns
  # the block's result and the scope.
  def with_scope(kind)
    scope = JSAnalyzer::Node::Scope.new(scope: @scope, kind: kind)
    @scope = scope
    [yield, scope]
  ensure
    if scope
      scope.close!
      @scope = scope.parent_scope
    end
  end

  # Arrow function parameters, which are parsed as an expression until the
  # `=>`. mark is where the scope's references, children and pending
  # references were before them, so they can be moved into the arrow
  # function's scope.
  ArrowParams = Struct.new(:args, :mark)

  # Turns the variable references in a parameter list parsed as expressions
  # (an arrow function's) into declarations in `scope`, adding each
  # reference replaced to `bound`. Returns the node to use in place of node.
  def bind_targets!(node, scope, kind, bound)
    bind = ->(n) { bind_targets!(n, scope, kind, bound) }
    case node
    when JSAnalyzer::Node::VariableReference
      bound << node
      scope.declare(kind, node.text, range: node.range)
    when JSAnalyzer::Node::BinaryOperator
      node.left = bind.(node.left) if node.operation == '='
      node
    when JSAnalyzer::Node::SpreadOperator
      node.variable = bind.(node.variable)
      node
    when JSAnalyzer::Node::Object
      node.entries.each do |entry|
        case entry
        when JSAnalyzer::Node::Object::ShorthandEntry, JSAnalyzer::Node::Object::DefaultEntry
          entry.key = bind.(entry.key)
        when JSAnalyzer::Node::Object::Entry
          entry.value = bind.(entry.value)
        when JSAnalyzer::Node::SpreadOperator
          bind.(entry)
        end
      end
      node
    when JSAnalyzer::Node::Array
      node.members.map! { it && bind.(it) }
      node
    else
      node
    end
  end

  # Marks the variable references an assignment writes to: a reference, or
  # those in a destructuring pattern like `[a, { b }] = c`
  def mark_written(node, read: false)
    case node
    when JSAnalyzer::Node::VariableReference
      node.write = true
      node.read = read
    when JSAnalyzer::Node::BinaryOperator # a default, as in [a = 1] = c
      mark_written(node.left) if node.operation == '='
    when JSAnalyzer::Node::SpreadOperator
      mark_written(node.variable)
    when JSAnalyzer::Node::Group # (a) = 1
      node.expressions.each { mark_written(it, read: read) }
    when JSAnalyzer::Node::Array
      node.members.each { mark_written(it) if it }
    when JSAnalyzer::Node::Object
      node.entries.each do |entry|
        case entry
        when JSAnalyzer::Node::Object::ShorthandEntry, JSAnalyzer::Node::Object::DefaultEntry
          mark_written(entry.key)
        when JSAnalyzer::Node::Object::Entry
          mark_written(entry.value)
        when JSAnalyzer::Node::SpreadOperator
          mark_written(entry)
        end
      end
    end
  end

  # Object literals

  # After the `{`
  def parse_object
    obj = JSAnalyzer::Node::Object.new

    loop do
      token = advance
      if token.punctuator?('}')
        return obj
      elsif token.punctuator?('...')
        obj.spread(expression)
      elsif token.punctuator?('[')
        key = statement
        expect(']')
        if accept(':')
          obj.add(key, expression)
        else
          expect('(')
          obj.shorthand(parse_function(key, false, false, :class))
        end
      elsif token.type == :string
        key = string_node(token)
        if accept('(')
          obj.shorthand(parse_function(key, false, false, :class, computed: false))
        else
          expect(':')
          obj.add(key, expression)
        end
      elsif token.type == :number
        if accept('(')
          obj.shorthand(parse_function(token.value, false, false, :class))
        else
          expect(':')
          obj.add(token.value, expression)
        end
      elsif token.punctuator?('*')
        key, computed = parse_property_key
        expect('(')
        obj.shorthand(parse_function(key, false, true, :class, computed: computed))
      elsif token.name_in?(ACCESSORS) && property_key_next?
        # Getter or setter: `get name() {}`, `set [expr](v) {}`
        key, computed = parse_property_key
        expect('(')
        accessor = token.value == 'get' ? JSAnalyzer::Node::Class::Getter : JSAnalyzer::Node::Class::Setter
        obj.shorthand(accessor.new(parse_function(key, false, false, :class, computed: computed)))
      elsif token.name?('async') && (property_key_next? || at?('*')) && !peek.newline_before
        generator = !!accept('*')
        key, computed = parse_property_key
        expect('(')
        obj.shorthand(parse_function(key, true, generator, :class, computed: computed))
      elsif token.name?
        key = token.value
        if at?('}') || accept(',')
          obj.shorthand(@scope.var(key, range: token.range))
          next
        elsif accept('=')
          # `{ key = value }`, only valid as a destructuring pattern
          obj.add_default(@scope.var(key, range: token.range), expression)
        elsif accept('(')
          obj.shorthand(parse_function(key, false, false, :class))
        else
          expect(':')
          obj.add(key, expression)
        end
      else
        raise syntax_error("unexpected #{token.value.inspect}", token)
      end

      expect('}') && (return obj) unless accept(',')
    end
  end

  # Whether a property key (as in `get key() {}`) is next
  def property_key_next?
    token = peek
    token.name? || token.type == :string || token.type == :number || token.punctuator?('[')
  end

  # A method or accessor's key, as [key, computed]: a name or number as a
  # String, a quoted key as a String node, or a computed key's expression
  def parse_property_key
    token = advance
    case token.type
    when :name, :number, :private_name
      [token.value, false]
    when :string
      [string_node(token), false]
    else
      raise syntax_error("expected a property name", token) unless token.punctuator?('[')
      key = statement
      expect(']')
      [key, true]
    end
  end

  # Functions

  # as_expression: a function expression, whose name is only visible inside
  # it. computed: the name is a computed key, `[expr]() {}`
  def parse_function(name, async, generator, type, as_expression: false, name_range: nil, computed: nil)
    # A function's name is a variable; a method's is a property name
    declare = (as_expression ? :inner : :outer) if type == :function
    fn = JSAnalyzer::Node::Method.new(name: name, async: async, scope: @scope, generator: generator, type: type,
                                      declare: declare, name_range: name_range, computed: computed)

    # Parse parameters, in the function's scope: names, rest (...args),
    # defaults (a = 1) and destructuring patterns ({ a, b }, [a, b])
    @scope = fn.scope
    begin
      loop do
        break if accept(')')
        rest = accept('...')
        param = parse_binding_target('param')
        if accept('=')
          param = JSAnalyzer::Node::BinaryOperator.new(left: param, operation: '=', right: expression)
        end
        fn.args << (rest ? JSAnalyzer::Node::SpreadOperator.new(param) : param)
        next if accept(',')
        expect(')')
        break
      end
    ensure
      @scope = fn.scope.parent_scope
    end

    expect('{')
    parse_function_body(fn, true)
    fn
  end

  def parse_function_body(fn, brackets = true)
    unless fn.simple_parameters?
      # With defaults, patterns or rest parameters, the parameters are in a
      # scope of their own and the body's declarations in another, so a
      # default can't see a `var` in the body
      fn.body_scope = JSAnalyzer::Node::Scope.new(scope: fn.scope, kind: :function_body)
    end

    if brackets && use_strict?
      fn.scope.strict = true
      fn.body_scope.strict = true
    end

    begin
      @scope = fn.body_scope
      if brackets
        fn.body.concat(parse_statement_list)
      else
        # Arrow function with an expression body
        fn.expression_body = true
        fn.body << expression
      end
    ensure
      fn.body_scope.close! unless fn.body_scope.equal?(fn.scope)
      fn.scope.close!
      @scope = fn.scope.parent_scope
    end
    expect('}') if brackets
  end

  # After the `(` of a call or parenthesized expression
  def parse_args
    args = []
    loop do
      break if accept(')')
      args << expression
      next if accept(',')
      expect(')')
      break
    end
    args
  end

  # After the `[`
  def parse_array
    array = JSAnalyzer::Node::Array.new
    loop do
      break if accept(']')
      if accept(',')
        array.members << nil # a hole, as in [1, , 2]
        next
      end

      array.members << expression
      next if accept(',')
      expect(']')
      break
    end
    array
  end

  # Classes

  # After `class`
  def parse_class(expression: false)
    token = peek
    name = (token.name? && !token.name?('extends')) ? [advance.value, token.range] : nil

    # extends takes any member, call or new expression (B.C, mixin(A, B), ...),
    # parsed here so its references are in the enclosing scope
    extends = statement(min_prec: PREFIX_PRECEDENCE) if accept_name('extends')
    expect('{')
    klass = JSAnalyzer::Node::Class.new(scope: @scope, name: name, extends: extends, expression: expression)

    begin
      @scope = klass.scope
      until accept('}')
        part = parse_class_part
        klass.body << part if part
      end
    ensure
      klass.scope.close!
      @scope = klass.scope.parent_scope
    end
    klass
  end

  CLASS_MODIFIERS = %w(static get set async).freeze
  CLASS_MEMBER_ENDS = ['(', '=', ';', '}'].freeze

  def parse_class_part
    token = advance
    return if token.punctuator?(';')

    # static, get, set and async are member names when nothing follows them,
    # e.g. `get(key) {}` or `static = 1`
    if token.name_in?(CLASS_MODIFIERS) && (peek.punctuator_in?(CLASS_MEMBER_ENDS) || peek.newline_before)
      return parse_class_member(token.value, false, false)
    end

    member = if token.name?('static')
      return parse_class_part.tap { |part| part.static = true }
    elsif token.name?('get')
      JSAnalyzer::Node::Class::Getter.new(parse_class_part)
    elsif token.name?('set')
      JSAnalyzer::Node::Class::Setter.new(parse_class_part)
    elsif token.punctuator?('{')
      block = JSAnalyzer::Node::Class::InitializationBlock.new(scope: @scope)
      begin
        @scope = block
        parse_statement_list.each { block << it }
      ensure
        block.close!
        @scope = block.parent_scope
      end
      expect('}')
      block
    else
      async = token.name?('async')
      token = advance if async
      generator = token.punctuator?('*')
      token = advance if generator
      unread(token)
      key, = parse_property_key
      return parse_class_member(key, async, generator)
    end
    JSAnalyzer::Node::Class::Field.new(member)
  end

  # A method or field named `name`, after its name
  def parse_class_member(name, async, generator)
    if accept('(')
      JSAnalyzer::Node::Class::Field.new(parse_function(name, async, generator, :class))
    elsif accept('=')
      JSAnalyzer::Node::Class::Field.new(name, statement)
    else
      # A field without an initializer, ended by `;` or a new line
      accept(';')
      JSAnalyzer::Node::Class::Field.new(name)
    end
  end

  # Destructuring patterns

  # The target of a declaration or parameter: a name, or an object or array
  # destructuring pattern. Names are declared as `kind` ("let", "param"...).
  # Returns the VariableDeclaration or the pattern.
  def parse_binding_target(kind)
    if accept('{')
      parse_object_pattern(kind)
    elsif accept('[')
      parse_array_pattern(kind)
    else
      token = expect_name
      @scope.declare(kind, token.value, range: token.range)
    end
  end

  # `{ a, b: c, d = 1, e: { f }, ...rest }`, after the `{`
  def parse_object_pattern(kind)
    pattern = JSAnalyzer::Node::DestructureObject.new
    loop do
      break if accept('}')
      if accept('...')
        pattern.add(parse_binding_target(kind), rest: true)
      elsif (key = parse_pattern_key)
        # A string, number or computed key: `'a-b': x`, `0: y`, `[k]: z`.
        # Only a plain name can be used without `: target`.
        expect(':')
        value = parse_binding_target(kind)
        default = accept('=') ? expression : nil
        pattern.add(key[0], value, default: default, computed: key[1])
      else
        token = expect_name
        if accept(':')
          # `key: target`, where key is only a property name
          key = token.value
          value = parse_binding_target(kind)
        else
          key = @scope.declare(kind, token.value, range: token.range)
          value = nil
        end
        default = accept('=') ? expression : nil
        pattern.add(key, value, default: default)
      end
      next if accept(',')
      expect('}')
      break
    end
    pattern
  end

  # An object pattern key other than a plain name, as [key, computed]: a
  # String node, a number (as written), or a computed key's expression.
  # Returns nil if the next key is a name.
  def parse_pattern_key
    token = peek
    if token.type == :string
      [string_node(advance), false]
    elsif token.type == :number
      [advance.value, false]
    elsif accept('[')
      key = expression
      expect(']')
      [key, true]
    end
  end

  # `[a, , b = 1, [c], ...rest]`, after the `[`
  def parse_array_pattern(kind)
    pattern = JSAnalyzer::Node::DestructureArray.new
    loop do
      break if accept(']')
      if accept(',')
        pattern.hole
        next
      end

      rest = accept('...')
      target = parse_binding_target(kind)
      if rest
        pattern.add(target, rest: true)
      else
        pattern.add(target, (expression if accept('=')))
      end
      next if accept(',')
      expect(']')
      break
    end
    pattern
  end

  # `with { type: "json" }` (or the older `assert { ... }`) after the module
  # specifier of an import or export. Returns [keyword, object] or nil.
  def parse_import_attributes
    return unless (keyword = accept_name_in(IMPORT_ATTRIBUTE_KEYWORDS))
    expect('{')
    [keyword.value, parse_object]
  end

  # After the opening backtick
  def parse_template
    node = JSAnalyzer::Node::InterpolatedString.new
    loop do
      text, kind = @tokens.template_chunk
      node << text unless text.empty?
      return node if kind == :end

      node << statement
      expect('}')
    end
  end

  # Expressions

  # Parses the right side of the binary operator `op` and pushes the
  # BinaryOperator onto the stack. Returns false if `op` binds looser than
  # min_prec and so belongs to the caller.
  def binary_operator(stack, op, min_prec, no_in)
    prec = PRECEDENCE.fetch(op)
    return false if prec < min_prec || (no_in && op == 'in')

    right = statement(min_prec: RIGHT_ASSOCIATIVE.include?(op) ? prec : prec + 1)
    left = stack.pop
    # `x = 1` only writes x; `x += 1` and `x ||= y` read it too
    mark_written(left, read: op != '=') if ASSIGNMENT_OPERATORS.include?(op)
    stack << JSAnalyzer::Node::BinaryOperator.new(left: left, operation: op, right: right)
    true
  end

  # A single expression that stops at a `,`, for argument lists, array items,
  # initializers, etc.
  def expression
    statement(min_prec: PRECEDENCE['='])
  end

  # no_in:    stop before an `in` operator (the first clause of a for loop)
  # min_prec: stop before any operator that binds looser than this (see
  #           PRECEDENCE), or a `;`; used to parse operands
  # top:      this is the start of a statement, so `function` and `class` are
  #           declarations rather than expressions
  def statement(no_in: false, min_prec: 0, top: false)
    stack = []

    loop do
      # A regex can start where a value is expected
      token = advance(regex: stack.empty?)

      case token.type
      when :eof
        unread(token)
        return stack.pop
      when :punctuator
        result = handle_punctuator(token, stack, no_in, min_prec)
      when :name
        result = handle_name(token, stack, no_in, min_prec, top)
      else
        # A value after a complete expression starts the next statement
        unless stack.empty?
          if token.type == :template
            stack << JSAnalyzer::Node::TaggedTemplate.new(stack.pop, parse_template)
            next
          end
          unread(token)
          return stack.pop
        end

        stack << case token.type
        when :number then JSAnalyzer::Node::Number.new(token.value)
        when :string then string_node(token)
        when :template then parse_template
        when :private_name then JSAnalyzer::Node::PrivateName.new(token.value) # #x in obj
        when :regex
          flags_at = token.value.rindex('/')
          JSAnalyzer::Node::Regex.new(token.value[1...flags_at], token.value[(flags_at + 1)..])
        end
        next
      end

      return result.value if result.is_a?(Return)
    end
  end

  # What a token handler returns to end the expression
  Return = Struct.new(:value)

  def end_expression(token, stack)
    unread(token)
    Return.new(stack.pop)
  end

  def handle_punctuator(token, stack, no_in, min_prec)
    value = token.value
    case value
    when ';'
      unread(token) if min_prec > 0
      Return.new(stack.pop)
    when '{'
      return end_expression(token, stack) unless stack.empty?
      stack << parse_object
    when '('
      last = stack.last
      # An arrow function can't be called without parens around it
      return end_expression(token, stack) if last.is_a?(JSAnalyzer::Node::Method) && last.type == :arrow

      if last.nil?
        # Arrow function parameters or a parenthesized expression
        mark = [@scope.references.size, @scope.children.size, @scope.pending.size]
        args = parse_args
        stack << (at?('=>') ? ArrowParams.new(args, mark) : JSAnalyzer::Node::Group.new(args))
      elsif CALLABLE.any? { last.is_a?(it) }
        stack << JSAnalyzer::Node::FunctionCall.new(stack.pop, parse_args)
      else
        end_expression(token, stack)
      end
    when '?.'
      stack << if accept('(')
        JSAnalyzer::Node::FunctionCall.new(stack.pop, parse_args, optional_chaining: true)
      elsif accept('[')
        key = statement
        expect(']')
        JSAnalyzer::Node::BracketAccessor.new(stack.pop, key, optional_chaining: true)
      else
        JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: member_name, optional_chaining: true)
      end
    when '?'
      return end_expression(token, stack) if PRECEDENCE['?'] < min_prec

      a = statement
      expect(':')
      b = statement(min_prec: PRECEDENCE['='])
      stack << JSAnalyzer::Node::Ternary.new(stack.pop, a, b)
    when '.'
      raise syntax_error("unexpected \".\"", token) if stack.empty?
      stack << JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: member_name)
    when '['
      stack << if stack.empty?
        parse_array
      else
        JSAnalyzer::Node::BracketAccessor.new(stack.pop, statement).tap { expect(']') }
      end
    when '...'
      Return.new(JSAnalyzer::Node::SpreadOperator.new(expression))
    when '!', '~'
      prefix_operator(token, stack)
    when '++', '--'
      # `a \n ++b` is `a; ++b`
      return end_expression(token, stack) if token.newline_before && !stack.empty?

      prefix = stack.empty?
      operand = prefix ? statement(min_prec: PREFIX_PRECEDENCE) : stack.pop
      mark_written(operand, read: true) # x++ and ++x read and write x
      stack << if prefix
        JSAnalyzer::Node::PrefixOperator.new(value, operand)
      else
        JSAnalyzer::Node::UnaryOperator.new(operand, value)
      end
    when '+', '-'
      if stack.empty?
        stack << JSAnalyzer::Node::PrefixOperator.new(value, statement(min_prec: PREFIX_PRECEDENCE))
      elsif !binary_operator(stack, value, min_prec, no_in)
        end_expression(token, stack)
      end
    when '=>'
      arrow_function(stack)
    when ','
      # Comma operator, or the end of an item in a list
      end_expression(token, stack) if stack.empty? || !binary_operator(stack, ',', min_prec, no_in)
    else
      if PRECEDENCE.key?(value) && !stack.empty?
        # Binary operator, including assignment
        end_expression(token, stack) unless binary_operator(stack, value, min_prec, no_in)
      elsif PRECEDENCE.key?(value) && value != '/'
        raise syntax_error("unexpected #{value.inspect}", token)
      else
        # `)`, `]`, `}`, `:` and the like end the expression
        end_expression(token, stack)
      end
    end
  end

  # A property name after `.` or `?.`, which may be a keyword or #private
  def member_name
    token = advance
    raise syntax_error("expected a property name", token) unless token.name? || token.type == :private_name
    token.value
  end

  def prefix_operator(token, stack)
    # A prefix operator can't follow a value, so it starts the next statement
    # (`a \n delete b`)
    return end_expression(token, stack) unless stack.empty?
    stack << JSAnalyzer::Node::PrefixOperator.new(token.value, statement(min_prec: PREFIX_PRECEDENCE))
  end

  def arrow_function(stack)
    params = stack.pop
    args, mark = case params
    when ArrowParams
      [params.args, params.mark]
    when JSAnalyzer::Node::VariableReference # x => ...
      [[params], [@scope.references.index { it.equal?(params) } || @scope.references.size,
                  @scope.children.size,
                  @scope.pending.index { it.equal?(params) } || @scope.pending.size]]
    else
      [Array(params), [@scope.references.size, @scope.children.size, @scope.pending.size]]
    end

    # The parameters were parsed in this scope; move what they declared and
    # referenced into the arrow function's. That includes references passed
    # up by scopes inside them that have already closed, such as a function
    # in a default value.
    references = @scope.references.slice!(mark[0]..) || []
    children = @scope.children.slice!(mark[1]..) || []
    pending = @scope.pending.slice!(mark[2]..) || []
    fn = JSAnalyzer::Node::Method.new(scope: @scope, type: :arrow)
    children.each { it.parent_scope = fn.scope; fn.scope.children << it }
    bound = []
    fn.args = args.map { bind_targets!(it, fn.scope, 'param', bound) }
    references.each do |reference|
      next if bound.any? { it.equal?(reference) }
      reference.scope = fn.scope
      fn.scope.references << reference
    end
    pending.each do |reference|
      fn.scope.pending << reference unless bound.any? { it.equal?(reference) }
    end

    parse_function_body(fn, !!accept('{'))
    stack << fn
  end

  def handle_name(token, stack, no_in, min_prec, top)
    value = token.value
    # A statement keyword after a complete expression starts the next
    # statement
    return end_expression(token, stack) if !stack.empty? && STATEMENT_KEYWORDS.include?(value)

    case value
    when 'in', 'instanceof'
      return end_expression(token, stack) if stack.empty? || !binary_operator(stack, value, min_prec, no_in)
    when 'export'
      Return.new(JSAnalyzer::Node::ExportStatement.parse(self))
    when 'import'
      if at?('(') || at?('.')
        # import(...) or import.meta
        stack << JSAnalyzer::Node::Keyword.new(value)
      else
        Return.new(JSAnalyzer::Node::ImportStatement.parse(self))
      end
    when 'async'
      return end_expression(token, stack) unless stack.empty?

      if async_function_next?
        # async applies only to the function or arrow function after it
        fn = statement(min_prec: PREFIX_PRECEDENCE)
        if fn.is_a?(JSAnalyzer::Node::Method)
          fn.async = true
          return Return.new(fn) if top && fn.type == :function
          stack << fn
        else
          # A call to something named async, e.g. async(x)
          args = fn.is_a?(JSAnalyzer::Node::Group) ? fn.expressions : [fn]
          stack << JSAnalyzer::Node::FunctionCall.new(@scope.var('async', range: token.range), args)
        end
      else
        stack << @scope.var(value, range: token.range)
      end
    when 'function'
      generator = !!accept('*')
      fn_name = peek.name? ? advance : nil
      expect('(')
      fn = parse_function(fn_name&.value, false, generator, :function, as_expression: !top, name_range: fn_name&.range)
      @scope.declare_block_function(fn.binding) if top && fn.binding
      return Return.new(fn) if top
      stack << fn
    when 'class'
      klass = parse_class(expression: !top)
      return Return.new(klass) if top
      stack << klass
    when 'new'
      return end_expression(token, stack) unless stack.empty?
      stack << parse_new
    when 'delete', 'typeof', 'void', 'await'
      prefix_operator(token, stack)
    when 'var', 'let', 'const'
      node = JSAnalyzer::Node::VariableStatement.new(value)
      loop do
        target = parse_binding_target(node.kind)
        init = accept('=') ? expression : nil
        node.add(target, init)
        break unless accept(',')
      end
      accept(';')
      Return.new(node)
    when 'for'
      Return.new(parse_for)
    when 'return'
      Return.new(JSAnalyzer::Node::ReturnStatement.new(statement_ends? ? nil : statement))
    when 'yield'
      delegate = !!accept('*') # yield* iterable
      Return.new(JSAnalyzer::Node::Yield.new(statement_ends? ? nil : statement, delegate: delegate))
    when 'with'
      Return.new(JSAnalyzer::Node::With.new(parse_condition, parse_body))
    when 'debugger'
      accept(';')
      Return.new(JSAnalyzer::Node::DebuggerStatement.new)
    when 'if'
      node = JSAnalyzer::Node::If.new(parse_condition, parse_body)
      while accept_name('else')
        if accept_name('if')
          node.else_if(parse_condition, parse_body)
        else
          node.else(parse_body)
          break
        end
      end
      Return.new(node)
    when 'while'
      Return.new(JSAnalyzer::Node::While.new(parse_condition, parse_body))
    when 'do'
      body = parse_body
      expect_name('while')
      condition = parse_condition
      accept(';')
      Return.new(JSAnalyzer::Node::DoWhile.new(body, condition))
    when 'throw'
      Return.new(JSAnalyzer::Node::ThrowStatement.new(statement))
    when 'try'
      Return.new(parse_try)
    when 'switch'
      Return.new(parse_switch)
    when 'break', 'continue'
      label = peek
      label = (label.name? && !label.newline_before) ? advance.value : nil
      accept(';')
      Return.new(JSAnalyzer::Node::JumpStatement.new(value, label))
    when 'true', 'false'
      return end_expression(token, stack) unless stack.empty?
      stack << JSAnalyzer::Node::Boolean.new(value == 'true')
    when 'this', 'super', 'null'
      return end_expression(token, stack) unless stack.empty?
      stack << JSAnalyzer::Node::Keyword.new(value)
    else
      return end_expression(token, stack) unless stack.empty?
      stack << @scope.var(value, range: token.range)
    end
  end

  # After `async`: whether a function (`async function`, `async (x) =>`,
  # `async x =>`) follows rather than `async` being a name
  def async_function_next?
    token = peek
    return false if token.newline_before
    return true if token.name?('function') || token.punctuator?('(')
    return false unless token.name?

    advance
    arrow = at?('=>')
    unread(token)
    arrow
  end

  # After `new`: `new.target`, or `new Callee(args)` where Callee is a member
  # expression and the argument list is optional
  def parse_new
    if accept('.')
      expect_name('target')
      return JSAnalyzer::Node::MetaProperty.new('new', 'target')
    end

    callee = if accept('(')
      JSAnalyzer::Node::Group.new(parse_args)
    elsif (token = accept_name_in(THIS_OR_SUPER))
      JSAnalyzer::Node::Keyword.new(token.value)
    elsif accept_name('new')
      parse_new
    else
      token = expect_name
      @scope.var(token.value, range: token.range)
    end

    loop do
      if accept('.')
        callee = JSAnalyzer::Node::DotAccessor.new(object: callee, key: member_name)
      elsif accept('[')
        callee = JSAnalyzer::Node::BracketAccessor.new(callee, statement).tap { expect(']') }
      else
        break
      end
    end

    JSAnalyzer::Node::Instantiation.new(callee, accept('(') ? parse_args : [])
  end

  # After `for`
  def parse_for
    # The head is in its own scope, for `for (let i ...)`
    node, _ = with_scope(:block) do
      is_await = !!accept_name('await') # for await (x of y)
      expect('(')
      initialization = statement(no_in: true)

      if (kind = accept_name_in(FOR_IN_OF))
        mark_written(initialization) # for (x of xs) assigns x
        right = statement
        expect(')')
        next JSAnalyzer::Node::ForIn.new(initialization, kind.value, right, parse_body, await: is_await)
      end

      expect(';') unless terminated?
      condition = statement
      expect(';') unless terminated?
      afterthought = statement
      expect(')')
      JSAnalyzer::Node::ForLoop.new(initialization, condition, afterthought, parse_body)
    end
    node
  end

  # After `try`
  def parse_try
    node = JSAnalyzer::Node::Try.new(parse_block)
    if accept_name('catch')
      with_scope(:catch) do
        if accept('(')
          node.param = parse_binding_target('catch')
          expect(')')
        end
        node.handler = parse_block
      end
    end
    node.finalizer = parse_block if accept_name('finally')
    node
  end

  # After `switch`
  def parse_switch
    node = JSAnalyzer::Node::Switch.new(parse_condition)
    expect('{')
    with_scope(:block) do
      while (kind = accept_name_in(SWITCH_CASES))
        test = kind.value == 'case' ? statement : nil
        expect(':')
        node.cases << [test, parse_statement_list(SWITCH_CASES)]
      end
    end
    expect('}')
    node
  end

end
