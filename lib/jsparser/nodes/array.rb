class JSParser::Node::Array
  
  attr_reader :members
  
  def initialize(members=[])
    @members = members
  end

  def to_js(indentation="")
    js = @members.map { it ? it.to_js : "" }.join(", ")
    # A trailing hole needs its comma, [1, ,] has two elements
    js << "," if @members.last.nil? && !@members.empty?
    "[#{js}]"
  end

end