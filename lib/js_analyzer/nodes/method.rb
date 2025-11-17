class JSAnalyzer::Node::Method

  attr_accessor :args, :body, :scope
  
  def initialize(name: nil, async:, scope:, generator: false)
    @variable = scope.declare("function", name) if name
    @name = name
    @scope = JSAnalyzer::Node::Scope.new(scope: scope)
    @args = []
    @body = []
    @generator = generator
  end
  
  def to_js
    js = @variable ? "#{@name}#{@generator ? '*' : ''} (" : String.new("(")
    js << @args.map { |a| a.name }.join(', ')
    js << ") {"
    js << @body.map(&:inspect).join('; ')
    js << "}"
  end
end
