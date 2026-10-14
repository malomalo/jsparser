class JSParser::Node::ReturnStatement

  attr_reader :value

  def initialize(value)
    @value = value
  end
  
  def to_js(indentation="")
    @value ? "return #{@value.to_js}" : "return"
  end

end
