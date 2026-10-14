class JSAnalyzer::Node::DestructureObject

  def initialize(type=nil)
    @parts = []
    @type = type
  end

  # `var`, `var: value`, `var = default`, or `...var` when rest
  def add(var, value=nil, default: nil, rest: false)
    @parts << { var: var, value: value, default: default, rest: rest }
  end

  def to_js(indentation="")
    js = String.new
    js << @type << " " if @type
    js << "{ "
    js << @parts.map do |part|
      next "...#{part[:var].to_js}" if part[:rest]

      # With a value (`key: target`) the key is a property name, a String
      s = part[:var].is_a?(::String) ? part[:var].dup : part[:var].to_js
      s += ": #{part[:value].to_js}" if part[:value]
      s += " = #{part[:default].to_js}" if part[:default]
      s
    end.join(', ')
    js << " }"
  end

end
