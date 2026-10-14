class JSParser::Node
  
  autoload :Array,                  'jsparser/nodes/array'
  autoload :BinaryOperator,         'jsparser/nodes/binary_operator'
  autoload :Boolean,                'jsparser/nodes/boolean'
  autoload :BracketAccessor,        'jsparser/nodes/bracket_accessor'
  autoload :Class,                  'jsparser/nodes/class'
  autoload :DotAccessor,            'jsparser/nodes/dot_accessor'
  autoload :Comment,                'jsparser/nodes/comment'
  autoload :DestructureArray,       'jsparser/nodes/destructure_array'
  autoload :DestructureObject,      'jsparser/nodes/destructure_object'  
  autoload :ExportStatement,        'jsparser/nodes/export_statement'
  autoload :ForIn,                  'jsparser/nodes/for_in'
  autoload :ForLoop,           'jsparser/nodes/for_loop'
  autoload :FunctionCall,           'jsparser/nodes/function_call'
  autoload :Group,                  'jsparser/nodes/group'
  autoload :Identifier,             'jsparser/nodes/identifier'
  autoload :If,                     'jsparser/nodes/if'
  autoload :ImportStatement,        'jsparser/nodes/import_statement'
  autoload :Instantiation,          'jsparser/nodes/instantiation'
  autoload :InterpolatedString,     'jsparser/nodes/string'
  autoload :JumpStatement,          'jsparser/nodes/jump_statement'
  autoload :Keyword,                'jsparser/nodes/keyword'
  autoload :Method,                 'jsparser/nodes/method'
  autoload :Number,                 'jsparser/nodes/number'
  autoload :Object,                 'jsparser/nodes/object'
  autoload :PrefixOperator,         'jsparser/nodes/prefix_operator'
  autoload :PrivateName,            'jsparser/nodes/keyword'
  autoload :Program,                'jsparser/nodes/program'
  autoload :Regex,        'jsparser/nodes/regex'
  autoload :ReturnStatement,        'jsparser/nodes/return_statement'
  autoload :Scope,                  'jsparser/nodes/scope'
  autoload :String,                 'jsparser/nodes/string'
  autoload :SpreadOperator,          'jsparser/nodes/spread_operator'
  autoload :TaggedTemplate,         'jsparser/nodes/tagged_template'
  autoload :Ternary,                'jsparser/nodes/ternary'
  autoload :UnaryOperator,          'jsparser/nodes/unary_operator'
  autoload :VariableDeclaration,    'jsparser/nodes/variable_declaration'
  autoload :VariableReference,      'jsparser/nodes/variable_reference'
  autoload :VariableStatement,      'jsparser/nodes/variable_statement'
  autoload :Yield,                  'jsparser/nodes/yield'

  autoload :Block,                  'jsparser/nodes/statements'
  autoload :DoWhile,                'jsparser/nodes/statements'
  autoload :LabeledStatement,       'jsparser/nodes/statements'
  autoload :Switch,                 'jsparser/nodes/statements'
  autoload :ThrowStatement,         'jsparser/nodes/statements'
  autoload :Try,                    'jsparser/nodes/statements'
  autoload :While,                  'jsparser/nodes/statements'
  autoload :With,                   'jsparser/nodes/statements'
  autoload :DebuggerStatement,      'jsparser/nodes/statements'
  autoload :MetaProperty,           'jsparser/nodes/statements'

  # Renders the statements of a block body as `{ ... }`
  def self.block_to_js(statements, indentation="")
    return "{ }" if statements.empty?

    "{#{statements_to_js(statements, indentation + '    ')}\n#{indentation}}"
  end

  # Renders a list of statements (or class members), each on its own line
  # starting with a line break, ending in `;`. Comments go on their own line,
  # or for a trailing comment, at the end of the line before.
  def self.statements_to_js(statements, indentation="")
    js = ::String.new
    statements.each do |statement|
      if statement.is_a?(JSParser::Node::Comment)
        js << (statement.trailing? && !js.empty? ? " " : "\n#{indentation}")
        js << statement.to_js(indentation)
      else
        js << "\n#{indentation}" << statement.to_js(indentation) << ";"
      end
    end
    js
  end
end