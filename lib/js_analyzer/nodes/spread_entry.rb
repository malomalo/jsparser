class JSAnalyzer::Node::SpreadEntry

  attr_reader :variable

  def initialize(variable=nil)
    @variable = variable
  end

  def to_js
    @variable ? "...#{@variable.to_js}" : "..."
  end

end