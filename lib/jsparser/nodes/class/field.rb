class JSParser::Node::Class::Field

  attr_accessor :value, :static

  def initialize(value = nil, assignment = nil, static: false)
    @value = value
    @static = static
    @assignment = assignment
  end

  def to_js(indentation="")
    js = String.new
    js << "static " if @static
    js << case @value
    when String
      @value
    when JSParser::Node::Method, JSParser::Node::Class::Getter, JSParser::Node::Class::Setter, JSParser::Node::Class::InitializationBlock
      @value.to_js(indentation)
    else
      "[#{@value.to_js}]"
    end
    js << " = " << @assignment.to_js(indentation) if @assignment
    js
  end

end