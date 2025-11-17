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
  
  def declare(type, name = nil, init = nil)
    @declarations[name] = JSAnalyzer::Node::VariableDeclaration.new(type)
    @declarations[name].add(name, init) if name
    @declarations[name]
  end

  # def lookup(name)
  #   @variables[name] || @parent_scope&.lookup(name)
  # end

end

class JSAnalyzer::Node::GlobalVariable

  attr_reader :name

  def initialize(name)
    @name = name
  end
end

class JSAnalyzer::Node::Program < JSAnalyzer::Node::Scope

  def initialize(...)
    super
    @globals = {}
  end

  # def lookup(name)
  #   if @variables[name]
  #     @variables[name]
  #   elsif @globals[name]
  #     @globals[name]
  #   else
  #     @globals[name] = JSAnalyzer::Node::GlobalVariable.new(name)
  #   end
  # end

end