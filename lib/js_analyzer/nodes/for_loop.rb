class JSAnalyzer::Node::ForLoop

  attr_accessor :body

  def initialize(initialization=nil, condition=nil, afterthought=nil, body=[])
    @initialization = initialization
    @condition = condition
    @afterthought = afterthought
    @body = body
  end
  
  def to_js(indentation="")
    js = String.new("for (")
    if @initialization
      js << if @initialization.contains { it.is_a?(JSAnalyzer::Node::BinaryOperator) && it.operation == 'in' }
        byebug
        @initialization.to_js(encapsulate: true)
      else
        @initialization.to_js
      end
    end
    js << "; "
    js << @condition.to_js if @condition
    js << "; "
    js << @afterthought.to_js if @afterthought
    js << ") {"
    @body.each do |part|
      js << "\n#{indentation+'    '}#{part.to_js(indentation+'    ')};"
    end
    js << "\n#{indentation}}"
  end

end