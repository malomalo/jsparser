# Splits JavaScript source into tokens on demand. The parser asks for each
# token as it needs it, saying whether a regex can start there: a `/` after
# a value is division, and anywhere else starts a regex. Template literals
# are read a piece at a time (see template_chunk).
#
# Whitespace and comments are skipped; each token records whether a line
# break came before it, for automatic semicolon insertion. Positions are
# byte offsets into the source.
class JSAnalyzer::Tokenizer

  include StreamParser

  # type        :name (identifiers and keywords), :private_name (#x),
  #             :number, :string, :regex, :template (the opening backtick),
  #             :punctuator or :eof
  # value       the token as written
  # start, end  its byte offsets
  # newline_before  whether a line break comes between it and the token
  #             before
  # lex_start   where lexing it began, before the whitespace and comments
  #             in front of it
  Token = Struct.new(:type, :value, :start, :end, :newline_before, :lex_start) do
    def punctuator?(*values)
      type == :punctuator && values.include?(value)
    end

    # A name, or with values, one of those names
    def name?(*values)
      type == :name && (values.empty? || values.include?(value))
    end

    def eof?
      type == :eof
    end

    def range
      start...self.end
    end
  end

  # Whitespace and comments
  SKIP = %r{(?:[\p{Space}\u{feff}]+|//[^\r\n\u2028\u2029]*|/\*.*?\*/)+}m
  LINE_TERMINATOR = /[\r\n\u2028\u2029]/

  NAME = /[\p{Alpha}_$][\p{Alpha}_$\d]*/
  PRIVATE_NAME = /\#[\p{Alpha}_$][\p{Alpha}_$\d]*/
  NUMBER = /0[xX][\da-fA-F_]+n?|0[oO][0-7_]+n?|0[bB][01_]+n?|(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?n?/
  STRING = /"(?:[^"\\\r\n]|\\.)*"|'(?:[^'\\\r\n]|\\.)*'/m
  # A / outside a character class ends the regex; inside one it doesn't, so
  # /[/]/ is valid
  REGEX = %r{/(?![*/])(?:[^/\\\[\r\n]|\\.|\[(?:[^\]\\\r\n]|\\.)*\])+/[\p{Alpha}\d_$]*}

  PUNCTUATORS = %w(
    >>>= ... === !== **= <<= >>= >>> &&= ||= ??=
    => == != <= >= += -= *= /= %= &= |= ^= ** ++ -- << >> && || ??
    { } ( ) [ ] ; , < > + - * / % & | ^ ! ~ ? : = .
  ).sort_by { -it.size }
  # `?.` isn't optional chaining before a digit: `a?.5:1` is a ternary
  PUNCTUATOR = /\?\.(?!\d)|#{Regexp.union(PUNCTUATORS)}/

  # Template literal text up to `${` or the closing backtick, as written
  TEMPLATE_TEXT = /(?:[^`\\$]|\\.|\$(?!\{))*/m

  # The most recently consumed token
  attr_reader :last

  def initialize(source)
    super
    scan(/#![^\n]*/) # hashbang, e.g. #!/usr/bin/env node
    @peeked = nil
    @last = nil
  end

  # The next token, without consuming it
  def peek(regex: false)
    if @peeked
      # A token read as `/` (division) is a regex in the other mode, and
      # the other way around, so read it again
      return @peeked unless @peeked_regex != regex && slash?(@peeked)
      @index = @peeked.lex_start
    end

    @peeked_regex = regex
    @peeked = lex(regex)
  end

  # Consumes and returns the next token
  def next(regex: false)
    token = peek(regex: regex)
    @peeked = nil
    @last = token
  end

  # Puts back `token`, the most recently consumed one or a token before it,
  # so that it's read again next
  def unread(token)
    @index = token.lex_start
    @peeked = nil
  end

  # Reads template literal text, after the opening backtick or the `}` that
  # ends an interpolation. Returns the text and whether an interpolation
  # (`${`) or the end of the template (:end) follows.
  def template_chunk
    @index = @peeked.lex_start if @peeked
    @peeked = nil

    text = scan(TEMPLATE_TEXT)
    if scan(/\$\{/)
      [text, :interpolation]
    elsif scan(/`/)
      [text, :end]
    else
      raise syntax_error("unterminated template literal", @index)
    end
  end

  # A JSAnalyzer::SyntaxError at `position`, with the line and column and the
  # source around it
  def syntax_error(message, position = @index)
    before = @source.byteslice(0, [position, @source.bytesize].min)
    after = @source.byteslice(before.bytesize..)
    line = before.count("\n") + 1
    line_before = before[((before.rindex("\n") || -1) + 1)..]
    line_after = after[/\A[^\n]*/]

    # Show at most 80 characters either side, so minified files stay readable
    shown_before = line_before[-80..] || line_before
    JSAnalyzer::SyntaxError.new(
      "#{message} at #{line}:#{line_before.size + 1}\n  #{shown_before}#{line_after[0, 80]}\n  #{' ' * shown_before.size}^"
    )
  end

  private

  # Matches re at the current position (@index, a byte offset) and moves past
  # it, returning the text. StreamParser#gobble searches the rest of the
  # source for a match and then checks it starts here; anchoring with \G
  # and a never-matching `|(?!)` alternative makes Onigmo try only the
  # current position (without the alternative it first searches ahead for
  # a literal every match needs, such as the `/` of a comment).
  def scan(re)
    return unless @source.byteindex(ANCHORED[re], @index)

    @old_index = @index
    @match = $~[0]
    @index = $~.byteend(0)
    @match
  end

  # Whether re matches at the current position
  def match?(re)
    !!@source.byteindex(ANCHORED[re], @index)
  end

  ANCHORED = Hash.new { |cache, re| cache[re] = Regexp.new("\\G(?:#{re.source}|(?!))", re.options) }.compare_by_identity

  def slash?(token)
    token.type == :regex || token.punctuator?('/', '/=')
  end

  def lex(regex)
    lex_start = @index
    skipped = scan(SKIP)
    newline = skipped ? skipped.match?(LINE_TERMINATOR) : false
    raise syntax_error("unterminated comment") if match?(%r{/\*})

    start = @index
    return Token.new(:eof, nil, start, start, newline, lex_start) if eos?

    type, value = case @source.getbyte(start)
    when 0x22, 0x27 # " '
      [:string, scan(STRING) || raise(syntax_error("unterminated string"))]
    when 0x60 # `
      @index += 1
      [:template, '`']
    when 0x23 # #
      [:private_name, scan(PRIVATE_NAME)]
    when 0x30..0x39 # 0-9
      [:number, scan(NUMBER)]
    when 0x2E # .
      (number = scan(NUMBER)) ? [:number, number] : [:punctuator, scan(PUNCTUATOR)]
    when 0x2F # /
      (regex && (re = scan(REGEX))) ? [:regex, re] : [:punctuator, scan(PUNCTUATOR)]
    else
      (name = scan(NAME)) ? [:name, name] : [:punctuator, scan(PUNCTUATOR)]
    end
    raise syntax_error("unexpected #{@source.byteslice(start, 4).scrub[0].inspect}") unless value

    Token.new(type, value, start, @index, newline, lex_start)
  end

end
