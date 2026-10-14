class JSAnalyzer::Node::Class
  
  autoload :Field, "js_analyzer/nodes/class/field"
  autoload :Getter, "js_analyzer/nodes/class/getter"
  autoload :Setter, "js_analyzer/nodes/class/setter"
  autoload :InitializationBlock, "js_analyzer/nodes/class/initialization_block"
  
  attr_reader :scope, :body
  
  def initialize(name: nil, extends: nil, scope:)
    @name = scope.declare('class', name) if name
    @extends = scope.var(extends) if extends
    @scope = JSAnalyzer::Node::Scope.new(scope: scope)
    @body = []
  end
  
  def to_js(indentation="")
    js = String.new("class ")
    js << "#{@name.to_js} " if @name
    js << "extends #{@extends.to_js} " if @extends
    js << "{\n"
    @body.each do |part|
      js << indentation << "    " << part.to_js(indentation + "    ") << ";\n"
    end
    js << "#{indentation}}"
  end

end


