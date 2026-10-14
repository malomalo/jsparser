# The name of a variable. A VariableDeclaration and all of its
# VariableReferences share one Identifier, so changing `name` here renames
# the variable everywhere it's printed.
class JSAnalyzer::Node::Identifier

  attr_accessor :name

  def initialize(name)
    @name = name
  end

  def to_js(indentation="")
    @name.dup
  end

  def to_s
    @name
  end

end
