# The variables declared in a part of the program and the references made
# in it. Scopes form a tree from the Program down.
#
#   kind  :program, :function, :arrow, :class, :static_block, :block or
#         :catch
#
# References are resolved as each scope closes (see close!), since
# JavaScript lets a variable be used before it's declared.
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
    @pending = []
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
    @pending << reference
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

  # References that haven't been resolved yet: this scope's own, and those
  # passed up from scopes inside it that have closed
  attr_reader :pending

  # Resolves the pending references once everything in this scope has been
  # parsed, so its declarations are complete, including hoisted ones (in
  # `f(); function f() {}` the call is parsed first). Those not declared here
  # are passed up to the parent; at the program they become implicit globals.
  def close!
    @pending.each do |reference|
      declaration = @declarations[reference.text]
      declaration ||= declare_implicit('arguments', 'arguments') if reference.text == 'arguments' && @kind == :function
      declaration ||= declare_implicit('global', reference.text) unless @parent_scope

      if declaration
        reference.declaration = declaration
        declaration.references << reference
      else
        @parent_scope.pending << reference
      end
    end
    @pending = []
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

end
