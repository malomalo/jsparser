class JSAnalyzer::Node::If
  attr_accessor :condition, :body, :elses
  
  def initialize(condition, body)
    @condition = condition
    @body = body
    @elses = []
  end

  def else_if(condition, body)
    @elses << JSAnalyzer::Node::If.new(condition, body)
  end
    
  def else(body)
    @elses << body
  end
    
  def to_js
    js = "if (#{condition.inspect}) {"
    js << body.map(&:inspect).join("\n")
    js << "\n}"
    @elses.each do |els|
      if els.is_a?(JSAnalyzer::Node::If)
        js << "else #{els.inspect}"
      else
        js << "else {\n"
        js << els.map(&:inspect).join("\n")
        js << "}"
      end
    end
    js
  end
end