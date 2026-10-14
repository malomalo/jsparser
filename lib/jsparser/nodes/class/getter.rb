class JSParser::Node::Class::Getter

  attr_reader :value

  def initialize(value=nil)
    @value = value
  end

  def to_js(indentation="")
    "get #{@value.to_js(indentation)}"
  end

end
