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
      @vars[0][0]
    else
      js = "#{@type} "
      js << @vars.map do |var|
        # The target is a name or a destructuring pattern
        target = var[0].is_a?(::String) ? var[0] : var[0].to_js
        if var[1]
          varjs = "#{target} = "
          varjs << "(" if encapsulate
          varjs << var[1].to_js
          varjs << ")" if encapsulate
          varjs
        else
          target
        end

      end.join(', ')

      js
    end
  end
  
  def contains
    @vars.find { |v| v[1] ? yield(v[1]) : false }
  end
end