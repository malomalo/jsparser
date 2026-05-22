class JSAnalyzer::Node::ReturnStatement

  attr_reader :value

  def initialize(value)
    @value = value
  end
  
  def to_js(indentation="")
    "return #{@value.to_js}"
  end

end
