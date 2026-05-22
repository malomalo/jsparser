class JSAnalyzer::Node::DestructureArray

  def initialize(type=nil)
    @parts = []
    @type = type
  end
  
  def add(var, default)
    @parts << [var, default]
  end
  
  def <<(v)
    @parts << v
  end
  
  def to_js
    js = String.new
    js << @type << " " if @type
    js << "[ "
    js << @parts.map do |parts|
      puts parts.inspect
      parts[1] ? "#{parts[0].to_js}: #{parts[1].to_js}" : parts[0].to_js
    end.join(', ')
    js << " ]"
  end
end


