# A use of a variable, e.g. the `a` in `a + 1`. After parsing, `declaration`
# is the VariableDeclaration it resolves to (an implicit "global" one if the
# variable is never declared).
#
#   text   the name as written in the source
#   range  where it is in the source, as byte offsets (source.byteslice(range) is the text)
#   scope  the Scope it appears in
class JSAnalyzer::Node::VariableReference

  attr_reader :text, :range
  attr_accessor :scope, :declaration

  def initialize(text, scope, range: nil)
    @text = text
    @scope = scope
    @range = range
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
