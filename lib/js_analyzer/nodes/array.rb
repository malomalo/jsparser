class JSAnalyzer::Node::Array
  
  attr_reader :members
  
  def initialize(members=[])
    @members = members
  end

  def to_js(indentation="")
    "[#{@members.map(&:to_js).join(", ")}]"
  end

end