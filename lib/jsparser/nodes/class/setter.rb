class JSParser::Node::Class::Setter

  attr_reader :value

  def initialize(value=nil)
    @value = value
  end

  def to_js(indentation="")
    "set #{@value.to_js(indentation)}"
  end

end