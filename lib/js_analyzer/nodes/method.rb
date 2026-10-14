class JSAnalyzer::Node::Method

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
    @args.all?(JSAnalyzer::Node::VariableDeclaration)
  end

  # declare: where a function's name is declared, :outer for a function
  #          declaration, :inner for a function expression (where the name is
  #          only visible inside), or nil for methods and arrow functions
  def initialize(scope:, name: nil, async: false, generator: false, type: :function, args: [],
                 declare: nil, name_range: nil)
    @name = name
    @async = async
    @type = type
    @scope = JSAnalyzer::Node::Scope.new(scope: scope, kind: type == :arrow ? :arrow : :function)
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
      js << if !@name.is_a?(String)
        "[#{@name.to_js}]"
      else
        @name
      end
    end
    js << "(" << @args.map(&:to_js).join(', ') << ") "
    js << "=> " if @type == :arrow
    if @type == :arrow && @expression_body
      js << @body.first.to_js
    else
      js << "{"
      @body.each do |part|
        js << "\n#{indentation+'    '}#{part.to_js(indentation+'    ')};"
      end
      js << (@body.size == 0 ? " " : "\n#{indentation}")
      js << "}"
    end
    js
  end
end
