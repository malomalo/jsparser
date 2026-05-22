class JSAnalyzer::Node::Instantiation
  attr_accessor :args
  def initialize(fn, args=[])
    @fn = fn
    @args = args
  end
  
  def to_js(indentation="")
    "new #{@fn.to_js}(#{@args.map(&:to_js).join(', ')})"
  end
end