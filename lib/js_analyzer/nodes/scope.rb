# The variables declared in a part of the program and the references made
# in it. Scopes form a tree from the Program down.
#
#   kind  :program, :function, :arrow, :class, :static_block, :block or
#         :catch
#
# References are resolved once the whole program is parsed (see resolve!),
# since JavaScript lets a variable be used before it's declared.
class JSAnalyzer::Node::Scope

  attr_reader :statements, :kind, :declarations, :references, :children
  attr_accessor :parent_scope

  # Scopes that `var` declarations belong to
  VAR_SCOPES = %i(program function arrow static_block)

  def initialize(scope: nil, statements: [], kind: :block)
    @statements = statements
    @kind = kind
    @declarations = {}
    @references = []
    @children = []
    @parent_scope = scope
    scope&.children&.<<(self)
  end

  # Declares `name` here (or, for `var`, in the enclosing function) and
  # returns the VariableDeclaration. Declaring a name again (`var a; var a`)
  # shares the first declaration's Identifier.
  def declare(kind, name, range: nil)
    target = kind == 'var' ? var_scope : self
    existing = target.declarations[name]
    identifier = existing ? existing.identifier : JSAnalyzer::Node::Identifier.new(name)
    declaration = JSAnalyzer::Node::VariableDeclaration.new(kind, identifier, scope: target, range: range)
    target.declarations[name] ||= declaration
    declaration
  end

  # A reference to `name` from this scope
  def var(name, range: nil)
    reference = JSAnalyzer::Node::VariableReference.new(name, self, range: range)
    @references << reference
    reference
  end

  # The VariableDeclaration `name` refers to from here, or nil
  def lookup(name)
    @declarations[name] || @parent_scope&.lookup(name)
  end

  # The variables declared in this scope
  def variables
    @declarations.values
  end

  # Every variable visible from this scope, by name. Inner declarations hide
  # outer ones.
  def variables_in_scope
    (@parent_scope&.variables_in_scope || {}).merge(@declarations)
  end

  # This scope and every scope inside it
  def scopes
    [self] + @children.flat_map(&:scopes)
  end

  def program
    @parent_scope ? @parent_scope.program : self
  end

  # The scope a `var` here is declared in
  def var_scope
    VAR_SCOPES.include?(@kind) || @parent_scope.nil? ? self : @parent_scope.var_scope
  end

  # Points every reference in this scope, and those inside it, at its
  # declaration
  def resolve!
    @references.each do |reference|
      declaration = lookup(reference.text) || implicit_declaration(reference.text)
      reference.declaration = declaration
      declaration.references << reference
    end
    @children.each(&:resolve!)
  end

  def <<(statement)
    @statements << statement if statement
  end

  protected

  def declare_implicit(kind, name)
    @declarations[name] ||= JSAnalyzer::Node::VariableDeclaration.new(
      kind, JSAnalyzer::Node::Identifier.new(name), scope: self, implicit: true
    )
  end

  private

  # `arguments` belongs to the nearest non-arrow function; anything else that
  # is never declared is a global
  def implicit_declaration(name)
    if name == 'arguments' && (function = scopes_up.find { it.kind == :function })
      function.declare_implicit('arguments', name)
    else
      program.declare_implicit('global', name)
    end
  end

  def scopes_up
    @parent_scope ? [self] + @parent_scope.send(:scopes_up) : [self]
  end

end
