# A binding: where a variable is declared, e.g. the `a` in `let a = 1`, a
# function parameter, an import, or a function or class name.
#
#   kind        "var", "let", "const", "param", "function", "class",
#               "import", "catch", or for variables that are never declared,
#               "global" (and "arguments" inside a function)
#   identifier  the name, shared with every reference (see Identifier)
#   text        the name as written in the source
#   range       where it is in the source, as byte offsets (source.byteslice(range) is the text)
#   scope       the Scope it's declared in
#   references  every VariableReference that resolves to it
class JSAnalyzer::Node::VariableDeclaration

  attr_reader :kind, :identifier, :text, :range, :scope, :references
  attr_writer :identifier # to share another declaration's (see Scope#declare_block_function)

  def initialize(kind, identifier, scope:, range: nil, text: identifier.name, implicit: false, block_function: false)
    @kind = kind
    @identifier = identifier
    @text = text
    @range = range
    @scope = scope
    @implicit = implicit
    @block_function = block_function
    @references = []
  end

  # True for the var a function declared in a block also gets in non-strict
  # code (see Scope#declare_block_function)
  def block_function?
    @block_function
  end

  def name
    @identifier.name
  end

  # True for a global or `arguments` that is used but never declared
  def implicit?
    @implicit
  end

  # The references that use the variable's value
  def reads
    @references.select(&:read?)
  end

  # The references that assign to the variable, after its declaration
  def writes
    @references.select(&:write?)
  end

  # [line, column], 1-based
  def location
    @range && @scope.program.location(@range.begin)
  end

  def to_js(indentation="")
    @identifier.to_js
  end

  def inspect
    "#<#{self.class.name} #{@kind} #{name}#{" at #{location.join(':')}" if location}>"
  end

end
