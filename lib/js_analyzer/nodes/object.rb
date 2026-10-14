class JSAnalyzer::Node::Object

  class Entry
    attr_reader :key, :value
    def initialize(key, value)
      @key = key
      @value = value
    end
  end
  
  class ShorthandEntry
    attr_reader :key
    def initialize(key)
      @key = key
    end
  end

  # `key = value` in a destructuring pattern
  class DefaultEntry
    attr_reader :key, :value
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
    @entries << JSAnalyzer::Node::Object::Entry.new(key, value)
  end
  
  def spread(variable)
    @entries << JSAnalyzer::Node::SpreadOperator.new(variable)
  end
  
  def add_default(key, value)
    @entries << JSAnalyzer::Node::Object::DefaultEntry.new(key, value)
  end

  def shorthand(variable)
    @entries << JSAnalyzer::Node::Object::ShorthandEntry.new(variable)
  end
  
  def to_js(indentation="")
    js = String.new("{")
    js << @entries.map do |entry|
      case entry
      # when JSAnalyzer::Node::SpreadOperator
      #   "...#{entry.variable.to_js}"
      when ShorthandEntry
        entry.key.to_js
      when DefaultEntry
        "#{entry.key.to_js} = #{entry.value.to_js}"
      when Entry
        case entry.key
        when String
          "#{entry.key}: #{entry.value.to_js}"
        when JSAnalyzer::Node::String
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
