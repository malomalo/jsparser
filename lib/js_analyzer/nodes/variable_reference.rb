class JSAnalyzer::Node::VariableReference
  
  def initialize(name, scope)
    @scope = scope
    @name = name
  end
  
  def to_js(indentation="")
    @name.dup
  end
  
end
