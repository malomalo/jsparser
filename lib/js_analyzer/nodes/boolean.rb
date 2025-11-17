class JSAnalyzer::Node::Boolean

  attr_reader :value

  def initialize(value)
    @value = value
  end
  
  def to_js
    @value.to_s
  end
  
end
