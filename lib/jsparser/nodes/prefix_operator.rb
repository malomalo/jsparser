class JSParser::Node::PrefixOperator

  WORD_OPERATORS = %w(delete typeof void await)

  attr_accessor :operation, :operand

  def initialize(operation, operand)
    @operation = operation
    @operand = operand
  end

  def to_js(indentation="")
    separator = WORD_OPERATORS.include?(@operation) ? " " : ""
    "#{@operation}#{separator}#{@operand.to_js}"
  end

end
