class JSAnalyzer::Node::ExportStatement

  class As
    attr_reader :var, :name

    def initialize(var, name)
      @var = var
      @name = name
    end
    
    def to_js(indentation="")
      "#{indentation}#{@var ? @var.to_js : '*'} as #{@name.is_a?(String) ? @name : @name.to_js}"
    end
  end
  
  class Default
    attr_reader :value
    
    def initialize(value)
      @value = value
    end
    
    def to_js(indentation="")
      "#{indentation}default #{@value.to_js}"
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
    
    def to_js(indentation="")
      "{ #{@values.map(&:to_js).join(', ')} }"
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
  
  def from(file)
    @from = file
  end

  # [keyword, object] for `with { type: "json" }`
  attr_writer :attributes
  
  def to_js(indentation="")
    js = "export #{@variables.empty? ? '*' : @variables.map(&:to_js).join(', ')}"
    js << " from #{@from.to_js}" if @from
    js << " #{@attributes[0]} #{@attributes[1].to_js}" if @attributes
    js
  end
  
  def self.parse(parser)
    xport = JSAnalyzer::Node::ExportStatement.new
    gob = parser.gobble!(/\p{Space}*(\{|\*|default|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
    
    case gob
    when '*'
      if parser.gobble(/\p{Space}+as/)
        as = parser.gobble!(/\p{Space}+(\'|\"|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
        if as == "'" || as == '"'
          xport.export_as(nil, parser.quoted_value(as))
        else
          xport.export_as(nil, as)
        end
      end
    when 'default'
      xport.export(Default.new(parser.statement))
    when '{'
      glob = Glob.new
      while (m = parser.gobble(/\p{Space}*(\/\*|\/\/|#{JSAnalyzer::Parser::IDENTIFIER})/)) && (var_name = m[1])
        case var_name
        when "/*"
          parser.scan_until(/\*\//)
        when "//"
          parser.scan_until_eol
        else
          var = parser.scope.var(var_name, range: parser.group_range(m))
          if parser.gobble(/\p{Space}+as/)
            as = parser.gobble!(/\p{Space}+(\'|\"|#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
            glob << if as == "'" || as == '"'
              As.new(var, JSAnalyzer::Node::String.new(parser.quoted_value(as), as))
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

    if parser.gobble(/\p{Space}+from/)
      xport.from(parser.statement)
      xport.attributes = parser.parse_import_attributes
    end
    
    xport
  end
  
end

