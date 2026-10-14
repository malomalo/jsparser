class JSAnalyzer::Node::Yield

  def initialize(value)
    @value = value
  end
  
  def to_js(indentation="")
    @value ? "yield #{@value.to_js}" : "yield"
  end

end