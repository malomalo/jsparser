class JSAnalyzer::Node::BracketAccessor
  def initialize(object, key)
    @object = object
    @key = key
  end
  
  def to_js(indentation="")
    "#{@object.to_js}[#{@key.to_js}]"
  end
end
