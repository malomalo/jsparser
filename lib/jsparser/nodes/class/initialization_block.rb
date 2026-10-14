class JSParser::Node::Class::InitializationBlock < JSParser::Node::Scope

  def initialize(**options)
    super(kind: :static_block, **options)
  end

  def to_js(indentation="")
    "{#{JSParser::Node.statements_to_js(@statements, indentation + '    ')}\n#{indentation}}"
  end
  
end