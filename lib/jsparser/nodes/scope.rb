# The variables declared in a part of the program and the references made
# in it. Scopes form a tree from the Program down.
#
#   kind  :program, :function, :arrow, :class, :static_block, :block,
#         :switch (a switch's cases), :catch, or :function_body (the body of a function whose parameters
#         aren't simple, which has its own scope)
#
# References are resolved as each scope closes (see close!), since
# JavaScript lets a variable be used before it's declared.
class JSParser::Node::Scope

  attr_reader :statements, :kind, :declarations, :references, :children
  attr_accessor :parent_scope

  # Scopes that `var` declarations belong to
  VAR_SCOPES = %i(program function arrow function_body static_block)

  # Whether the scope's code is strict mode: module code, class bodies,
  # code after a "use strict" directive, and everything inside those
  attr_writer :strict

  def strict?
    @strict
  end

  def initialize(scope: nil, statements: [], kind: :block)
    @statements = statements
    @kind = kind
    @declarations = {}
    @references = []
    @pending = []
    @children = []
    @parent_scope = scope
    @strict = kind == :class || scope&.strict? || false
    scope&.children&.<<(self)
  end

  # Declares `name` here (or, for `var`, in the enclosing function) and
  # returns the VariableDeclaration. Declaring a name again (`var a; var a`)
  # shares the first declaration's Identifier.
  def declare(kind, name, range: nil)
    target = kind == 'var' ? var_scope : self
    existing = target.declarations[name]
    if existing&.block_function? && LEXICAL.include?(kind)
      # A let, const or class replaces a binding added for a function in a
      # block (see declare_block_function), which then doesn't apply
      target.declarations.delete(name)
      existing = nil
    end

    identifier = existing ? existing.identifier : JSParser::Node::Identifier.new(name)
    declaration = JSParser::Node::VariableDeclaration.new(kind, identifier, scope: target, range: range)
    target.declarations[name] ||= declaration
    declaration
  end

  LEXICAL = ['let', 'const', 'class', 'using', 'await using'].freeze

  # In non-strict code a function declared in a block (`{ function f() {} }`)
  # is also a var in the enclosing function (Annex B.3.3 of the spec), unless
  # that would clash with a let, const or class there. The two bindings share
  # an Identifier, so renaming one renames both.
  def declare_block_function(declaration)
    target = var_scope
    return if target.equal?(self) || strict?

    existing = target.declarations[declaration.text]
    return if existing && LEXICAL.include?(existing.kind)

    if existing
      declaration.identifier = existing.identifier
    else
      target.declarations[declaration.text] = JSParser::Node::VariableDeclaration.new(
        'function', declaration.identifier, scope: target, range: declaration.range, block_function: true
      )
    end
  end

  # A reference to `name` from this scope
  def var(name, range: nil)
    reference = JSParser::Node::VariableReference.new(name, self, range: range)
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
    @declarations[name] ||= JSParser::Node::VariableDeclaration.new(
      kind, JSParser::Node::Identifier.new(name), scope: self, implicit: true
    )
  end

end
