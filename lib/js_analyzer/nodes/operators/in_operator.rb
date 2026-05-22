class JSAnalyzer::Node::InOperator < JSAnalyzer::Node::Operator

  def initialize(key, object)
    @key = key
    @object = object
    @precedence = 9
  end

  def to_js(indentation="")
    "#{@key.to_js} in #{@object.to_js}"
  end

end