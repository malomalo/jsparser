class JSParser::Node::ImportStatement
  
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
    attr_reader :as

    def initialize(as)
      @as = as
    end
    
    def to_js(indentation="")
      @as.to_js
    end
  end
  
  class Star
    attr_reader :as

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
  
  # One imported binding: `imported` is the name in the other module
  # ("default", "*" for `* as ns`, or the name, which may be a quoted
  # string), and `local` the VariableDeclaration it's bound to here
  Specifier = Struct.new(:imported, :local)

  # attributes is [keyword, object] for `with { type: "json" }`
  def initialize(imports: [], from:, attributes: nil)
    @imports = imports
    @from = from
    @attributes = attributes
  end
  
  # The module imported, as written between the quotes
  def source
    @from.value
  end

  # The names imported (empty for `import "module"`)
  def specifiers
    @imports.flat_map do |import|
      case import
      when Default then [Specifier.new('default', import.as)]
      when Star then [Specifier.new('*', import.as)]
      when Extract
        import.imports.map do |entry|
          if entry.is_a?(As)
            Specifier.new(entry.name.is_a?(::String) ? entry.name : entry.name.value, entry.var)
          else
            Specifier.new(entry.text, entry)
          end
        end
      end
    end
  end

  def to_js(indentation="")
    js = "import #{@imports.map(&:to_js).join(', ')}"
    js << ' from ' if @imports.size > 0
    js << @from.to_js
    js << " #{@attributes[0]} #{@attributes[1].to_js}" if @attributes
    js
  end
  
  # After `import`
  def self.parse(parser)
    imports = []
    from = nil

    # Declares an imported name
    bind = ->(token) { parser.scope.declare('import', token.value, range: token.range) }

    if parser.peek.type == :string
      from = parser.expect_string # import "module"
    else
      imports << Default.new(bind.(parser.advance)) if parser.peek.name? && !parser.peek.name?('from')

      if imports.empty? || parser.accept(',')
        if parser.accept('*')
          parser.expect_name('as')
          imports << Star.new(bind.(parser.expect_name))
        elsif parser.accept('{')
          extract = Extract.new
          loop do
            break if parser.accept('}')
            name = parser.advance
            imported = name.type == :string ? parser.string_node(name) : name.value
            extract.imports << if parser.accept_name('as')
              As.new(imported, bind.(parser.expect_name))
            else
              bind.(name)
            end
            next if parser.accept(',')
            parser.expect('}')
            break
          end
          imports << extract
        end
      end

      parser.expect_name('from')
      from = parser.expect_string
    end

    node = JSParser::Node::ImportStatement.new(imports: imports, from: from, attributes: parser.parse_import_attributes)
    parser.accept(';')
    node
  end
end
