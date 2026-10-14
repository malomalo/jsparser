class JSAnalyzer::Node::Class
  
  autoload :Field, "js_analyzer/nodes/class/field"
  autoload :Getter, "js_analyzer/nodes/class/getter"
  autoload :Setter, "js_analyzer/nodes/class/setter"
  autoload :InitializationBlock, "js_analyzer/nodes/class/initialization_block"
  
  attr_reader :scope, :body
  
  # name is a [text, range] pair and extends the superclass expression. A
  # class declaration's name is declared in the enclosing scope; a class
  # expression's only inside it.
  def initialize(name: nil, extends: nil, scope:, expression: false)
    @extends = extends
    @scope = JSAnalyzer::Node::Scope.new(scope: scope, kind: :class)
    @name = (expression ? @scope : scope).declare('class', name[0], range: name[1]) if name
    @body = []
  end
  
  def to_js(indentation="")
    js = String.new("class ")
    js << "#{@name.to_js} " if @name
    js << "extends #{@extends.to_js} " if @extends
    js << "{" << JSAnalyzer::Node.statements_to_js(@body, indentation + "    ") << "\n#{indentation}}"
  end

end


