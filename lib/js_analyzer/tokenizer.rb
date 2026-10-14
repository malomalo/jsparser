require 'strscan'

# Splits JavaScript source into tokens on demand. The parser asks for each
# token as it needs it, saying whether a regex can start there: a `/` after
# a value is division, and anywhere else starts a regex. Template literals
# are read a piece at a time (see template_chunk).
#
# Whitespace and comments are skipped; each token records whether a line
# break came before it, for automatic semicolon insertion. Positions are
# byte offsets into the source.
class JSAnalyzer::Tokenizer

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
    @source = source
    @scanner = StringScanner.new(source)
    @scanner.skip(/#![^\n]*/) # hashbang, e.g. #!/usr/bin/env node
    @peeked = nil
    @last = nil
  end

  # The next token, without consuming it
  def peek(regex: false)
    if @peeked
      # A token read as `/` (division) is a regex in the other mode, and
      # the other way around, so read it again
      return @peeked unless @peeked_regex != regex && slash?(@peeked)
      @scanner.pos = @peeked.lex_start
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
    @scanner.pos = token.lex_start
    @peeked = nil
  end

  # Reads template literal text, after the opening backtick or the `}` that
  # ends an interpolation. Returns the text and whether an interpolation
  # (`${`) or the end of the template (:end) follows.
  def template_chunk
    @scanner.pos = @peeked.lex_start if @peeked
    @peeked = nil

    text = @scanner.scan(TEMPLATE_TEXT)
    if @scanner.skip(/\$\{/)
      [text, :interpolation]
    elsif @scanner.skip(/`/)
      [text, :end]
    else
      raise syntax_error("unterminated template literal", @scanner.pos)
    end
  end

  # A JSAnalyzer::SyntaxError at `position`, with the line and column and the
  # source around it
  def syntax_error(message, position = @scanner.pos)
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

  def slash?(token)
    token.type == :regex || token.punctuator?('/', '/=')
  end

  def lex(regex)
    lex_start = @scanner.pos
    skipped = @scanner.scan(SKIP)
    newline = skipped ? skipped.match?(LINE_TERMINATOR) : false
    raise syntax_error("unterminated comment") if @scanner.match?(%r{/\*})

    start = @scanner.pos
    return Token.new(:eof, nil, start, start, newline, lex_start) if @scanner.eos?

    type, value = case @source.getbyte(start)
    when 0x22, 0x27 # " '
      [:string, @scanner.scan(STRING) || raise(syntax_error("unterminated string"))]
    when 0x60 # `
      @scanner.pos += 1
      [:template, '`']
    when 0x23 # #
      [:private_name, @scanner.scan(PRIVATE_NAME)]
    when 0x30..0x39 # 0-9
      [:number, @scanner.scan(NUMBER)]
    when 0x2E # .
      (number = @scanner.scan(NUMBER)) ? [:number, number] : [:punctuator, @scanner.scan(PUNCTUATOR)]
    when 0x2F # /
      (regex && (re = @scanner.scan(REGEX))) ? [:regex, re] : [:punctuator, @scanner.scan(PUNCTUATOR)]
    else
      (name = @scanner.scan(NAME)) ? [:name, name] : [:punctuator, @scanner.scan(PUNCTUATOR)]
    end
    raise syntax_error("unexpected #{@source.byteslice(start, 4).scrub[0].inspect}") unless value

    Token.new(type, value, start, @scanner.pos, newline, lex_start)
  end

end
