# `object.key`, or with optional_chaining `object?.key`. key is the property
# name, a String (`#name` for a private member).
class JSAnalyzer::Node::DotAccessor

  attr_reader :object, :key

  def initialize(object:, key:, optional_chaining: false)
    @object = object
    @key = key
    @optional_chaining = optional_chaining
  end

  def optional_chaining?
    @optional_chaining
  end

  def to_js(indentation="")
    "#{@object.to_js}#{@optional_chaining ? '?.' : '.'}#{@key}"
  end
end
