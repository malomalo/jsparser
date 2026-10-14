class JSAnalyzer::Node::Class::InitializationBlock < JSAnalyzer::Node::Scope

  def initialize(**options)
    super(kind: :static_block, **options)
  end

  def to_js(indentation="")
    "{#{JSAnalyzer::Node.statements_to_js(@statements, indentation + '    ')}\n#{indentation}}"
  end
  
end