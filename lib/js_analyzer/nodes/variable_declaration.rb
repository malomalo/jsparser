class JSAnalyzer::Node::VariableDeclaration
  
  attr_accessor :type, :vars

  def initialize(type, destructure: false)
    @type = type
    @vars = []
    @destructure = destructure
  end
  
  def add(name, init=nil)
    @vars << [name, init]
  end
  
  def to_js(indentation="", encapsulate: false)
    case @type
    when 'import', 'destructure', 'class', 'argument'
      indentation + @vars[0][0]
    else
      js = "#{indentation}#{@type} "
      js << @vars.map do |var|
        if var[1]
          varjs = "#{var[0]} = "
          varjs << "(" if encapsulate
          varjs << var[1].to_js
          varjs << ")" if encapsulate
          varjs
        else
          var[0]
        end
        
      end.join(', ')

      js
    end
  end
  
  def contains
    @vars.find { |v| v[1] ? yield(v[1]) : false }
  end
end