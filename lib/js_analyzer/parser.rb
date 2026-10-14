class JSAnalyzer::Parser
  
  include StreamParser
  
  attr_accessor :scope # TODO: remove
  
  # StreamParser util updates
  def scan_until_eol
    scan_until(/[^\n\f]+(\n+|\f|\z)/)
    match
  end
  
  # Positions (@index, and the ranges on declarations and references) are
  # byte offsets into the source, as in StreamParser, so matching never has
  # to count characters from the start of the source.

  def peek(n=1)
    if n.is_a?(Regexp)
      skip_comments if skips_comments?(n)
      @source.byteindex(anchored(n), @index) && $~
    else
      super
    end
  end

  # Matches r at the current position and moves past it. Unlike
  # StreamParser's version this only tries the current position (instead of
  # searching the rest of the source), and skips comments first when r starts
  # with optional whitespace.
  def gobble(r)
    r = LITERAL[r] if r.is_a?(::String)
    skip_comments if skips_comments?(r)
    return unless @source.byteindex(anchored(r), @index)

    m = $~
    @match = m.to_s
    @old_index = @index
    @index = m.byteend(0)
    m
  end

  # The `|(?!)` alternative never matches; it stops Onigmo from first
  # searching the rest of the source for a literal every match needs (here
  # the `/`), which made each attempt cost the distance to the next one
  COMMENT = /\G(?:\p{Space}*(?:\/\/[^\n]*|\/\*.*?\*\/)|(?!))/m

  # Comments can appear anywhere whitespace can, so patterns that allow
  # leading whitespace skip comments too
  SKIPS_COMMENTS = {}.compare_by_identity

  def skips_comments?(r)
    SKIPS_COMMENTS.fetch(r) { SKIPS_COMMENTS[r] = r.source.start_with?('\p{Space}') }
  end

  # The first byte of whitespace or a comment
  COMMENT_START_BYTES = [9, 10, 11, 12, 13, 32, '/'.ord].freeze

  def skip_comments
    # Most of the time the next character is neither, so don't run the regex
    while COMMENT_START_BYTES.include?(@source.getbyte(@index)) && @source.byteindex(COMMENT, @index)
      @index = $~.byteend(0)
    end
  end

  # Moves back `by` characters. StreamParser's rewind copies and counts the
  # source before the current position, which costs the length of the
  # source in non-ASCII text; this steps back over UTF-8 continuation bytes
  # instead.
  # TODO: move this into StreamParser
  def rewind(by = 1)
    return super unless @source.encoding == Encoding::UTF_8

    by.times do
      @index -= 1
      @index -= 1 while @index > 0 && (@source.getbyte(@index) & 0b1100_0000) == 0b1000_0000
    end
  end

  # Patterns are regex literals compiled once (with /o where they
  # interpolate), so the anchored versions are cached by the pattern itself.
  # `|(?!)` never matches; see COMMENT.
  ANCHORED = {}.compare_by_identity

  def anchored(r)
    ANCHORED[r] ||= Regexp.new("\\G(?:#{r.source}|(?!))", r.options)
  end

  # Regexes matching a literal string, as in gobble("${")
  LITERAL = Hash.new { |cache, string| cache[string] = Regexp.new(Regexp.escape(string)) }
  
  # Reads a string literal's contents up to the closing quote_char, keeping
  # escape sequences as written. (StreamParser's version removes the
  # backslashes, so `"a\"b"` would print back as `"a"b"`.)
  QUOTED = Hash.new do |cache, quote_char|
    q = Regexp.escape(quote_char)
    cache[quote_char] = /((?:[^#{q}\\\r\n]|\\.)*)#{q}/m
  end

  def quoted_value(quote_char = '"', _escape_chars = nil)
    m = gobble(QUOTED[quote_char])
    raise syntax_error("unterminated string") unless m
    m[1]
  end

  # A JSAnalyzer::SyntaxError for the current position, with the line and
  # column and the source around it
  def syntax_error(message)
    before = @source.byteslice(0, [@index, @source.bytesize].min)
    after = @source.byteslice(before.bytesize..)
    line = before.count("\n") + 1
    line_before = before[((before.rindex("\n") || -1) + 1)..]
    line_after = after[/\A[^\n]*/]
    column = line_before.size + 1

    # Show at most 80 characters either side, so minified files stay readable
    shown_before = line_before[-80..] || line_before
    JSAnalyzer::SyntaxError.new(
      "#{message} at #{line}:#{column}\n  #{shown_before}#{line_after[0, 80]}\n  #{' ' * shown_before.size}^"
    )
  end

  def gobble!(r)
    x = gobble(r)
    raise syntax_error("expected #{r.is_a?(Regexp) ? r.source : r.inspect}") unless x
    x
  end
  
  # DSL helpers
  # def p(pattern, precedence: 0)
  #   @patterns.rindex { |ps| ps[0] }
  #   @patterns << [precedence, pattern]
    
  # end
  
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

  BINARY_OPERATORS = PRECEDENCE.keys.grep_v(/\A(\?|[a-z]+)\z/)
  UNARY_OPERATORS = %w(++ --)
  OPERATORS = (UNARY_OPERATORS+BINARY_OPERATORS).sort_by(&:length).reverse
  OPERATOR_REGEX = Regexp.union(OPERATORS)

  WHITESPACE = /\p{Space}+/
  IDENTIFIER = /[\p{Alpha}_\$][\p{Alpha}_\$\d]*/
  NUMBER = /0[xX][\da-fA-F_]+n?|0[oO][0-7_]+n?|0[bB][01_]+n?|(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?n?/
  NUMBER_TOKEN = /\A(?:#{NUMBER})\z/o
  
  def parse
    @scope = JSAnalyzer::Node::Program.new
    gobble(/#![^\n]*/) # hashbang, e.g. #!/usr/bin/env node

    parse_statement_list.each { @scope << it }
    gobble(WHITESPACE)
    raise syntax_error("unexpected #{peek(1).inspect}") unless eos?

    @scope.source = @source
    @scope.close!
    @scope
  end

  STATEMENT_LIST_END = /\p{Space}*(\}|\z)/

  # Parses statements until `until` matches (by default a `}` or the end of
  # the source), without consuming it
  def parse_statement_list(until_pattern = STATEMENT_LIST_END)
    statements = []
    until peek(until_pattern)
      start = @index
      st = statement_list_item
      statements << st if st
      raise syntax_error("unexpected #{peek(1).inspect}") if @index == start
    end
    statements
  end

  # A statement where one may begin: here `{` starts a block rather than an
  # object, `;` is an empty statement (returns nil), and `name:` is a label
  def statement_list_item
    if gobble(/\p{Space}*\{/)
      statements, scope = with_scope(:block) { parse_statement_list }
      gobble!(/\p{Space}*\}/)
      JSAnalyzer::Node::Block.new(statements).tap { it.scope = scope }
    elsif gobble(/\p{Space}*;/)
      nil
    elsif label = gobble(/\p{Space}*(#{IDENTIFIER})\p{Space}*:(?!:)/o)&.[](1)
      JSAnalyzer::Node::LabeledStatement.new(label, statement_list_item)
    else
      statement(top: true)
    end
  end

  # Parses a required `{ ... }` block, in a new scope, returning its
  # statements
  def parse_block
    gobble!(/\p{Space}*\{/)
    statements, _ = with_scope(:block) { parse_statement_list }
    gobble!(/\p{Space}*\}/)
    statements
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

  # The source range of a match's group
  def group_range(match_data, group = 1)
    match_data.bytebegin(group)...match_data.byteend(group)
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
  
  def parse_object
    obj = JSAnalyzer::Node::Object.new
    
    while true
      gobble(WHITESPACE)
      gob = gobble(/(\}|\[|\"|\'|#{NUMBER}|#{IDENTIFIER}|\.\.\.|\/|\*)/o)
      key_range = group_range(gob, 0)

      case gob[0]
      when "}"
        return obj
      when "["
        key = statement
        gobble!(/\p{Space}*\]\p{Space}*/)
        case gobble(/\p{Space}*(\:|\()\p{Space}*/)&.[](1)
        when ':'
          obj.add(key, expression)
          gobble(/\p{Space}*,/)
        when '('
          obj.shorthand(parse_function(key, false, false, :class))
          gobble(/\p{Space}*,/)
        else
          parse_scope([JSAnalyzer::Node::Array.new([key])])
        end

      when '"', "'"
        quote = match
        key = JSAnalyzer::Node::String.new(quoted_value(quote), quote)
        return parse_scope([key]) unless gobble(/\p{Space}*:\p{Space}*/)
        obj.add(key, expression)
        gobble(/\p{Space}*,/)
      when '...'
        obj.spread(expression)
        gobble(/\p{Space}*,/)
      when "/"
        case peek(1)
        when "/"
          scan_until_eol
        when '*'
          scan_until(/\*\//)
        end
      when "*"
        key = gobble!(/\p{Space}*(\[|#{IDENTIFIER})/o)&.[](1)
        
        if key == '['
          key = statement
          gobble!(/\p{Space}*\]\p{Space}*/)
        end
        
        gobble!(/\p{Space}*\(/)
        obj.shorthand(parse_function(key, false, true, :class))
        gobble(/\p{Space}*,/)
      when 'async'
        # `async` as an ordinary key: { async: true }, { async() {} }, { async }
        unless peek(/\p{Space}*(\*|\[|#{IDENTIFIER})/o)
          if gobble(/\p{Space}*:/)
            obj.add("async", expression)
          elsif gobble(/\p{Space}*\(/)
            obj.shorthand(parse_function("async", false, false, :class))
          else
            obj.shorthand(@scope.var("async", range: key_range))
          end
          gobble(/\p{Space}*,/)
          next
        end

        key = gobble!(/\p{Space}*(\*|\[|#{IDENTIFIER})/o)&.[](1)
        if key == '*'
          generator = true
          key = gobble!(/\p{Space}*(\[|#{IDENTIFIER})/o)&.[](1)
        end
        
        if key == '['
          key = statement
          gobble!(/\p{Space}*\]\p{Space}*/)
        end

        gobble!(/\p{Space}*\(/)
        obj.shorthand(parse_function(key, true, generator, :class))
        gobble(/\p{Space}*,/)
      when NUMBER_TOKEN
        key = match
        return parse_scope([key]) unless gobble(/\p{Space}*:\p{Space}*/)
        obj.add(key, expression)
        gobble(/\p{Space}*,/)
      when IDENTIFIER
        key = match

        # Getter or setter: `get name() {}`, `set [expr](v) {}`
        if (key == 'get' || key == 'set') && (name = gobble(/\p{Space}+(#{IDENTIFIER}|#{NUMBER})|\p{Space}*(\[)/o))
          name = name[1] || name[2]
          if name == '['
            name = statement
            gobble!(/\p{Space}*\]/)
          end
          gobble!(/\p{Space}*\(/)
          accessor = key == 'get' ? JSAnalyzer::Node::Class::Getter : JSAnalyzer::Node::Class::Setter
          obj.shorthand(accessor.new(parse_function(name, false, false, :class)))
          gobble(/\p{Space}*,/)
          next
        end

        if peek(/\p{Space}*\}/)
          # Shorthand property as the last entry
          obj.shorthand(@scope.var(key, range: key_range))
          next
        end

        if gobble(/\p{Space}*=(?![=>])/)
          # `{ key = value }`, only valid as a destructuring pattern
          obj.add_default(@scope.var(key, range: key_range), expression)
          gobble(/\p{Space}*,/)
          next
        end

        return parse_scope([key]) unless gob = gobble(/\p{Space}*([:,\(])\p{Space}*/)

        case gob[1]
        when ","
          obj.shorthand(@scope.var(key, range: key_range))
        when "("
          obj.shorthand(parse_function(key, false, false, :class))
          gobble(/\p{Space}*,/)
        else
          obj.add(key, expression)
          gobble(/\p{Space}*,/)
        end

      else
        # TODO: unhandled object member
      end
    end
  end
  
  # as_expression: a function expression, which (unlike a declaration) is part
  # of the surrounding expression and so doesn't consume a following `;`
  def parse_function(name, async, generator, type, as_expression: false, name_range: nil)
    # A function's name is a variable; a method's is a property name
    declare = (as_expression ? :inner : :outer) if type == :function
    fn = JSAnalyzer::Node::Method.new(name: name, async: async, scope: @scope, generator: generator, type: type,
                                      declare: declare, name_range: name_range)

    # Parse parameters, in the function's scope: names, rest (...args),
    # defaults (a = 1) and destructuring patterns ({ a, b }, [a, b])
    @scope = fn.scope
    begin
      until gobble(/\p{Space}*\)/)
        start = @index
        rest = gobble(/\p{Space}*\.\.\./)
        param = parse_binding_target('param')
        if gobble(/\p{Space}*=(?![=>])/)
          param = JSAnalyzer::Node::BinaryOperator.new(left: param, operation: '=', right: expression)
        end
        fn.args << (rest ? JSAnalyzer::Node::SpreadOperator.new(param) : param)
        gobble(/\p{Space}*,/)
        raise syntax_error("unexpected #{peek(1).inspect}") if @index == start
      end
    ensure
      @scope = fn.scope.parent_scope
    end

    gobble!(/\p{Space}*\{/)
    
    parse_function_body(fn, true, as_expression)
    
    fn
  end
  
  def parse_function_body(fn, brackets = true, as_expression = false)
    begin
      @scope = fn.scope
      if brackets
        fn.body.concat(parse_statement_list)
      else
        # Arrow function with an expression body
        fn.expression_body = true
        fn.body << expression
      end
    ensure
      fn.scope.close!
      @scope = fn.scope.parent_scope
    end
    gobble!(/\p{Space}*\}/) if brackets
    # An expression is ended by the statement it's in
    gobble!(/\p{Space}*;?/) unless as_expression || fn.type == :arrow
  end
  
  def parse_scope(statements=[])
    @scope = JSAnalyzer::Node::Scope.new(scope: @scope, statements: statements)
    
  ensure
    @scope.close!
    @scope = @scope.parent_scope
  end
  
  def parse_array
    array = JSAnalyzer::Node::Array.new
    until gobble(/\p{Space}*\]/)
      if gobble(/\p{Space}*,/)
        array.members << nil # a hole, as in [1, , 2]
        next
      end

      array.members << expression
      next if gobble(/\p{Space}*,/)
      gobble!(/\p{Space}*\]/)
      break
    end
    array
  end
  
  def parse_class(expression: false)
    m = gobble(/\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/o)
    name = m && [m[1], group_range(m)]

    extends = if name&.first == 'extends'
      name = nil
      m = gobble!(/\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/o)
      [m[1], group_range(m)]
    elsif (m = gobble(/\p{Space}+extends\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/o))
      [m[1], group_range(m)]
    end
    gobble!(/\p{Space}*\{/)
    klass = JSAnalyzer::Node::Class.new(scope: @scope, name: name, extends: extends, expression: expression)

    begin
      @scope = klass.scope
      while part = parse_class_part
        klass.body << part
      end
    ensure
      klass.scope.close!
      @scope = klass.scope.parent_scope
    end

    gobble!(/\p{Space}*\}\p{Space}*;?/)
    klass
  end
  
  def parse_class_part
    identifier = gobble(/\p{Space}*(\/|\*|\[|\{|\#?#{IDENTIFIER})/o)&.[](1)
    
    # Skip comments
    while identifier == "/"
      case peek(1)

      when "/"
        scan_until_eol
      when '*'
        scan_until(/\*\//)
      end
      identifier = gobble(/\p{Space}*(\/|\*|\[|\{|\#?#{IDENTIFIER})/o)&.[](1)
    end
    
    return if identifier.nil?

    # static, get, set and async are member names when nothing follows them,
    # e.g. `get(key) {}` or `static = 1`
    if %w(static get set async).include?(identifier) && peek(/\p{Space}*[(=;}]|[ \t]*\n/)
      return parse_class_member(identifier, false, false)
    end

    member = case identifier
    when "static"
      return parse_class_part.tap { |p| p.static = true }
    when "get"
      JSAnalyzer::Node::Class::Getter.new(parse_class_part)
    when "set"
      JSAnalyzer::Node::Class::Setter.new(parse_class_part)
    when "{"
      block = JSAnalyzer::Node::Class::InitializationBlock.new(scope: @scope)
      begin
        @scope = block
        parse_statement_list.each { block << it }
      ensure
        block.close!
        @scope = block.parent_scope
      end
      gobble!(/\p{Space}*\}\p{Space}*;?/)
      block
    else
      if identifier == 'async'
        async = true
        identifier = gobble!(/\p{Space}*(\*|\[|\#?#{IDENTIFIER})/o)&.[](1)
      end
      
      if identifier == '*'
        generator = true
        identifier = gobble!(/\p{Space}*(\[|\#?#{IDENTIFIER})/o)&.[](1)
      end
      
      if identifier == '['
        identifier = statement
        gobble!(/\p{Space}*\]\p{Space}*/)
      end

      return parse_class_member(identifier, async, generator)
    end
    JSAnalyzer::Node::Class::Field.new(member)
  end

  # A method or field named `name`, after its name
  def parse_class_member(name, async, generator)
    case gobble(/\p{Space}*(\(|=|;)/)&.[](1)
    when "("
      JSAnalyzer::Node::Class::Field.new(parse_function(name, async, generator, :class))
    when "="
      JSAnalyzer::Node::Class::Field.new(name, statement)
    else
      # A field without an initializer, ended by `;` or a new line
      JSAnalyzer::Node::Class::Field.new(name)
    end
  end
  
  # The target of a declaration or parameter: a name, or an object or array
  # destructuring pattern. Names are declared as `kind` ("let", "param"...).
  # Returns the VariableDeclaration or the pattern.
  def parse_binding_target(kind)
    if gobble(/\p{Space}*\{/)
      parse_object_pattern(kind)
    elsif gobble(/\p{Space}*\[/)
      parse_array_pattern(kind)
    else
      m = gobble!(/\p{Space}*(#{IDENTIFIER})/o)
      @scope.declare(kind, m[1], range: group_range(m))
    end
  end

  # `{ a, b: c, d = 1, e: { f }, ...rest }`, after the `{`
  def parse_object_pattern(kind)
    pattern = JSAnalyzer::Node::DestructureObject.new
    until gobble(/\p{Space}*\}/)
      if gobble(/\p{Space}*\.\.\./)
        pattern.add(parse_binding_target(kind), rest: true)
      else
        m = gobble!(/\p{Space}*(#{IDENTIFIER})/o)
        if gobble(/\p{Space}*:/)
          # `key: target`, where key is only a property name
          key = m[1]
          value = parse_binding_target(kind)
        else
          key = @scope.declare(kind, m[1], range: group_range(m))
          value = nil
        end
        default = gobble(/\p{Space}*=(?![=>])/) ? expression : nil
        pattern.add(key, value, default: default)
      end
      next if gobble(/\p{Space}*,/)
      gobble!(/\p{Space}*\}/)
      break
    end
    pattern
  end

  # `[a, , b = 1, [c], ...rest]`, after the `[`
  def parse_array_pattern(kind)
    pattern = JSAnalyzer::Node::DestructureArray.new
    until gobble(/\p{Space}*\]/)
      if gobble(/\p{Space}*,/)
        pattern.hole
        next
      end

      rest = gobble(/\p{Space}*\.\.\./)
      target = parse_binding_target(kind)
      if rest
        pattern.add(target, rest: true)
      else
        pattern.add(target, (expression if gobble(/\p{Space}*=(?![=>])/)))
      end
      next if gobble(/\p{Space}*,/)
      gobble!(/\p{Space}*\]/)
      break
    end
    pattern
  end

  def parse_args
    args = []
    while nibble = expression
      args << nibble
      gobble(/\p{Space}*,/)
    end
    gobble!(/\p{Space}*\)/)
    args
  end

  # Parses the body of an if, for, etc.: either a `{ ... }` block or a single
  # statement. Returns an array of statements.
  def parse_body
    if peek(/\p{Space}*\{/)
      body = parse_block
      gobble(/\p{Space}*;/)
      body
    else
      [statement_list_item].compact
    end
  end

  # Whether the statement ends here, for keywords like `return` whose value
  # must start on the same line: a `;`, `}`, the end of the source, or a new
  # line (automatic semicolon insertion). Consumes a `;`.
  def statement_ends?
    return true if gobble(/[ \t]*;/)
    !!peek(/[ \t]*(\/\/[^\n]*)?(\n|\}|\z)/)
  end

  # `with { type: "json" }` (or the older `assert { ... }`) after the module
  # specifier of an import or export. Returns [keyword, object] or nil.
  def parse_import_attributes
    return unless kw = gobble(/\p{Space}*(with|assert)(?![\p{Alpha}_\$\d])\p{Space}*\{/)&.[](1)
    [kw, parse_object]
  end

  # Parses `( expression )`, as in `if (...)`
  def parse_condition
    gobble!(/\p{Space}*\(/)
    condition = statement
    gobble!(/\p{Space}*\)/)
    condition
  end

  WHITESPACE_BYTES = [9, 10, 11, 12, 13, 32].freeze
  SEMICOLON = ';'.ord

  # Whether the last non-whitespace character consumed was a `;`. Nested
  # statement calls consume the `;` that ends them, so callers that need a
  # separator (e.g. the clauses of a for loop) check this before gobbling one.
  def terminated?
    i = @index - 1
    i -= 1 while i >= 0 && WHITESPACE_BYTES.include?(@source.getbyte(i))
    i >= 0 && @source.getbyte(i) == SEMICOLON
  end

  # Parses the right side of the binary operator `op` and pushes the
  # BinaryOperator onto the stack. Returns false, consuming nothing, if `op`
  # binds looser than min_prec and so belongs to the caller.
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
  STATEMENT_KEYWORDS = Set.new(%w(break class const continue debugger do export for function if import let return switch throw try var while with)).freeze
  BINARY_OPERATOR_TOKENS = PRECEDENCE.keys.freeze

  def statement(no_in: false, min_prec: 0, top: false)
    stack = []

    while true
      newline = gobble(WHITESPACE)&.[](0)&.include?("\n")

      if gob = gobble(/(\;|=>|\.\.\.|#{OPERATOR_REGEX}|\?|!|~|#{NUMBER}|\.|\[|\{|\(|\"|\'|\`|\##{IDENTIFIER}|#{IDENTIFIER})/o)
        token_range = group_range(gob, 0)
        if !stack.empty? && STATEMENT_KEYWORDS.include?(match)
          # A statement keyword after a complete expression starts the next
          # statement
          rewind(match.size)
          return stack.pop
        end

        case match
        when ";"
          rewind(1) if min_prec > 0
          return stack.pop
        when "export"
          return JSAnalyzer::Node::ExportStatement.parse(self)
        when "import"
          if peek(/\p{Space}*[(.]/)
            # import(...) or import.meta
            stack << JSAnalyzer::Node::Keyword.new(match)
          else
            return JSAnalyzer::Node::ImportStatement.parse(self)
          end
        when "async"
          if !stack.empty?
            rewind(match.size)
            return stack.pop
          elsif peek(/\p{Space}*(function(?![\p{Alpha}_\$\d])|\(|#{IDENTIFIER}\p{Space}*=>)/o)
            # async applies only to the function or arrow function after it
            fn = statement(min_prec: PREFIX_PRECEDENCE)
            if fn.is_a?(JSAnalyzer::Node::Method)
              fn.async = true
              return fn if top && fn.type == :function
              stack << fn
            else
              # A call to something named async, e.g. async(x)
              args = fn.is_a?(JSAnalyzer::Node::Group) ? fn.expressions : [fn]
              stack << JSAnalyzer::Node::FunctionCall.new(@scope.var("async", range: token_range), args)
            end
          else
            stack << @scope.var(match, range: token_range)
          end
          
        when "function"
          generator = !!gobble(/\p{Space}*\*/)
          m = gobble(/\p{Space}*(#{IDENTIFIER})/o)
          gobble!(/\p{Space}*\(/)
          
          fn = parse_function(m&.[](1), false, generator, :function, as_expression: !top,
                              name_range: m && group_range(m))
          return fn if top
          stack << fn
        when "class"
          klass = parse_class(expression: !top)
          return klass if top
          stack << klass
        
        when "new"
          if gobble(/\p{Space}*\.\p{Space}*target(?![\p{Alpha}_\$\d])/)
            stack << JSAnalyzer::Node::MetaProperty.new("new", "target")
            next
          end

          # new Callee(args), where Callee is a member expression and the
          # argument list is optional
          what = if gobble(/\p{Space}*\(/)
            JSAnalyzer::Node::Group.new(parse_args)
          else
            m = gobble!(/\p{Space}*(#{IDENTIFIER})/o)
            @scope.var(m[1], range: group_range(m))
          end
          while gob = gobble(/\p{Space}*(\.|\[)/)&.[](1)
            what = if gob == "."
              JSAnalyzer::Node::DotAccessor.new(object: what, key: gobble!(/\p{Space}*(#{IDENTIFIER})/o)[1])
            else
              JSAnalyzer::Node::BracketAccessor.new(what, statement).tap { gobble!(/\p{Space}*\]/) }
            end
          end
          args = gobble(/\p{Space}*\(/) ? parse_args : []
          stack << JSAnalyzer::Node::Instantiation.new(what, args)
        when "..."
          return JSAnalyzer::Node::SpreadOperator.new(expression)
        when "{"
          if stack.size > 0
            rewind(1)
            return stack.pop
          else
            stack << parse_object
          end
        when "("
          if stack.last.is_a?(JSAnalyzer::Node::Method) && stack.last.type == :arrow
            # An arrow function can't be called without parens around it
            rewind(1)
            return stack.pop
          end

          case stack.last
          when JSAnalyzer::Node::Method, JSAnalyzer::Node::VariableReference,
               JSAnalyzer::Node::DotAccessor, JSAnalyzer::Node::BracketAccessor,
               JSAnalyzer::Node::FunctionCall, JSAnalyzer::Node::Group,
               JSAnalyzer::Node::Instantiation, JSAnalyzer::Node::TaggedTemplate,
               JSAnalyzer::Node::Keyword # import(), super()
            stack << JSAnalyzer::Node::FunctionCall.new(stack.pop, parse_args)
          when nil
            # Arrow function parameters or a parenthesized expression
            mark = [@scope.references.size, @scope.children.size, @scope.pending.size]
            args = parse_args
            stack << (peek(/\p{Space}*=>/) ? ArrowParams.new(args, mark) : JSAnalyzer::Node::Group.new(args))
          else
            rewind(1)
            return stack.pop
          end


        when "?"
          if gob = gobble(/\p{Space}*(\.\[|\.\(|\.)/)&.[](1)
            stack << case gob
            when '.('
              JSAnalyzer::Node::FunctionCall.new(stack.pop, parse_args, optional_chaining: true)
            when '.['
              key = statement
              gobble!(/\p{Space}*\]\p{Space}*/)
              JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: key, optional_chaining: true)
            when '.'
              JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: gobble!(/\#?#{IDENTIFIER}/o)[0], optional_chaining: true)
            end
          else
            if PRECEDENCE['?'] < min_prec
              rewind(1)
              return stack.pop
            end

            a = statement
            gobble!(/\p{Space}*:/)
            b = statement(min_prec: PRECEDENCE['='])
            stack << JSAnalyzer::Node::Ternary.new(stack.pop, a, b)
          end
        when "."
          if stack.empty?
            raise syntax_error("unexpected #{match.inspect}")
          else
            stack << JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: gobble!(/\#?#{IDENTIFIER}/o)[0])
          end
        when "["
          if newline && !stack.empty?
            # Treat a `[` on a new line as a new statement. (JavaScript
            # itself would continue the expression here.)
            rewind(1)
            return stack.pop
          end

          stack << if stack.empty?
            parse_array
          else
            n = JSAnalyzer::Node::BracketAccessor.new(stack.pop, statement)
            gobble!(/\p{Space}*\]/)
            n
          end
        when NUMBER_TOKEN
          stack << JSAnalyzer::Node::Number.new(match)
        when /\A\#/
          # A private name on its own, as in `#x in obj`
          stack << JSAnalyzer::Node::PrivateName.new(match)
        when '"', "'"
          quote = match
          stack << JSAnalyzer::Node::String.new(quoted_value(quote), quote)
        when "`"
          stack << if stack.empty?
            tick_quoted_value
          else
            JSAnalyzer::Node::TaggedTemplate.new(stack.pop, tick_quoted_value)
          end
        when "!", "~", "delete", "typeof", "void", "await"
          # Prefix operator
          m = match
          unless stack.empty?
            # A prefix operator can't follow a value, so it starts the next
            # statement (`a \n delete b`)
            rewind(m.size)
            return stack.pop
          end
          stack <<JSAnalyzer::Node::PrefixOperator.new(m, statement(min_prec: PREFIX_PRECEDENCE))
        when "++", "--"
          # Prefix or postfix increment / decrement
          m = match
          if newline && !stack.empty?
            # `a \n ++b` is `a; ++b`
            rewind(m.size)
            return stack.pop
          end

          prefix = stack.empty?
          operand = prefix ? statement(min_prec: PREFIX_PRECEDENCE) : stack.pop
          mark_written(operand, read: true) # x++ and ++x read and write x
          stack << if prefix
            JSAnalyzer::Node::PrefixOperator.new(m, operand)
          else
            JSAnalyzer::Node::UnaryOperator.new(operand, m)
          end
        when "+", "-"
          # Prefix or Binary operator
          m = match
          if stack.empty?
            stack << JSAnalyzer::Node::PrefixOperator.new(m, statement(min_prec: PREFIX_PRECEDENCE))
          elsif !binary_operator(stack, m, min_prec, no_in)
            rewind(m.size)
            return stack.pop
          end
        when "/"
          # Comment, regex, or division
          case peek(1)
          when "/"
            match + scan_until_eol
          when '*'
            [match, scan_until(/\*\//)]
          else
            # A `/` after a value is division; anywhere else it starts a regex
            if stack.empty?
              stack << parse_regex
            elsif !binary_operator(stack, "/", min_prec, no_in)
              rewind(1)
              return stack.pop
            end
          end
        when '=>'
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

          # The parameters were parsed in this scope; move what they declared
          # and referenced into the arrow function's. That includes references
          # passed up by scopes inside them that have already closed, such as
          # a function in a default value.
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

          parse_function_body(fn, !!gobble(/\p{Space}*\{/))
          stack << fn
        when ","
          # Comma operator, or the end of an item in a list
          if stack.empty? || !binary_operator(stack, ",", min_prec, no_in)
            rewind(1)
            return stack.pop
          end
        when *BINARY_OPERATOR_TOKENS
          # Binary operator, including assignment
          m = match
          if stack.empty? && m == '/='
            # A regex starting with `=`, e.g. /=+/
            rewind(1)
            stack << parse_regex
          elsif stack.empty?
            raise syntax_error("unexpected #{match.inspect}")
          elsif !binary_operator(stack, m, min_prec, no_in)
            rewind(m.size)
            return stack.pop
          end
        when "for"
          # The head is in its own scope, for `for (let i ...)`
          with_scope(:block) do
            is_await = !!gobble(/\p{Space}*await(?![\p{Alpha}_\$\d])/) # for await (x of y)
            gobble!(/\p{Space}*\(/)
            initialization = statement(no_in: true)

            if kind = gobble(/\p{Space}*(in|of)(?![\p{Alpha}_\$\d])/)&.[](1)
              mark_written(initialization) # for (x of xs) assigns x
              right = statement
              gobble!(/\p{Space}*\)/)
              return JSAnalyzer::Node::ForIn.new(initialization, kind, right, parse_body, await: is_await)
            end

            gobble!(/\p{Space}*;/) unless terminated?
            condition = statement
            gobble!(/\p{Space}*;/) unless terminated?
            afterthought = statement
            gobble!(/\p{Space}*\)/)
            return JSAnalyzer::Node::ForLoop.new(initialization, condition, afterthought, parse_body)
          end
        when "var", "let", "const"
          node = JSAnalyzer::Node::VariableStatement.new(match)
          loop do
            target = parse_binding_target(node.kind)
            init = gobble(/\p{Space}*=(?![=>])/) ? expression : nil
            node.add(target, init)
            break unless gobble(/\p{Space}*,/)
          end
          gobble(/\p{Space}*;/) unless terminated?
          return node
        when "return"
          return JSAnalyzer::Node::ReturnStatement.new(statement_ends? ? nil : statement)
        when "yield"
          delegate = !!gobble(/\p{Space}*\*/) # yield* iterable
          return JSAnalyzer::Node::Yield.new(statement_ends? ? nil : statement, delegate: delegate)
        when "with"
          return JSAnalyzer::Node::With.new(parse_condition, parse_body)
        when "debugger"
          gobble(/\p{Space}*;/)
          return JSAnalyzer::Node::DebuggerStatement.new
        when "true", "false"
          stack <<  JSAnalyzer::Node::Boolean.new(match == "true")
        when "if"
          node = JSAnalyzer::Node::If.new(parse_condition, parse_body)
          while gobble(/\p{Space}*else(?![\p{Alpha}_\$\d])/)
            if gobble(/\p{Space}*if(?![\p{Alpha}_\$\d])/)
              node.else_if(parse_condition, parse_body)
            else
              node.else(parse_body)
              break
            end
          end
          return node
        when "while"
          return JSAnalyzer::Node::While.new(parse_condition, parse_body)
        when "do"
          body = parse_body
          gobble!(/\p{Space}*while(?![\p{Alpha}_\$\d])/)
          condition = parse_condition
          gobble(/\p{Space}*;/)
          return JSAnalyzer::Node::DoWhile.new(body, condition)
        when "throw"
          return JSAnalyzer::Node::ThrowStatement.new(statement)
        when "try"
          node = JSAnalyzer::Node::Try.new(parse_block)
          if gobble(/\p{Space}*catch(?![\p{Alpha}_\$\d])/)
            with_scope(:catch) do
              if gobble(/\p{Space}*\(/)
                node.param = parse_binding_target('catch')
                gobble!(/\p{Space}*\)/)
              end
              node.handler = parse_block
            end
          end
          if gobble(/\p{Space}*finally(?![\p{Alpha}_\$\d])/)
            node.finalizer = parse_block
          end
          return node
        when "switch"
          node = JSAnalyzer::Node::Switch.new(parse_condition)
          gobble!(/\p{Space}*\{/)
          case_end = /\p{Space}*((case|default)(?![\p{Alpha}_\$\d])|\}|\z)/
          with_scope(:block) do
            while kind = gobble(/\p{Space}*(case|default)(?![\p{Alpha}_\$\d])/)&.[](1)
              test = kind == "case" ? statement : nil
              gobble!(/\p{Space}*:/)
              node.cases << [test, parse_statement_list(case_end)]
            end
          end
          gobble!(/\p{Space}*\}/)
          return node
        when "break", "continue"
          keyword = match
          label = gobble(/[ \t]+(#{IDENTIFIER})/o)&.[](1)
          gobble(/\p{Space}*;/)
          return JSAnalyzer::Node::JumpStatement.new(keyword, label)
        when "this", "super", "null"
          if stack.size > 0
            rewind(match.size)
            return stack.pop
          end
          stack << JSAnalyzer::Node::Keyword.new(match)
        when IDENTIFIER
          if stack.size > 0
            rewind(match.size)
            return stack.pop
          else
            stack << @scope.var(match, range: token_range)
          end
        else
          # TODO: unhandled token
        end
      else
        gobble(/\p{Space}*;?/)
        if stack.size > 1
          raise "stack issue: #{stack.map(&:to_js).join("; ")}"
        end
        return stack.pop
      end
    end
  end

  OBJECT_KEY = /#{IDENTIFIER}|#{NUMBER}|"(\\"|(?!\\)[^"])+"/o
  def continue_object(key)
    obj = ['{', key]
    obj << statement
    
    while true
      gobble(WHITESPACE)
    # puts ['continue_object', peek(1), obj].inspect
      case peek(1)
      when "}"
        obj << gobble("}")[0]
        break
      when ","
        gobble(",")
        object_key(obj)
        # puts ['continue_object', peek(1), obj].inspect
        # puts cursor
        # puts match
        obj << if peek(/\p{Space}*,/)
          'NO KEY'
        else
          gobble(/\p{Space}*:/)
          statement
        end
      when "/"
        obj << if peek(1) == "/"
          match + scan_until_eol
        else
          # error
        end
      end
    end

    
    obj
  end
  
  def object_key(obj)
    # puts "object_key"

    while true
      scan_until(/(\[|#{NUMBER}|\/\/|\"|\'|#{IDENTIFIER})/o)

      case match
      when NUMBER_TOKEN
        return match
      when "["
        expr = statement
        gobble(/\p{Space}*\]/)
        return ["[", expr, "]"]
      when "\""
        return double_quoted_value
      when "'"
        return single_quoted_value
      when IDENTIFIER
        if gobble(/\p{Space}*\(/)
        else
          return match
        end
      when "//"
        obj << match + scan_until_eol
      else
        raise 'Syntax Error'
      end
      gobble(/\p{Space}*:/)
    end
  end

  def block
    block_statements = []
    while peek(1) != "}"
      block_statements << statement
      gobble(WHITESPACE)
    end
    block_statements
  end

  # Parses the rest of a template literal after the opening backtick. Text is
  # kept as written, including escapes.
  def tick_quoted_value
    ret_value = JSAnalyzer::Node::InterpolatedString.new

    while true
      text = gobble(/(?:[^`\\$]|\\.|\$(?!\{))*/m)[0]
      ret_value << text unless text.empty?

      if gobble("${")
        ret_value << statement
        gobble!(/\p{Space}*\}/)
      elsif gobble("`")
        return ret_value
      else
        raise syntax_error("unterminated template literal")
      end
    end
  end
  
  def parse_regex
    ret_value = String.new

    regex_stack =  ['/']
    while !regex_stack.empty?
      scan_until(/[\/\[\]]/)
      escaped = pre_match[-1] == "\\" && pre_match[-2] != "\\"
      ret_value << pre_match
      case match
      when "["
        regex_stack << '[' if !escaped && regex_stack.last != "["
        ret_value << match
      when "]"
        regex_stack.pop if !escaped && regex_stack.last == "["
        ret_value << match
      when "/"
        # From https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Character_class
        # 
        # The lexical grammar does a very rough parse of regex literals, so
        # that it does not end the regex literal at a / character which appears
        # within a character class. This means /[/]/ is valid without needing
        # to escape the /.
        if !escaped && regex_stack.last != "[" && regex_stack.pop != "/"
          raise syntax_error("unexpected \"/\"")
        else
          ret_value << match
        end
      end
    end
  
    JSAnalyzer::Node::Regex.new(ret_value[..-2],gobble(/\p{Alpha}+/)&.[](0))
  end
  
  
end