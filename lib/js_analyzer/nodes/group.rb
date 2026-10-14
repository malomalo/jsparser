class JSAnalyzer::Node::Group

  attr_accessor :expressions

  def initialize(expressions)
    @expressions = expressions
  end

  def to_js(indentation="")
    "(#{@expressions.map(&:to_js).join(', ')})"
  end

end
