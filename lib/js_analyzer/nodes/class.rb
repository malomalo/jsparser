class JSAnalyzer::Node::ClassStatement
  attr_reader :scope, :body
  
  def initialize(name: nil, extends: nil, scope:)
    @name = scope.declare('class', name) if name
    @extends = scope.var(extends) if extends
    @scope = JSAnalyzer::Node::Scope.new(scope: scope)
    @body = []
  end
  
  def to_js
    js = String.new("class ")
    js << "#{@name.to_js} " if @name
    js << "extends #{@extends.to_js} " if @extends
    js << "{\n"
    js << @body.map(&:inspect).join("\n")
    js << "}"
  end

end