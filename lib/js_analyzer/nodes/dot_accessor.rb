class JSAnalyzer::Node::DotAccessor
  def initialize(object:, key:, optional_chaining: false)
    @object = object
    @key = key
    @optional_chaining = optional_chaining
  end
  
  def to_js(indentation="")
    js = @object.to_js
    js << (@optional_chaining ? "?." : ".")
    js << (@key.is_a?(String) ? @key : "[#{@key.to_js}]")
  end
end