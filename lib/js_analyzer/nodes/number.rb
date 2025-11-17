class JSAnalyzer::Node::Number
  
  attr_reader :value
  
  def initialize(value)
    @value = value
  end

  def to_js
    @value
  end
end