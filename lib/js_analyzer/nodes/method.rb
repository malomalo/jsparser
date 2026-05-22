class JSAnalyzer::Node::Method

  attr_accessor :args, :body, :scope, :type, :async
  
  def initialize(scope:, name: nil, async: false, generator: false, type: :function, args: [])
    @name = name
    @async = async
    @type = type
    @variable = scope.declare("function", name) if name
    @scope = JSAnalyzer::Node::Scope.new(scope: scope)
    @args = Array(args)
    @body = []
    @generator = generator
  end
  
  def to_js(indentation="")
    js = String.new
    js << "async " if @async
    js << 'function ' if @type == :function
    js << "*" if @generator
    if @name
      js << if !@name.is_a?(String)
        "[#{@name.to_js}]"
      else
        @name
      end
    end
    js << "(" << @args.map(&:to_js).join(', ') << ") "
    js << "=> " if @type == :arrow
    # js << "{\n" if @type != :arrow || @body.size != 1
    if @type == :arrow && @body.size == 1
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
