require "js_analyzer/node"

class JSAnalyzer::Parser
  include StreamParser

    attr_accessor :scope
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
  
  
  BINARY_OPERATORS = %w(+ - * ** / % += -= *= /= %= **= = == === != !== > < >= <= && &&= || ||= !=)
  BINARY_OPERATOR_REGEX = Regexp.new(BINARY_OPERATORS.map{|o| o.gsub(/[\*\&\|\+]/) { |i| "\\#{i}" } }.join("|"))
  
  WHITESPACE = /\p{Space}+/
  IDENTIFIER = /[\p{Alpha}_\$][\p{Alpha}_\$\d]*/
  NUMBER = /\d+|\d*\.\d+/
  
  def parse
    @scope = JSAnalyzer::Node::Program.new
    
    while !eos?
      @scope.statements << statement

      if @scope.statements.last.respond_to?(:to_js)
        puts "JS: " + @scope.statements.last.to_js
      else
        puts "SR: " + @scope.statements.last.inspect
      end
    end
  end
  
  
  
  def parse_object
    obj = JSAnalyzer::Node::Object.new
    
    while true
      gobble(WHITESPACE)
      gob = gobble(/(\}|\[|\"|\'|#{NUMBER}|#{IDENTIFIER}|\.\.\.|\/\/)/)
      # puts ['parse_object', gob].inspect
      case gob[0]
      when "}"
      # puts ['parse_objected', obj].inspect
        return obj
      when "["
        key = statement
        gobble!(/\p{Space}*\]\p{Space}*/)
        return parse_scope([JSAnalyzer::Node::Array.new([key])]) unless gobble(/\p{Space}*:\p{Space}/)
        obj.add(key, statement)
        gobble(/\p{Space}*,/)
      when '"', "'"
        key = quoted_value(match)
        return parse_scope([key]) unless gobble(/\p{Space}*:\p{Space}*/)
        obj.add(key, statement)
        gobble(/\p{Space}*,/)
      when "class"
        return JSAnalyzer::Node::ClassStatement.parse(self)
      when NUMBER
        key = match
        return parse_scope([key]) unless gobble(/\p{Space}*:\p{Space}*/)
        obj.add(key, statement)
        gobble(/\p{Space}*,/)
      when IDENTIFIER
        key = match
        return parse_scope([key]) unless gob = gobble(/\p{Space}*([:,\(])\p{Space}*/)
        # puts ['gob', gob[1]].inspect
        case gob[1]
        when ","
          obj.shorthand(@scope.var(key))
        when "("
          args = function_arguments
          gobble!(/\p{Space}*\{/)
          obj.add(key, JSAnalyzer::Node::Method.new(
            args: args,
            body: function_body,
            scope: @scope
          ))
          gobble(/\p{Space}*,/)
        else
          obj.add(key, statement)
          gobble(/\p{Space}*,/)
        end

      when '...'
        variable = @scope.var(gobble!(IDENTIFIER))
        obj.spread(variable)
        gobble(/\p{Space}*,/)
      when "//"
        # skip
        match + scan_until_eol
      else
        puts 'OBJECT WARNING'
      end
    end
  end
  
  def function_arguments
    args = []

    while nibble = gobble!(/\p{Space}*(\)|\.\.\.|#{IDENTIFIER})/)
      case nibble[1]
      when ")"
        return args
      when "..."
        args << JSAnalyzer::Node::SpreadEntry.new
      when IDENTIFIER
        args << nibble[1]
      else
        raise 'Fun Arg syntax error'
      end
    end
  end
  
  def function_body
    body = JSAnalyzer::Node::MethodBody.new(scope: @scope)
    @scope = body
    while  st = statement
      body.statements << st
    end
    gobble!(/\p{Space}*\}/)
    body
  ensure
    @scope = body.parent_scope
  end
  
  def parse_function(name, async, generator)
    fn = JSAnalyzer::Node::Method.new(name: name, async: async, scope: @scope, generator: generator)

    # Parse Arguments
    while nibble = gobble(/\p{Space}*(\/|\.\.\.|#{IDENTIFIER})/)
      case nibble[1]
      when "..."
        fn.args << JSAnalyzer::Node::SpreadEntry.new
      when IDENTIFIER
        fn.args << fn.scope.declare(nibble[1])
      else
        raise 'Fun Arg syntax error'
      end
      gobble(/\p{Space}*,/)
    end

    gobble!(/\p{Space}*\)\p{Space}*\{/)
    
    begin
      @scope = fn.scope
      while  st = statement
        fn.body << st
      end
    ensure
      @scope = fn.scope.parent_scope
    end
puts cursor
    gobble!(/\p{Space}*\}\p{Space}*;?/)

    fn
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
    klass = JSAnalyzer::Node::ClassStatement.new(scope: scope, name: name, extends: extends)
    
    begin
      scope = klass.scope
      while identifier = gobble(/\p{Space}*(\*|\[|\#|#{IDENTIFIER})/)&.[](1)
        case identifier
        when '*'
        when '['
        when '#'
        else
          if identifier == 'async'
            async = true
            identifier = gobble!(/\p{Space}*(\*|\[|#{IDENTIFIER})/)&.[](1)
          end
          
          if identifier == '*'
            generator = true
            identifier = gobble!(/\p{Space}*(\[|#{IDENTIFIER})/)&.[](1)
          end
          
          if identifier == '['
            identifier = statement
            gobble!(/\p{Space}*\]\p{Space}*/)
          end

          if gobble!(/\p{Space}*\(/)
            parse_function(identifier, async, generator)
          else
            puts 'error'
          end
        end
      end
    ensure
      scope = klass.scope.parent_scope
    end

    gobble!(/\p{Space}*\}\p{Space}*;?/)
    klass
  end

  def statement
    stack = []
    
    while true
      gobble(WHITESPACE)
      if x = gobble(/(#{BINARY_OPERATOR_REGEX}|\.|\[|\{|\(|\"|\'|\`|#{NUMBER}|#{IDENTIFIER})/)
        puts x.inspect
        puts match.inspect
        puts stack.last&.to_js
        case match
        when "export"
          x = JSAnalyzer::Node::ExportStatement.parse(self)
          puts "EX: #{x.to_js}"
          return x
        when "import"
          return JSAnalyzer::Node::ImportStatement.parse(self)
        when "function", "async"
          async = gobble!(/\p{Space}+function/) if match == 'async'
          generator = true if gobble(/\*/)
          name = gobble(/\p{Space}+(#{IDENTIFIER})/)&.[](1)
          gobble!(/\p{Space}*\(/)
          
          return parse_function(name, async, generator)
        when "class"
          return parse_class
        when "{"
          stack << parse_object
        when "("
          x = statement
          gobble!(/\p{Space}*\)/)
          stack << if gobble(/\p{Space}*=>\p{Space}*\{/)
            JSAnalyzer::Node::Method.new(
              args: x||[],
              body: function_body,
              scope: @scope
            )
          else
            x
          end
        when "."
          stack << if stack.empty?
            raise 'Stack expected'
          else
            JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: match, right: statement, spacing: nil)
          end
        when "["
          stmnt << parse_array
        when NUMBER
          puts :number
          stack << JSAnalyzer::Node::Number.new(match)
        when '"', "'"
          stack << JSAnalyzer::Node::String.new(quoted_value(match), match)
        when "!"
          # Left Unary operator
        when "++", "--"
          # Left or Right Unary operator
        when "+", "-"
          # Left Unary or Binary operator
          stack << if stack.empty?
            raise 'Stack expected'
          else
            JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: match, right: statement)
          end
        when "/"
          # Binary operator or comment
          case peek(1)
          when "/"
            match + scan_until_eol
          when '*'
            [match, scan_until(/\*\//)]
          else
            match
          end
        when '*', "**", "%", "+=", "-=", "*=", "/=", "%=", "**=", "=", "==", "===", "!=", "!==", '>', "<", ">=", '<=', '&&', '&&=', '||', '||='
          # Binary operator
          byebug
          stack << if stack.empty?
            raise 'Stack expected'
          else
            JSAnalyzer::Node::BinaryOperator.new(left: stack.pop, operation: match, right: statement)
          end
        when "var", "let", "const"
          type = match
          case name = gobble!(/\p{Space}*(\{|\[|#{IDENTIFIER})/)[1]
          when "{"
            d = JSAnalyzer::Node::DestructureObject.new
            while gob = gobble(/\p{Space}*(#{JSAnalyzer::Parser::IDENTIFIER})\p{Space}*/)
              d.add(@scope.declare('destructure', gob[1]), gobble(/:\p{Space}*/) ? statement : nil)
              gobble(/\p{Space}*,/)
            end
            gobble!(/\p{Space}*\}/)

            y = if gobble(/\p{Space}*=/)
              JSAnalyzer::Node::BinaryOperator.new(left: d, operation: "=", right: statement)
            else
              d
            end
            return y
          when "["
            d = JSAnalyzer::Node::DestructureArray.new
            while gob = gobble(/\p{Space}*(#{JSAnalyzer::Parser::IDENTIFIER})\p{Space}*/)
              d.add(@scope.declare('destructure', gob[1]), gobble(/=\p{Space}*/) ? statement : nil)
              gobble(/\p{Space}*,/)
            end
            gobble!(/\p{Space}*\]/)

            y = if gobble(/\p{Space}*=/)
              JSAnalyzer::Node::BinaryOperator.new(left: d, operation: "=", right: statement)
            else
              d
            end
            return y
          else
            declaration = @scope.declare(type)
            initialization = statement if gobble(/\p{Space}*=/)
            declaration.add(name, initialization)
            puts cursor
            while gob = gobble(/\p{Space}*(,|\[|\{|\/\/|\/\*)/)&.[](1)
            puts gob.inspect
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
          gobble(/\p{Space}*;?/)
          return declaration
        when "return"
          stack << JSAnalyzer::Node::ReturnStatement.new(statement)
          
        when "true", "false"
          stack <<  JSAnalyzer::Node::Boolean.new(match == "true")
        when "if"
          gobble!(/\p{Space}*\(/)
          condition = statement
          gobble!(/\p{Space}*\)\p{Space}*\{/)
          stack << JSAnalyzer::Node::If.new(condition, function_body)
        when "else"
          gob = gobble!(/\p{Space}*({|if)/)[1]
          if gob == "if"
            gobble!(/\p{Space}*\(/)
            condition = statement
            gobble!(/\p{Space}*\)\p{Space}*\{/)
            stack.last.else_if(condition, function_body)
          else
            stack.last.else(function_body)
          end
        when IDENTIFIER
          stack <<  @scope.var(match)
        when ","
          puts ',,,,,,'
        else
        puts match, '-----------'
        end
      else
        gobble(/\p{Space}*;?/)
        return stack.pop
      end
    end

    stmnt
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
        puts "ELSE"
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
      # puts ['object_key', match].inspect
      case match
      when NUMBER
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
        if gooble(/\p{Space}*\(/)
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
  
  # def block_or_object
  #   key:
  #   1:
  #   "sdf":
  #   's':
  #   shorthandProperty,
  #   method(parameters) {},
  #   get property() {},
  #     set property(value) {},
    
  #     [expression]: "computed property",
  #     ...spread
      
  #   scan_until //
  # end

  def block
    block_statements = []
    while peek(1) != "}"
      block_statements << statement
      gobble(WHITESPACE)
    end
    block_statements
  end

end