class JSParser::Node::String

  # value is the text between the quotes, as written (escapes included)
  attr_reader :value, :quote

  def initialize(value, quotes='"')
    @value = value
    @quote = quotes
  end

  def to_js(indentation="")
    "#{@quote}#{@value}#{@quote}"
  end
end

class JSParser::Node::InterpolatedString

  def initialize(parts=[])
    @parts = parts
  end

  def <<(part)
    @parts << part
  end
  
  def to_js(indentation="")
    js = String.new('`')
    @parts.each do |part|
      if part.is_a?(String)
        js << part
      else
        js << "${" << part.to_js << "}"
      end
    end
    js << '`'
  end
end