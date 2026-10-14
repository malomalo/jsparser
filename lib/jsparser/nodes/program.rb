class JSParser::Node::Program < JSParser::Node::Scope

  # The source that was parsed
  attr_accessor :source

  # The `#!` line at the start of the source, if there is one
  attr_accessor :hashbang

  # :script or :module, as parsed
  attr_accessor :source_type

  # The import statements
  def imports
    @statements.grep(JSParser::Node::ImportStatement)
  end

  # The export statements
  def exports
    @statements.grep(JSParser::Node::ExportStatement)
  end

  # Whether it's an ES module: parsed as one, or has imports or exports
  def module?
    @source_type == :module || !imports.empty? || !exports.empty?
  end

  # Every name exported (not including those of `export * from "module"`)
  def exported_names
    exports.flat_map(&:exported_names).uniq
  end

  def default_export?
    exports.any?(&:default?)
  end

  # The modules imported or re-exported from, in the order they appear
  def dependencies
    @statements.filter_map do |statement|
      case statement
      when JSParser::Node::ImportStatement, JSParser::Node::ExportStatement then statement.source
      end
    end.uniq
  end

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