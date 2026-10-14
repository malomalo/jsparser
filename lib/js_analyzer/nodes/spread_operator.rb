# `...value`, as a spread in calls, arrays and objects or a rest element
class JSAnalyzer::Node::SpreadOperator

  attr_accessor :variable

  def initialize(variable=nil)
    @variable = variable
  end

  def to_js(indentation="")
    @variable ? "...#{@variable.to_js}" : "..."
  end

end