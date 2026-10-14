# Statement nodes: blocks, loops, try, switch, throw and labels

class JSAnalyzer::Node::Block

  attr_accessor :statements, :scope

  def initialize(statements=[])
    @statements = statements
  end

  def to_js(indentation="")
    JSAnalyzer::Node.block_to_js(@statements, indentation)
  end

end

class JSAnalyzer::Node::While

  attr_accessor :condition, :body

  def initialize(condition, body=[])
    @condition = condition
    @body = body
  end

  def to_js(indentation="")
    "while (#{@condition.to_js}) #{JSAnalyzer::Node.block_to_js(@body, indentation)}"
  end

end

class JSAnalyzer::Node::DoWhile

  attr_accessor :body, :condition

  def initialize(body, condition)
    @body = body
    @condition = condition
  end

  def to_js(indentation="")
    "do #{JSAnalyzer::Node.block_to_js(@body, indentation)} while (#{@condition.to_js})"
  end

end

class JSAnalyzer::Node::Try

  attr_accessor :block, :param, :handler, :finalizer

  def initialize(block)
    @block = block
  end

  def to_js(indentation="")
    js = "try #{JSAnalyzer::Node.block_to_js(@block, indentation)}"
    if @handler
      js << " catch"
      js << " (#{@param.to_js})" if @param
      js << " " << JSAnalyzer::Node.block_to_js(@handler, indentation)
    end
    js << " finally #{JSAnalyzer::Node.block_to_js(@finalizer, indentation)}" if @finalizer
    js
  end

end

class JSAnalyzer::Node::Switch

  # cases is a list of [test, statements]; test is nil for `default`
  attr_accessor :discriminant, :cases

  def initialize(discriminant)
    @discriminant = discriminant
    @cases = []
  end

  def to_js(indentation="")
    js = "switch (#{@discriminant.to_js}) {"
    @cases.each do |test, statements|
      js << "\n#{indentation}    " << (test ? "case #{test.to_js}:" : "default:")
      js << JSAnalyzer::Node.statements_to_js(statements, indentation + '        ')
    end
    js << "\n#{indentation}}"
  end

end

class JSAnalyzer::Node::ThrowStatement

  attr_reader :value

  def initialize(value)
    @value = value
  end

  def to_js(indentation="")
    "throw #{@value.to_js}"
  end

end

class JSAnalyzer::Node::LabeledStatement

  attr_reader :label, :body

  def initialize(label, body)
    @label = label
    @body = body
  end

  def to_js(indentation="")
    "#{@label}: #{@body&.to_js(indentation)}"
  end

end

class JSAnalyzer::Node::With

  attr_reader :object, :body

  def initialize(object, body=[])
    @object = object
    @body = body
  end

  def to_js(indentation="")
    "with (#{@object.to_js}) #{JSAnalyzer::Node.block_to_js(@body, indentation)}"
  end

end

class JSAnalyzer::Node::DebuggerStatement

  def to_js(indentation="")
    "debugger"
  end

end

# new.target (import.meta is parsed as a member access on import)
class JSAnalyzer::Node::MetaProperty

  attr_reader :meta, :property

  def initialize(meta, property)
    @meta = meta
    @property = property
  end

  def to_js(indentation="")
    "#{@meta}.#{@property}"
  end

end
