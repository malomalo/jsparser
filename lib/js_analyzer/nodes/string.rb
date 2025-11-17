class JSAnalyzer::Node::String

  def initialize(value, quotes='"')
    @value = value
    @quote = quotes
  end

  def to_js
    "#{@quote}#{@value}#{@quote}"
  end
end