class JSAnalyzer::Node::BinaryOperator

  attr_accessor :left, :operation, :right

  def initialize(left:, operation:, right:, spacing: 2)
    @left = left
    @operation = operation
    @right = right
    @spacing = spacing
  end
  
  def to_js
    if spacing.nil? || spacing == 0
      "#{left.to_js}#{operation}#{right.to_js}"
    else
      "#{left.to_js} #{operation} #{right.to_js}"
    end
  end

end