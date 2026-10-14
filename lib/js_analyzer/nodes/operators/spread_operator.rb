class JSAnalyzer::Node::SpreadOperator < JSAnalyzer::Node::Operator

  attr_accessor :variable

  def initialize(variable=nil)
    @variable = variable
    @precedence = 2
  end

  def to_js(indentation="")
    @variable ? "...#{@variable.to_js}" : "..."
  end

end