# `break` and `continue`, with an optional label
class JSAnalyzer::Node::JumpStatement

  attr_accessor :keyword, :label

  def initialize(keyword, label=nil)
    @keyword = keyword
    @label = label
  end

  def to_js(indentation="")
    @label ? "#{@keyword} #{@label}" : @keyword
  end

end
