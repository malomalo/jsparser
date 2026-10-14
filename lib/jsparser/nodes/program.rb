class JSParser::Node::Program < JSParser::Node::Scope

  # The source that was parsed
  attr_accessor :source

  # The `#!` line at the start of the source, if there is one
  attr_accessor :hashbang

  def initialize(**options)
    super(kind: :program, **options)
  end

  # [line, column], 1-based, of a byte offset in the source. The column
  # counts characters.
  def location(offset)
    before = @source.byteslice(0, offset)
    [before.count("\n") + 1, before.size - (before.rindex("\n") || -1)]
  end

  def to_js(indentation="")
    js = String.new
    js << @hashbang << "\n" if @hashbang
    statements = JSParser::Node.statements_to_js(@statements)
    js << statements[1..] << "\n" unless statements.empty?
    js
  end

end