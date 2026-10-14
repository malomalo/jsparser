class JSParser::Node::DestructureArray

  def initialize(type=nil)
    @parts = []
    @type = type
  end

  # `var`, `var = default`, or `...var` when rest
  def add(var, default=nil, rest: false)
    @parts << { var: var, default: default, rest: rest }
  end

  # An empty slot, as in [, a]
  def hole
    @parts << nil
  end

  def to_js(indentation="")
    js = String.new
    js << @type << " " if @type
    js << "[ "
    js << @parts.map do |part|
      if part.nil?
        ""
      elsif part[:rest]
        "...#{part[:var].to_js}"
      elsif part[:default]
        "#{part[:var].to_js} = #{part[:default].to_js}"
      else
        part[:var].to_js
      end
    end.join(', ')
    js << " ]"
  end
end
