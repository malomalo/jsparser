class JSAnalyzer::Node::VariableDeclaration
  
  attr_accessor :initialization, :name

  def initialize(type)
    @type = type
    @vars = []
  end
  
  def add(name, init=nil)
    @vars << [name, init]
  end
  
  def to_js
    case @type
    when 'import', 'destructure', 'class'
      @vars[0][0]
    else
      js = "#{@type} "
      js << @vars.map do |var|
        var[1] ? "#{var[0]} = #{var[1].to_js}" : var[0]
      end.join(', ')
      js
    end
  end
  
end