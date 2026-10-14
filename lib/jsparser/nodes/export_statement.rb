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

  # The module re-exported from (`export ... from "module"`), or nil
  def source
    @from&.value
  end

  # Whether it's `export * from "module"`, which exports every name the
  # module does (they're not listed in exported_names)
  def star?
    @variables.empty?
  end

  # Whether it's the module's default export
  def default?
    exported_names.include?('default')
  end

  # The names exported: "default", the names in `export { ... }` (or their
  # `as` names), the name in `export * as name`, or the variables an
  # exported declaration declares
  def exported_names
    @variables.flat_map do |exported|
      case exported
      when Default then ['default']
      when As then [name_of(exported.name)]
      when Glob then exported.values.map { name_of(it.is_a?(As) ? it.name : it) }
      when JSParser::Node::VariableStatement then exported.declarations.map(&:name)
      when JSParser::Node::Method, JSParser::Node::Class then [exported.binding&.name].compact
      else []
      end
    end
  end

  # The exported declaration (a VariableStatement, function or class), or nil
  def declaration
    @variables.find do |exported|
      exported.is_a?(JSParser::Node::VariableStatement) || exported.is_a?(JSParser::Node::Method) || exported.is_a?(JSParser::Node::Class)
    end
  end

  # [keyword, object] for `with { type: "json" }`
  attr_writer :attributes
  
  def to_js(indentation="")
    js = "export #{@variables.empty? ? '*' : @variables.map(&:to_js).join(', ')}"
    js << " from #{@from.to_js}" if @from
    js << " #{@attributes[0]} #{@attributes[1].to_js}" if @attributes
    js
  end
  
  private

  def name_of(name)
    case name
    when ::String then name
    when JSParser::Node::String then name.value
    when JSParser::Node::VariableReference then name.text
    else name.to_js
    end
  end

  public

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
      xport.export(Default.new(parser.required(parser.statement)))
    elsif token.punctuator?('{')
      entries = [] # [name token, `as` name or nil]
      loop do
        break if parser.accept('}')
        name = parser.advance
        raise parser.syntax_error("expected a name", name) unless name.name? || name.type == :string
        as = (as_token = parser.accept_name('as') && parser.advance) &&
             (as_token.type == :string ? parser.string_node(as_token) : as_token.value)
        entries << [name, as]
        next if parser.accept(',')
        parser.expect('}')
        break
      end

      # In `export { a } from "m"` the names are the other module's, not
      # variables here
      re_export = parser.peek.name?('from')
      glob = Glob.new
      entries.each do |name, as|
        exported = if name.type == :string
          raise parser.syntax_error("a quoted name can only be re-exported", name) unless re_export
          parser.string_node(name)
        elsif re_export
          JSParser::Node::Identifier.new(name.value)
        else
          parser.scope.var(name.value, range: name.range)
        end
        glob << (as ? As.new(exported, as) : exported)
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

