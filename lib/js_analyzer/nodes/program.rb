class JSAnalyzer::Node::Program < JSAnalyzer::Node::Scope

  # The source that was parsed
  attr_accessor :source

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
    @statements.each do |statment|
      js << statment.to_js << ";\n"
    end
    js
  end

end