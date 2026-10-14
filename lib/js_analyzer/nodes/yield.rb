class JSAnalyzer::Node::Yield

  # delegate is true for `yield* iterable`
  def initialize(value, delegate: false)
    @value = value
    @delegate = delegate
  end
  
  def to_js(indentation="")
    keyword = @delegate ? "yield*" : "yield"
    @value ? "#{keyword} #{@value.to_js}" : keyword
  end

end