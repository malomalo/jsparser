class JSAnalyzer::Node
  
  autoload :Array,                  'js_analyzer/nodes/array'
  autoload :BinaryOperator,         'js_analyzer/nodes/binary_operator'
  autoload :Boolean,                'js_analyzer/nodes/boolean'
  autoload :BracketAccessor,        'js_analyzer/nodes/bracket_accessor'
  autoload :Class,                  'js_analyzer/nodes/class'
  autoload :DotAccessor,            'js_analyzer/nodes/dot_accessor'
  autoload :DestructureArray,       'js_analyzer/nodes/destructure_array'
  autoload :DestructureObject,      'js_analyzer/nodes/destructure_object'  
  autoload :ExportStatement,        'js_analyzer/nodes/export_statement'
  autoload :ForIn,                  'js_analyzer/nodes/for_in'
  autoload :ForLoop,           'js_analyzer/nodes/for_loop'
  autoload :FunctionCall,           'js_analyzer/nodes/function_call'
  autoload :Group,                  'js_analyzer/nodes/group'
  autoload :Identifier,             'js_analyzer/nodes/identifier'
  autoload :If,                     'js_analyzer/nodes/if'
  autoload :ImportStatement,        'js_analyzer/nodes/import_statement'
  autoload :Instantiation,          'js_analyzer/nodes/instantiation'
  autoload :InterpolatedString,     'js_analyzer/nodes/string'
  autoload :JumpStatement,          'js_analyzer/nodes/jump_statement'
  autoload :Keyword,                'js_analyzer/nodes/keyword'
  autoload :Method,                 'js_analyzer/nodes/method'
  autoload :Number,                 'js_analyzer/nodes/number'
  autoload :Object,                 'js_analyzer/nodes/object'
  autoload :Operator,                'js_analyzer/nodes/operator'
  autoload :PrefixOperator,         'js_analyzer/nodes/prefix_operator'
  autoload :PrivateName,            'js_analyzer/nodes/keyword'
  autoload :Program,                'js_analyzer/nodes/program'
  autoload :Regex,        'js_analyzer/nodes/regex'
  autoload :ReturnStatement,        'js_analyzer/nodes/return_statement'
  autoload :Scope,                  'js_analyzer/nodes/scope'
  autoload :String,                 'js_analyzer/nodes/string'
  autoload :SpreadOperator,          'js_analyzer/nodes/operators/spread_operator'
  autoload :TaggedTemplate,         'js_analyzer/nodes/tagged_template'
  autoload :Ternary,                'js_analyzer/nodes/ternary'
  autoload :UnaryOperator,          'js_analyzer/nodes/unary_operator'
  autoload :VariableDeclaration,    'js_analyzer/nodes/variable_declaration'
  autoload :VariableReference,      'js_analyzer/nodes/variable_reference'
  autoload :VariableStatement,      'js_analyzer/nodes/variable_statement'
  autoload :Yield,                  'js_analyzer/nodes/yield'

  autoload :Block,                  'js_analyzer/nodes/statements'
  autoload :DoWhile,                'js_analyzer/nodes/statements'
  autoload :LabeledStatement,       'js_analyzer/nodes/statements'
  autoload :Switch,                 'js_analyzer/nodes/statements'
  autoload :ThrowStatement,         'js_analyzer/nodes/statements'
  autoload :Try,                    'js_analyzer/nodes/statements'
  autoload :While,                  'js_analyzer/nodes/statements'
  autoload :With,                   'js_analyzer/nodes/statements'
  autoload :DebuggerStatement,      'js_analyzer/nodes/statements'
  autoload :MetaProperty,           'js_analyzer/nodes/statements'

  # Renders the statements of a block body as `{ ... }`
  def self.block_to_js(statements, indentation="")
    return "{ }" if statements.empty?

    js = ::String.new("{")
    statements.each do |part|
      js << "\n#{indentation}    #{part.to_js(indentation + '    ')};"
    end
    js << "\n#{indentation}}"
  end
end