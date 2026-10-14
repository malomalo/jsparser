class JSAnalyzer::Node::DestructureObject

  def initialize(type=nil)
    @parts = []
    @type = type
  end

  # `var`, `var: value`, `var = default`, or `...var` when rest. With a
  # value, var is the key: a property name (String), a String node for a
  # quoted key, or with computed, the expression in `[expr]: value`.
  def add(var, value=nil, default: nil, rest: false, computed: false)
    @parts << { var: var, value: value, default: default, rest: rest, computed: computed }
  end

  def to_js(indentation="")
    js = String.new
    js << @type << " " if @type
    js << "{ "
    js << @parts.map do |part|
      next "...#{part[:var].to_js}" if part[:rest]

      s = if part[:computed]
        "[#{part[:var].to_js}]"
      elsif part[:var].is_a?(::String) # a property name or number
        part[:var].dup
      else
        part[:var].to_js
      end
      s += ": #{part[:value].to_js}" if part[:value]
      s += " = #{part[:default].to_js}" if part[:default]
      s
    end.join(', ')
    js << " }"
  end

end
