class JSParser::Node::ForLoop

  attr_accessor :body

  def initialize(initialization=nil, condition=nil, afterthought=nil, body=[])
    @initialization = initialization
    @condition = condition
    @afterthought = afterthought
    @body = body
  end
  
  def to_js(indentation="")
    clauses = [@initialization, @condition, @afterthought]
    header = if clauses.none?
      ";;"
    else
      clauses.map { it ? it.to_js : "" }.join("; ")
    end

    "for (#{header}) #{JSParser::Node.block_to_js(@body, indentation)}"
  end

end