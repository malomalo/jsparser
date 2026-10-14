# `break` and `continue`, with an optional label
class JSParser::Node::JumpStatement

  attr_accessor :keyword, :label

  def initialize(keyword, label=nil)
    @keyword = keyword
    @label = label
  end

  def to_js(indentation="")
    @label ? "#{@keyword} #{@label}" : @keyword
  end

end
