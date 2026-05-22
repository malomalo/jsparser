class JSAnalyzer::Node::Ternary

  def initialize(condition, a, b)
    @condition = condition
    @a = a
    @b = b
  end

  def to_js(indentation="")
    "#{@condition.to_js} ? #{@a.to_js} : #{@b.to_js}"
  end
end
