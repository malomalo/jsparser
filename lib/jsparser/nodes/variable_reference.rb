# A use of a variable, e.g. the `a` in `a + 1`. After parsing, `declaration`
# is the VariableDeclaration it resolves to (an implicit "global" one if the
# variable is never declared).
#
#   text   the name as written in the source
#   range  where it is in the source, as byte offsets (source.byteslice(range) is the text)
#   scope  the Scope it appears in
class JSParser::Node::VariableReference

  attr_reader :text, :range
  attr_accessor :scope, :declaration
  attr_writer :read, :write

  def initialize(text, scope, range: nil)
    @text = text
    @scope = scope
    @range = range
    @read = true
    @write = false
  end

  # Whether the value is used. False only for the target of a plain
  # assignment (`x = 1`); `x += 1` and `x++` both read and write.
  def read?
    @read
  end

  # Whether a value is assigned: by `=`, a compound assignment, `++`/`--`,
  # a destructuring assignment, or `for (x of xs)`
  def write?
    @write
  end

  def identifier
    @declaration&.identifier
  end

  def name
    identifier ? identifier.name : @text
  end

  # [line, column], 1-based
  def location
    @range && @scope.program.location(@range.begin)
  end

  def to_js(indentation="")
    name.dup
  end

  def inspect
    "#<#{self.class.name} #{name}#{" at #{location.join(':')}" if location}>"
  end

end
