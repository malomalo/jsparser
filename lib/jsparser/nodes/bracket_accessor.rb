# `object[key]`, or with optional_chaining `object?.[key]`
class JSParser::Node::BracketAccessor

  attr_reader :object, :key

  def initialize(object, key, optional_chaining: false)
    @object = object
    @key = key
    @optional_chaining = optional_chaining
  end

  def optional_chaining?
    @optional_chaining
  end

  def to_js(indentation="")
    "#{@object.to_js}#{'?.' if @optional_chaining}[#{@key.to_js}]"
  end
end
