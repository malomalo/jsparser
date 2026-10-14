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
    
  def to_js(indentation="")
    js = "if (#{condition.to_js}) #{JSAnalyzer::Node.block_to_js(body, indentation)}"
    @elses.each do |els|
      js << " else "
      js << if els.is_a?(JSAnalyzer::Node::If)
        els.to_js(indentation)
      else
        JSAnalyzer::Node.block_to_js(els, indentation)
      end
    end
    js
  end
end