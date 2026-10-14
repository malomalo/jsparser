class JSParser::Node::ExportStatement

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
  
  # After `export`
  def self.parse(parser)
    xport = JSParser::Node::ExportStatement.new
    token = parser.advance

    if token.punctuator?('*')
      if parser.accept_name('as')
        as = parser.advance
        xport.export_as(nil, as.type == :string ? parser.string_node(as) : as.value)
      end
    elsif token.name?('default')
      xport.export(Default.new(parser.statement))
    elsif token.punctuator?('{')
      glob = Glob.new
      loop do
        break if parser.accept('}')
        name = parser.expect_name
        var = parser.scope.var(name.value, range: name.range)
        glob << if parser.accept_name('as')
          as = parser.advance
          As.new(var, as.type == :string ? parser.string_node(as) : as.value)
        else
          var
        end
        next if parser.accept(',')
        parser.expect('}')
        break
      end
      xport.export(glob)
    else # const, let, var, function, class
      parser.unread(token)
      xport.export(parser.statement(top: true))
    end

    if parser.accept_name('from')
      xport.from(parser.expect_string)
      xport.attributes = parser.parse_import_attributes
    end
    parser.accept(';')
    xport
  end

end

