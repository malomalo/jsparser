class JSAnalyzer::Node::UnaryOperator

  attr_accessor :left, :operation, :right

  def initialize(on, operation, side: :right)
    @on = on
    @operation = operation
    @side = side
  end

  def to_js
    js = String.new
    js << @operation if @side == :left
    js << @on.to_js
    js << @operation if @side == :right
    js
  end
end