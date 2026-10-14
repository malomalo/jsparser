class JSAnalyzer::Node::ForIn

  attr_accessor :left, :kind, :right, :body

  # kind is "in" or "of"
  def initialize(left, kind, right, body=[])
    @left = left
    @kind = kind
    @right = right
    @body = body
  end

  def to_js(indentation="")
    "for (#{@left.to_js} #{@kind} #{@right.to_js}) #{JSAnalyzer::Node.block_to_js(@body, indentation)}"
  end

end
