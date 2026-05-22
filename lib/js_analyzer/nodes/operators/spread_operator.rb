class JSAnalyzer::Node::SpreadOperator < JSAnalyzer::Node::Operator

  def initialize(variable=nil)
    @variable = variable
    @precedence = 2
  end

  def to_js
    @variable ? "...#{@variable.to_js}" : "..."
  end

end