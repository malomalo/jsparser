class JSParser::Node::Class
  
  autoload :Field, "jsparser/nodes/class/field"
  autoload :Getter, "jsparser/nodes/class/getter"
  autoload :Setter, "jsparser/nodes/class/setter"
  autoload :InitializationBlock, "jsparser/nodes/class/initialization_block"
  
  attr_reader :scope, :body
  
  # name is a [text, range] pair and extends the superclass expression. A
  # class declaration's name is declared in the enclosing scope; a class
  # expression's only inside it.
  def initialize(name: nil, extends: nil, scope:, expression: false)
    @extends = extends
    @scope = JSParser::Node::Scope.new(scope: scope, kind: :class)
    @name = (expression ? @scope : scope).declare('class', name[0], range: name[1]) if name
    @body = []
  end
  
  def to_js(indentation="")
    js = String.new("class ")
    js << "#{@name.to_js} " if @name
    js << "extends #{@extends.to_js} " if @extends
    js << "{" << JSParser::Node.statements_to_js(@body, indentation + "    ") << "\n#{indentation}}"
  end

end


