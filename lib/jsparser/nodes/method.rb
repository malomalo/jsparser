class JSParser::Node::Method

  attr_accessor :args, :body, :scope, :type, :async

  # True for an arrow function whose body is an expression, not a `{ }` block
  attr_accessor :expression_body

  # The VariableDeclaration for a function's name, if it has one
  attr_reader :binding

  attr_writer :body_scope

  # The scope of the function's body. It's the same as `scope`, where the
  # parameters are declared, unless the parameters aren't simple (see
  # simple_parameters?).
  def body_scope
    @body_scope || @scope
  end

  # Whether every parameter is a plain name: no defaults, patterns or rest
  def simple_parameters?
    @args.all?(JSParser::Node::VariableDeclaration)
  end

  # declare: where a function's name is declared, :outer for a function
  #          declaration, :inner for a function expression (where the name is
  #          only visible inside), or nil for methods and arrow functions
  # computed: whether a name that isn't a String is a computed key
  # (`[expr]() {}`); false for a quoted key (`"a"() {}`)
  def initialize(scope:, name: nil, async: false, generator: false, type: :function, args: [],
                 declare: nil, name_range: nil, computed: nil)
    @name = name
    @computed = computed.nil? ? !name.is_a?(::String) : computed
    @async = async
    @type = type
    @scope = JSParser::Node::Scope.new(scope: scope, kind: type == :arrow ? :arrow : :function)
    if name && declare
      @binding = (declare == :outer ? scope : @scope).declare("function", name, range: name_range)
    end
    @args = Array(args)
    @body = []
    @generator = generator
  end
  
  def to_js(indentation="")
    js = String.new
    js << "async " if @async
    js << 'function ' if @type == :function
    js << "*" if @generator
    if @binding
      js << @binding.to_js
    elsif @name
      js << if @name.is_a?(String)
        @name
      elsif @computed
        "[#{@name.to_js}]"
      else
        @name.to_js
      end
    end
    js << "(" << @args.map(&:to_js).join(', ') << ") "
    js << "=> " if @type == :arrow
    if @type == :arrow && @expression_body
      js << @body.first.to_js
    else
      js << JSParser::Node.block_to_js(@body, indentation)
    end
    js
  end
end
