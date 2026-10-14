class JSParser::Node::Object

  class Entry
    attr_reader :key
    attr_accessor :value
    def initialize(key, value)
      @key = key
      @value = value
    end
  end
  
  class ShorthandEntry
    attr_accessor :key
    def initialize(key)
      @key = key
    end
  end

  # `key = value` in a destructuring pattern
  class DefaultEntry
    attr_accessor :key
    attr_reader :value
    def initialize(key, value)
      @key = key
      @value = value
    end
  end

  attr_reader :entries

  def initialize
    @entries = []
  end
  
  def add(key, value)
    @entries << JSParser::Node::Object::Entry.new(key, value)
  end
  
  def spread(variable)
    @entries << JSParser::Node::SpreadOperator.new(variable)
  end
  
  def add_default(key, value)
    @entries << JSParser::Node::Object::DefaultEntry.new(key, value)
  end

  def shorthand(variable)
    @entries << JSParser::Node::Object::ShorthandEntry.new(variable)
  end
  
  def to_js(indentation="")
    js = String.new("{")
    js << @entries.map do |entry|
      case entry
      # when JSParser::Node::SpreadOperator
      #   "...#{entry.variable.to_js}"
      when ShorthandEntry
        entry.key.to_js
      when DefaultEntry
        "#{entry.key.to_js} = #{entry.value.to_js}"
      when Entry
        case entry.key
        when String
          "#{entry.key}: #{entry.value.to_js}"
        when JSParser::Node::String
          "#{entry.key.to_js}: #{entry.value.to_js}"
        else
          "[#{entry.key.to_js}]: #{entry.value.to_js}"
        end
      else
        entry.to_js
      end
    end.join(", ")
    js << "}"
  end
  
end
