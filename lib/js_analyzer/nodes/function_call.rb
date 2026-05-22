class JSAnalyzer::Node::FunctionCall
  
  attr_accessor :args
  
  def initialize(fn, args=[], optional_chaining: false)
    @fn = fn
    @args = args
    @optional_chaining = optional_chaining
  end
  
  def to_js(indentation="")
    js = @fn.to_js(indentation)
    js << (@optional_chaining ? "?.(" : "(")
    js << @args.map(&:to_js).join(', ')
    js << ")"
  end
end