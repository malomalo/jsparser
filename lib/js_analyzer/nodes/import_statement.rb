class JSAnalyzer::Node::ImportStatement
  
  class As
    attr_reader :var, :name

    def initialize(name, var)
      @var = var
      @name = name
    end
    
    def to_js(indentation="")
      if @name.is_a?(String)
        "#{@name} as #{var.to_js}"
      else
        "#{@name.to_js} as #{var.to_js}"
      end

    end
  end
  
  class Default
    def initialize(as)
      @as = as
    end
    
    def to_js(indentation="")
      @as.to_js
    end
  end
  
  class Star
    def initialize(as)
      @as = as
    end
    
    def to_js(indentation="")
      "* as #{@as.to_js}"
    end
  end
  
  class Extract
    attr_reader :imports
    
    def initialize
      @imports = []
    end
    
    def to_js(indentation="")
      "{ #{@imports.map(&:to_js).join(', ')} }"
    end
  end
  
  # attributes is [keyword, object] for `with { type: "json" }`
  def initialize(imports: [], from:, attributes: nil)
    @imports = imports
    @from = from
    @attributes = attributes
  end
  
  def to_js(indentation="")
    js = "import #{@imports.map(&:to_js).join(', ')}"
    js << ' from ' if @imports.size > 0
    js << @from.to_js
    js << " #{@attributes[0]} #{@attributes[1].to_js}" if @attributes
    js
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
        value = JSAnalyzer::Node::String.new(parser.quoted_value(gobble), gobble)
        if mode == :extract
          gob = parser.gobble!(/\p{Space}+as\p{Space}+(#{JSAnalyzer::Parser::IDENTIFIER})/)[1]
          imports.last.imports << As.new(value, parser.scope.declare('import', gob))
        else
          from = value
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

    JSAnalyzer::Node::ImportStatement.new(imports: imports, from: from, attributes: parser.parse_import_attributes)
  end
end