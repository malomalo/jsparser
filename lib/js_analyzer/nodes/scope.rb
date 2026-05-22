class JSAnalyzer::Node::Scope

  attr_reader :statements, :parent_scope
  
  def initialize(scope: nil, statements: [])
    @statements = statements
    @references = {}
    @declarations = {}
    @parent_scope = scope
  end
  
  def var(name)
    @references[name] ||= JSAnalyzer::Node::VariableReference.new(name, self)
  end
  
  def declare(type, name = nil, init = nil, destructure: false)
    @declarations[name] = JSAnalyzer::Node::VariableDeclaration.new(type, destructure: destructure)
    @declarations[name].add(name, init) if name
    @declarations[name]
  end
  
  def <<(statement)
    @statements << statement if statement
  end

  # def lookup(name)
  #   @variables[name] || @parent_scope&.lookup(name)
  # end

end