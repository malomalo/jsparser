class JSAnalyzer::Node::Yield

  def initialize(value)
    @value = value
  end
  
  def to_js(indentation="")
    "yield #{@value.to_js}"
  end

end