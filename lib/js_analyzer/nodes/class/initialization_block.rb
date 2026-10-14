class JSAnalyzer::Node::Class::InitializationBlock < JSAnalyzer::Node::Scope

  def initialize(**options)
    super(kind: :static_block, **options)
  end

  def to_js(indentation="")
    js = String.new("{\n")
    @statements.each do |statment|
      js << indentation << '    ' << statment.to_js(indentation + '    ') << ";\n"
    end
    js << "#{indentation}}"
  end
  
end