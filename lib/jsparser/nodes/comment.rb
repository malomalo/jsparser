# A `// line` or `/* block */` comment, kept in statement lists and class
# bodies (comments inside expressions aren't kept).
#
#   text      the comment as written, including `//` or `/*` and `*/`
#   range     where it is in the source, as byte offsets
#   trailing  whether it follows code on the same line (`a(); // why`), so
#             it's printed at the end of that line rather than on its own
class JSParser::Node::Comment

  attr_reader :text, :range
  attr_writer :trailing

  def initialize(text, range, trailing: false)
    @text = text
    @range = range
    @trailing = trailing
  end

  def trailing?
    @trailing
  end

  def block?
    @text.start_with?('/*')
  end

  # A block comment's later lines are indented to match, keeping a leading
  # ` *` (as in JSDoc) lined up under the `/*`
  def to_js(indentation="")
    return @text.dup unless block? && @text.include?("\n")

    first, *rest = @text.split("\n", -1)
    rest = rest.map do |line|
      line = line.lstrip
      line.start_with?('*') ? "#{indentation} #{line}" : "#{indentation}#{line}"
    end
    [first, *rest].join("\n")
  end

end
