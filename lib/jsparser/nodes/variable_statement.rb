# A `var`, `let`, `const`, `using` or `await using` statement, e.g.
# `let a = 1, { b } = c`.
#
#   kind         "var", "let", "const", "using" or "await using"
#   declarators  [target, init] pairs, where target is a VariableDeclaration
#                or a destructuring pattern, and init may be nil
class JSParser::Node::VariableStatement

  attr_reader :kind, :declarators

  def initialize(kind)
    @kind = kind
    @declarators = []
  end

  def add(target, init = nil)
    @declarators << [target, init]
  end

  # Every variable declared, including those in destructuring patterns
  def declarations
    @declarators.flat_map { |target, _| JSParser::Node.declarations_in(target) }
  end

  def to_js(indentation="")
    "#{@kind} " + @declarators.map do |target, init|
      init ? "#{target.to_js} = #{init.to_js}" : target.to_js
    end.join(', ')
  end

end
