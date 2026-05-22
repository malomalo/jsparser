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
    js = "#{indentation}if (#{condition.inspect}) {\n"
    body.each do |part|
      js << part.to_js(indentation + "    ") << "\n"
    end
    js << "#{indentation}}"
    @elses.each do |els|
      if els.is_a?(JSAnalyzer::Node::If)
        js << "#{indentation}else #{els.inspect}"
      else
        js << "#{indentation}else {\n"
        js << els.map(&:inspect).join("\n")
        js << "#{indentation}}"
      end
    end
    js
  end
end