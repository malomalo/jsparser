class JSAnalyzer::Node::UnaryOperator

  attr_accessor :left, :operation, :right

  def initialize(left: nil, operation:, right: nil)
    @left = left
    @operation = operation
    @right = right
  end

end