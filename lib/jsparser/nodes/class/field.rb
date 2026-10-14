class JSParser::Node::Class::Field

  attr_accessor :value, :static

  # value is a method, accessor or static block, or a field's name: a
  # String, a String node for a quoted name, or with computed, the
  # expression in `[expr]`
  def initialize(value = nil, assignment = nil, static: false, computed: false)
    @value = value
    @static = static
    @assignment = assignment
    @computed = computed
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
      @computed ? "[#{@value.to_js}]" : @value.to_js
    end
    js << " = " << @assignment.to_js(indentation) if @assignment
    js
  end

end