class JSAnalyzer::Parser
  
  include StreamParser
  
  attr_accessor :scope # TODO: remove
  
  # StreamParser util updates
  def scan_until_eol
    scan_until(/[^\n\f]+(\n+|\f|\z)/)
    match
  end
  
  def peek(n=1)
    if n.is_a?(Regexp)
      m = @source.match(n, @index)
      if m&.begin(0) == @index
        m
      end
    else
      @source.slice(@index, n)
    end
  end
  
  def gobble!(r)
    x = gobble(r)
    raise 'SyntaxError' unless x
    x
  end
  
  # DSL helpers
  # def p(pattern, precedence: 0)
  #   @patterns.rindex { |ps| ps[0] }
  #   @patterns << [precedence, pattern]
    
  # end
  
  BINARY_OPERATORS = %w(+ - * ** / % += -= *= /= %= **= = == === != !== > < >= <= && &&= || ||= !=).sort_by(&:length).reverse
  UNARY_OPERATORS = %w(++ --)
  OPERATORS = UNARY_OPERATORS+BINARY_OPERATORS
  OPERATOR_REGEX = Regexp.new(OPERATORS.map{|o| o.gsub(/[\*\&\|\+]/) { |i| "\\#{i}" } }.join("|"))

  WHITESPACE = /\p{Space}+/
  IDENTIFIER = /[\p{Alpha}_\$][\p{Alpha}_\$\d]*/
  NUMBER = /0[xX][\da-fA-F_]+n?|0[oO][0-7_]+n?|0[bB][01_]+n?|(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?n?/
  NUMBER_TOKEN = /\A(?:#{NUMBER})\z/
  
  def parse
    @scope = JSAnalyzer::Node::Program.new
    
    while !eos?
      @scope << statement
    end
    
    @scope
  end
  
  def parse_object
    obj = JSAnalyzer::Node::Object.new
    
    while true
      gobble(WHITESPACE)
      gob = gobble(/(\}|\[|\"|\'|#{NUMBER}|#{IDENTIFIER}|\.\.\.|\/|\*)/)

      case gob[0]
      when "}"
        return obj
      when "["
        key = statement
        gobble!(/\p{Space}*\]\p{Space}*/)
        case gobble(/\p{Space}*(\:|\()\p{Space}*/)&.[](1)
        when ':'
          obj.add(key, statement)
          gobble(/\p{Space}*,/)
        when '('
          obj.shorthand(parse_function(key, false, false, :class))
          gobble(/\p{Space}*,/)
        else
          parse_scope([JSAnalyzer::Node::Array.new([key])])
        end

      when '"', "'"
        key = quoted_value(match)
        return parse_scope([key]) unless gobble(/\p{Space}*:\p{Space}*/)
        obj.add(key, statement)
        gobble(/\p{Space}*,/)
      when "class"
        return JSAnalyzer::Node::Class.parse(self)
      when '...'
        variable = @scope.var(gobble!(IDENTIFIER))
        obj.spread(variable)
        gobble(/\p{Space}*,/)
      when "/"
        case peek(1)
        when "/"
          scan_until_eol
        when '*'
          scan_until(/\*\//)
        end
      when "*"
        key = gobble!(/\p{Space}*(\[|#{IDENTIFIER})/)&.[](1)
        
        if key == '['
          key = statement
          gobble!(/\p{Space}*\]\p{Space}*/)
        end
        
        gobble!(/\p{Space}*\(/)
        obj.shorthand(parse_function(key, false, true, :class))
        gobble(/\p{Space}*,/)
      when 'async'
        key = gobble!(/\p{Space}*(\*|\[|#{IDENTIFIER})/)&.[](1)
        if key == '*'
          generator = true
          key = gobble!(/\p{Space}*(\[|#{IDENTIFIER})/)&.[](1)
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
        obj.add(key, statement)
        gobble(/\p{Space}*,/)
      when IDENTIFIER
        key = match
        return parse_scope([key]) unless gob = gobble(/\p{Space}*([:,\(])\p{Space}*/)
        
        case gob[1]
        when ","
          obj.shorthand(@scope.var(key))
        when "("
          obj.add(key, parse_function(key, false, false, :class))
          gobble(/\p{Space}*,/)
        else
          obj.add(key, statement)
          gobble(/\p{Space}*,/)
        end

      else
        # TODO: unhandled object member
      end
    end
  end
  
  def parse_function(name, async, generator, type)
    fn = JSAnalyzer::Node::Method.new(name: name, async: async, scope: @scope, generator: generator, type: type)

    # Parse Arguments
    while nibble = gobble(/\p{Space}*(\/|\.\.\.|#{IDENTIFIER})/)
      case nibble[1]
      when "..."
        fn.args << JSAnalyzer::Node::SpreadOperator.new
      when IDENTIFIER
        fn.args << fn.scope.declare('argument', nibble[1])
      else
        raise 'Fun Arg syntax error'
      end
      gobble(/\p{Space}*,/)
    end

    gobble!(/\p{Space}*\)\p{Space}*\{/)
    
    parse_function_body(fn)
    
    fn
  end
  
  def parse_function_body(fn, brackets = true)
    begin
      @scope = fn.scope
      while st = statement
        fn.body << st
        break if !brackets
      end
    ensure
      @scope = fn.scope.parent_scope
    end
    gobble!(/\p{Space}*\}/) if brackets
    gobble!(/\p{Space}*;?/)
  end
  
  def parse_scope(statements=[])
    @scope = JSAnalyzer::Node::Scope.new(scope: @scope, statements: statements)
    
  ensure
    @scope = @scope.parent_scope
  end
  
  def parse_array
    array = JSAnalyzer::Node::Array.new
    array.members << statement
    while gobble(/\p{Space}*\,/)
      array.members << statement
    end
    gobble!(/\p{Space}*\]/)
    array
  end
  
  def parse_class
    name = gobble(/\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)&.[](1)

    extends = if name == 'extends'
      name = nil
      gobble!(/\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
    else
      gobble(/\p{Space}+extends\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)&.[](1)
    end
    gobble!(/\p{Space}*\{/)
    klass = JSAnalyzer::Node::Class.new(scope: @scope, name: name, extends: extends)

    begin
      @scope = klass.scope
      while part = parse_class_part
        klass.body << part
      end
    ensure
      @scope = klass.scope.parent_scope
    end

    gobble!(/\p{Space}*\}\p{Space}*;?/)
    klass
  end
  
  def parse_class_part
    identifier = gobble(/\p{Space}*(\/|\*|\[|\{|\#?#{IDENTIFIER})/)&.[](1)
    
    # Skip comments
    while identifier == "/"
      case peek(1)

      when "/"
        scan_until_eol
      when '*'
        scan_until(/\*\//)
      end
      identifier = gobble(/\p{Space}*(\/|\*|\[|\{|\#?#{IDENTIFIER})/)&.[](1)
    end
    
    return if identifier.nil?

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
        while st = statement
          block << st
        end
      ensure
        @scope = block.parent_scope
      end
      gobble!(/\p{Space}*\}\p{Space}*;?/)
      block
    else
      if identifier == 'async'
        async = true
        identifier = gobble!(/\p{Space}*(\*|\[|\#?#{IDENTIFIER})/)&.[](1)
      end
      
      if identifier == '*'
        generator = true
        identifier = gobble!(/\p{Space}*(\[|\#?#{IDENTIFIER})/)&.[](1)
      end
      
      if identifier == '['
        identifier = statement
        gobble!(/\p{Space}*\]\p{Space}*/)
      end

      case gobble!(/\p{Space}*(\(|=|;)/)[1]
      when "("
        parse_function(identifier, async, generator, :class)
      when "="
        return JSAnalyzer::Node::Class::Field.new(identifier, statement)
      else
        identifier
      end
    end
    JSAnalyzer::Node::Class::Field.new(member)
  end
  
  def parse_args
    args = []
    while nibble = statement
      args << nibble
      gobble(/\p{Space}*,/)
    end
    gobble!(/\p{Space}*\)/)
    args
  end

  # Parses the body of an if, for, etc.: either a `{ ... }` block or a single
  # statement. Returns an array of statements.
  def parse_body
    if gobble(/\p{Space}*\{/)
      body = []
      while st = statement
        body << st
      end
      gobble!(/\p{Space}*\}/)
      gobble(/\p{Space}*;/)
      body
    else
      [statement].compact
    end
  end

  # Parses `( expression )`, as in `if (...)`
  def parse_condition
    gobble!(/\p{Space}*\(/)
    condition = statement
    gobble!(/\p{Space}*\)/)
    condition
  end

  # Whether the last non-whitespace character consumed was a `;`. Nested
  # statement calls consume the `;` that ends them, so callers that need a
  # separator (e.g. the clauses of a for loop) check this before gobbling one.
  def terminated?
    return false if @index == 0
    i = @source.rindex(/\S/, @index - 1)
    !i.nil? && @source[i] == ';'
  end

  # no_in:   stop before an `in` operator (the first clause of a for loop)
  # operand: parse only the operand of a prefix operator; stop before any
  #          binary operator, ternary, or `;`
  def statement(no_in: false, operand: false)
    stack = []

    while true
      gobble(WHITESPACE)

      if gob = gobble(/(\;|=>|\?|\.\.\.|#{OPERATOR_REGEX}|!|~|#{NUMBER}|\.|\[|\{|\(|\"|\'|\`|#{IDENTIFIER})/)
        case match
        when ";"
          rewind(1) if operand
          return stack.pop
        when "export"
          return JSAnalyzer::Node::ExportStatement.parse(self)
        when "import"
          return JSAnalyzer::Node::ImportStatement.parse(self)
        when "async"
          if !stack.empty?
            rewind(match.size)
            return stack.pop
          else
            return statement.tap { |s| s.async = true }
          end
          
        when "function"
          generator = !!gobble(/\p{Space}*\*/)
          name = gobble(/\p{Space}*(#{IDENTIFIER})/)&.[](1)
          gobble!(/\p{Space}*\(/)
          
          return parse_function(name, false, generator, :function)
        when "class"
          return parse_class
        
        when "new"
          what = @scope.var(gobble!(/\p{Space}*(#{IDENTIFIER})/)[1])
          gobble!(/\p{Space}*\(/)
          stack << JSAnalyzer::Node::Instantiation.new(what, parse_args)
        when "..."
          var = gobble(/\p{Space}*(#{IDENTIFIER})/)&.[](1)
          return JSAnalyzer::Node::SpreadOperator.new(var ? @scope.var(var) : nil)
        when "{"
          if stack.size > 0
            rewind(1)
            return stack.pop
          else
            stack << parse_object
          end
        when "("
          case stack.last
          when JSAnalyzer::Node::Method, JSAnalyzer::Node::VariableReference,
               JSAnalyzer::Node::DotAccessor, JSAnalyzer::Node::BracketAccessor,
               JSAnalyzer::Node::FunctionCall, JSAnalyzer::Node::Group
            stack << JSAnalyzer::Node::FunctionCall.new(stack.pop, parse_args)
          when nil
            # Arrow function parameters or a parenthesized expression
            args = parse_args
            stack << (peek(/\p{Space}*=>/) ? args : JSAnalyzer::Node::Group.new(args))
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
              JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: gobble!(/#{IDENTIFIER}/)[0], optional_chaining: true)
            end
          else
            if operand
              rewind(1)
              return stack.pop
            end

            a = statement
            gobble!(/\p{Space}*:/)
            return JSAnalyzer::Node::Ternary.new(stack.pop, a, statement)
          end
        when "."
          if stack.empty?
            raise 'Stack expected'
          else
            stack << JSAnalyzer::Node::DotAccessor.new(object: stack.pop, key: gobble!(/#{IDENTIFIER}/)[0])
          end
        when "["
          stack << if stack.last.is_a?(JSAnalyzer::Node::VariableReference)
            n = JSAnalyzer::Node::BracketAccessor.new(stack.pop, statement)
            gobble!(']')
            n
          elsif stack.size > 0
            rewind(1)
            return stack.pop
          else
            parse_array
          end
        when NUMBER_TOKEN
          stack << JSAnalyzer::Node::Number.new(match)
        when '"', "'"
          stack << JSAnalyzer::Node::String.new(quoted_value(match), match)
        when "`"
          stack << tick_quoted_value
        when "!", "~", "delete", "typeof", "void"
          # Prefix operator
          m = match
          stack << JSAnalyzer::Node::PrefixOperator.new(m, statement(operand: true))
        when "++", "--"
          # Left or Right Unary operator
          stack << JSAnalyzer::Node::UnaryOperator.new(stack.pop, match)
        when "+", "-"
          # Prefix or Binary operator
          m = match
          if stack.empty?
            stack << JSAnalyzer::Node::PrefixOperator.new(m, statement(operand: true))
          elsif operand
            rewind(m.size)
            return stack.pop
          else
            y = statement
            stack << JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: m, right: y)
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
            elsif operand
              rewind(1)
              return stack.pop
            else
              y = statement
              stack << JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: "/", right: y)
            end
          end
        # Assignment
        when '='
          if operand
            rewind(1)
            return stack.pop
          end
          return JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: match, right: statement)
        when '=>'
          fn = JSAnalyzer::Node::Method.new(args: stack.pop, scope: @scope, type: :arrow)
          parse_function_body(fn, !!gobble(/\p{Space}*\{/))
          return fn
        when 'in', '*', "**", "%", "+=", "-=", "*=", "/=", "%=", "**=", "==", "===", "!=", "!==", '>', "<", ">=", '<=', '&&', '&&=', '||', '||='
          # Binary operator
          m = match
          if stack.empty? && m == '/='
            # A regex starting with `=`, e.g. /=+/
            rewind(1)
            stack << parse_regex
          elsif stack.empty?
            raise 'Stack expected'
          elsif operand || (no_in && m == 'in')
            rewind(m.size)
            return stack.pop
          else
            y = statement
            stack << JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: m, right: y)
          end
        when "for"
          gobble!(/\p{Space}*\(/)
          initialization = statement(no_in: true)

          if kind = gobble(/\p{Space}*(in|of)(?![\p{Alpha}_\$\d])/)&.[](1)
            right = statement
            gobble!(/\p{Space}*\)/)
            return JSAnalyzer::Node::ForIn.new(initialization, kind, right, parse_body)
          end

          gobble!(/\p{Space}*;/) unless terminated?
          condition = statement
          gobble!(/\p{Space}*;/) unless terminated?
          afterthought = statement
          gobble!(/\p{Space}*\)/)
          return JSAnalyzer::Node::ForLoop.new(initialization, condition, afterthought, parse_body)
        when "var", "let", "const"
          type = match
          case name = gobble!(/\p{Space}*(\{|\[|#{IDENTIFIER})/)[1]
          when "{"
            d = JSAnalyzer::Node::DestructureObject.new(type)
            while gob = gobble(/\p{Space}*(#{JSAnalyzer::Parser::IDENTIFIER})\p{Space}*/)
              d.add(@scope.declare('destructure', gob[1]), gobble(/:\p{Space}*/) ? statement : nil)
              gobble(/\p{Space}*,/)
            end
            gobble!(/\p{Space}*\}/)

            y = if gobble(/\p{Space}*=/)
              z = statement
              JSAnalyzer::Node::BinaryOperator.new(left: d, operation: "=", right: z)
            else
              d
            end
            return y
          when "["
            d = JSAnalyzer::Node::DestructureArray.new(type)
            while gob = gobble(/\p{Space}*(#{JSAnalyzer::Parser::IDENTIFIER})\p{Space}*/)
              d.add(@scope.declare('destructure', gob[1]), gobble(/=\p{Space}*/) ? statement : nil)
              gobble(/\p{Space}*,/)
            end
            gobble!(/\p{Space}*\]/)

            y = if gobble(/\p{Space}*=/)
              z = statement
              JSAnalyzer::Node::BinaryOperator.new(left: d, operation: "=", right: z)
            else
              d
            end
            return y
          else
            declaration = @scope.declare(type)
            stack << declaration
            initialization = statement if gobble(/\p{Space}*=/)
            declaration.add(name, initialization)

            while gob = gobble(/\p{Space}*(,|\[|\{|\/\/|\/\*)/)&.[](1)
              case gob
              when "/*"
                scan_until(/\*\//)
              when "//"
                scan_until_eol
              when ","
                name = gobble!(/\p{Space}*(#{IDENTIFIER})/)[1]
                init = statement if gobble(/\p{Space}*=/)
                declaration.add(name, init)
              end
            end
          end
          gobble(/\p{Space}*;/) unless terminated?
          return declaration
        when "return"
          return JSAnalyzer::Node::ReturnStatement.new(statement)
        when "yield"
          return JSAnalyzer::Node::Yield.new(statement)
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
        when "break", "continue"
          keyword = match
          label = gobble(/[ \t]+(#{IDENTIFIER})/)&.[](1)
          gobble(/\p{Space}*;/)
          return JSAnalyzer::Node::JumpStatement.new(keyword, label)
        when IDENTIFIER
          if stack.size > 0
            rewind(match.size)
            return stack.pop
          else
            stack << @scope.var(match)
          end
        when ","
          # TODO: comma operator
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

  OBJECT_KEY = /#{IDENTIFIER}|#{NUMBER}|"(\\"|(?!\\)[^"])+"/
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
      scan_until(/(\[|#{NUMBER}|\/\/|\"|\'|#{IDENTIFIER})/)

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

  def tick_quoted_value
    ret_value = JSAnalyzer::Node::InterpolatedString.new

    while scan_until(/[\`\$]/)
      if match == "\`"
        if pre_match[-1] != "\\"
          ret_value << pre_match
          return ret_value
        else
          ret_value << pre_match[..2]
        end
      elsif match == "$" && peek(1) == '{'
        ret_value << pre_match
        forward(1)
        ret_value << statement
        gobble!(/\p{Space}*\}/)
      else
        raise NotImplementedError, "unhandled `$` in template literal"
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
          raise unexptected_token("/")
        else
          ret_value << match
        end
      end
    end
  
    JSAnalyzer::Node::Regex.new(ret_value[..-2],gobble(/\p{Alpha}+/)&.[](0))
  end
  
  
end