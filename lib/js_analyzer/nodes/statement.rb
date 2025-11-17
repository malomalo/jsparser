class JSAnalyzer::Node::Statement

  def <<(value)
    @value = case @value
    when nil
      value
    else
      raise "Statement error add #{value.inspect} to #{@value.inspect}"
    end
  end

end