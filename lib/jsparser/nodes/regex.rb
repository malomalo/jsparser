class JSParser::Node::Regex
  def initialize(value, options)
    @value = value
    @options = options
  end
  
  def to_js(indentation="")
    "/#{@value}/#@options"
  end
end