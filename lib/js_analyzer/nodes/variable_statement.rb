# A `var`, `let` or `const` statement, e.g. `let a = 1, { b } = c`.
#
#   kind         "var", "let" or "const"
#   declarators  [target, init] pairs, where target is a VariableDeclaration
#                or a destructuring pattern, and init may be nil
class JSAnalyzer::Node::VariableStatement

  attr_reader :kind, :declarators

  def initialize(kind)
    @kind = kind
    @declarators = []
  end

  def add(target, init = nil)
    @declarators << [target, init]
  end

  def to_js(indentation="")
    "#{@kind} " + @declarators.map do |target, init|
      init ? "#{target.to_js} = #{init.to_js}" : target.to_js
    end.join(', ')
  end

end
