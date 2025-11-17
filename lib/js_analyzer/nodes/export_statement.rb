class JSAnalyzer::Node::ExportStatement

  class As
    attr_reader :var, :name

    def initialize(var, name)
      @var = var
      @name = name
    end
    
    def to_js
      "#{var.to_js} as #{@name}"
    end
  end
  
  class Default
    attr_reader :value
    
    def initialize(value)
      @value = value
    end
    
    def to_js
      "default #{@value.to_js}"
    end
  end

  class Glob
    attr_reader :values
    
    def initialize
      @values = []
    end
    
    def <<(v)
      @values << v
    end
    
    def to_js
      "{#{@values.map(&:to_js).join(', ')}}"
    end
  end

  
  attr_reader :variables, :default
  
  def initialize(vars=[])
    @variables = vars
  end

  def export(variable)
    @variables << variable
  end
  
  def export_as(variable, as)
    @variables << As.new(variable, as)
  end
  
  def to_js
    puts @variables.inspect
    "export #{@variables.map(&:to_js).join(', ')}"
  end
  
  def self.parse(parser)
    xport = JSAnalyzer::Node::ExportStatement.new
    gob = parser.gobble!(/\p{Space}*(\{|\*|default|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
    
    case gob
    when '*'
    when 'default'
      xport.export(Default.new(parser.statement))
    when '{'
      glob = Glob.new
      while var_name = parser.gobble(/\p{Space}*(\/\*|\/\/|#{JSAnalyzer::Parser::IDENTIFIER})/)&.[](1)
        case var_name
        when "/*"
          parser.scan_until(/\*\//)
        when "//"
          parser.scan_until_eol
        else
          var = parser.scope.var(var_name)
          if parser.gobble(/\p{Space}+as/)
            as = parser.gobble!(/\p{Space}+(\'|\"|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
            glob << if as == "'" || as == '"'
              As.new(var, parser.quoted_value(as))
            else
              As.new(var, as)
            end
          else
            glob << var
          end
          parser.gobble(/\p{Space}*,/)
        end
      end
      parser.gobble!(/\p{Space}*}/)
      xport.export(glob)
    else # 'const', 'let', 'var', 'function'
      parser.rewind(gob.length)
      xport.export(parser.statement)
    end
    xport
  end
  
end

class JSAnalyzer::Node::DestructureObject
  
  def initialize
    @parts = []
  end
  
  def add(var, default)
    @parts << [var, default]
  end
  
  def <<(v)
    @parts << v
  end
  
  def to_js
    js = String.new("{ ")
    js << @parts.map do |parts|
      puts parts.inspect
      parts[1] ? "#{parts[0].to_js}: #{parts[1].to_js}" : parts[0].to_js
    end.join(', ')
    js << " }"
  end
  
end


class JSAnalyzer::Node::DestructureArray
  def initialize
    @parts = []
  end
  
  def add(var, default)
    @parts << [var, default]
  end
  
  def <<(v)
    @parts << v
  end
  
  def to_js
    js = String.new("[ ")
    js << @parts.map do |parts|
      puts parts.inspect
      parts[1] ? "#{parts[0].to_js}: #{parts[1].to_js}" : parts[0].to_js
    end.join(', ')
    js << " ]"
  end
end


class JSAnalyzer::Node::ImportStatement
  
  class As
    attr_reader :var, :name

    def initialize(name, var)
      @var = var
      @name = name
    end
    
    def to_js
      "#{@name} as #{var.to_js}"
    end
  end
  
  class Default
    def initialize(as)
      @as = as
    end
    
    def to_js
      @as.to_js
    end
  end
  
  class Star
    def initialize(as)
      @as = as
    end
    
    def to_js
      "* as #{@as.to_js}"
    end
  end
  
  class Extract
    attr_reader :imports
    
    def initialize
      @imports = []
    end
    
    def to_js
      "{#{@imports.map(&:to_js).join(', ')}}"
    end
  end
  
  def initialize(imports: [], from:)
    @imports = imports
    @from = from
  end
  
  def to_js
    "import #{@imports.map(&:to_js).join(', ')} from #{@from.to_js}"
  end
  
  def self.parse(parser)
    mode = nil
    imports = []
    from = nil

    gobble = parser.gobble!(/\p{Space}*(\{|\}|'|"|\/|\*|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
    while gobble
      case gobble
      when "*"
        gob = parser.gobble!(/\p{Space}+as\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
        imports << Star.new(parser.scope.declare('import', gob))
      when "{"
        mode = :extract
        imports << Extract.new
      when "}"
        mode = nil
      when '"', "'"
        value = parser.quoted_value(gobble)
        if mode == :extract
          gob = parser.gobble!(/\p{Space}+as\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
          imports.last.imports << As.new(gobble, parser.scope.declare('import', gob))
        else
          from = JSAnalyzer::Node::String.new(value, gobble)
          break
        end
      when "/"
        parser.gobble!(/\*/)
        parser.scan_until(/\*\//)
      when "from"
        gob = parser.gobble!(/\p{Space}*(["'])/)[1]
        from = JSAnalyzer::Node::String.new(parser.quoted_value(gob), gob)
        break
      when JSAnalyzer::Parser::IDENTIFIER
        if mode == :extract
          imports.last.imports << if gob = parser.gobble(/\p{Space}+as\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)
            As.new(gobble, parser.scope.declare('import', gob[1]))
          else
            parser.scope.declare('import', gobble)
          end
        else
          imports << Default.new(parser.scope.declare('import', gobble))
        end
      end
      gobble = parser.gobble!(/(?:\p{Space}*,)?\p{Space}*(\{|\}|'|"|\/|\*|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
    end

    JSAnalyzer::Node::ImportStatement.new(imports: imports, from: from)
  end
end