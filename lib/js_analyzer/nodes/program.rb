class JSAnalyzer::Node::Program < JSAnalyzer::Node::Scope

  def initialize(...)
    super
    @globals = {}
  end
  
  def to_js
    js = String.new
    @statements.each do |statment|
      js << statment.to_js << ";\n"
    end
    js
  end

end