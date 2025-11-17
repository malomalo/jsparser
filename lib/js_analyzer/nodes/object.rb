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

  attr_reader :entries
  
  def initialize
    @entries = []
  end
  
  def add(key, value)
    puts 'ADD ' + key.inspect
    @entries << JSAnalyzer::Node::Object::Entry.new(key, value)
  end
  
  def spread(variable)
    @entries << JSAnalyzer::Node::SpreadEntry.new(variable)
  end
  
  def shorthand(variable)
    @entries << JSAnalyzer::Node::Object::ShorthandEntry.new(variable)
  end
  
  def to_js
    js = String.new("{")
    js << @entries.map do |entry|
      case entry
      when JSAnalyzer::Node::SpreadEntry
        "...#{entry.variable.to_js}"
      when ShorthandEntry
        entry.key.to_js
      when Entry
        case entry.key
        when String
          "#{entry.key}: #{entry.value.to_js}"
        else
        puts entry.value.inspect
          "[#{entry.key.to_js}]: #{entry.value.to_js}"
        end
      else
        entry.to_js
      end
    end.join(", ")
    js << "}"
  end
  
end
