# frozen_string_literal: true

require 'strscan'

# Splits JavaScript source into tokens on demand. The parser asks for each
# token as it needs it, saying whether a regex can start there: a `/` after
# a value is division, and anywhere else starts a regex. Template literals
# are read a piece at a time (see template_chunk).
#
# Whitespace and comments are skipped; each token records whether a line
# break came before it, for automatic semicolon insertion. Positions are
# byte offsets into the source.
class JSParser::Tokenizer

  # type        :name (identifiers and keywords), :private_name (#x),
  #             :number, :string, :regex, :template (the opening backtick),
  #             :punctuator or :eof
  # value       the token as written
  # start, end  its byte offsets
  # newline_before  whether a line break comes between it and the token
  #             before
  # lex_start   where lexing it began, before the whitespace and comments
  #             in front of it
  # regex       whether it was read where a regex could start
  # comments    the comments before it (JSParser::Node::Comment), or nil
  Token = Struct.new(:type, :value, :start, :end, :newline_before, :lex_start, :regex, :comments) do
    # The punctuator `expected`. (One value, not a splat, as this is called
    # constantly and a splat allocates an array per call.)
    def punctuator?(expected)
      type == :punctuator && value == expected
    end

    def punctuator_in?(values)
      type == :punctuator && values.include?(value)
    end

    # A name, or with expected, that name
    def name?(expected = nil)
      type == :name && (expected.nil? || value == expected)
    end

    def name_in?(values)
      type == :name && values.include?(value)
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
  COMMENT = %r{//[^\r\n\u2028\u2029]*|/\*.*?\*/}m

  NAME = /[\p{Alpha}_$][\p{Alpha}_$\d]*/
  PRIVATE_NAME = /\#[\p{Alpha}_$][\p{Alpha}_$\d]*/
  NUMBER = /0[xX][\da-fA-F_]+n?|0[oO][0-7_]+n?|0[bB][01_]+n?|(?:\d[\d_]*(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?n?/
  STRING = /"(?:[^"\\\r\n]|\\.)*"|'(?:[^'\\\r\n]|\\.)*'/m
  # A / outside a character class ends the regex; inside one it doesn't, so
  # /[/]/ is valid
  REGEX = %r{/(?![*/])(?:[^/\\\[\r\n]|\\.|\[(?:[^\]\\\r\n]|\\.)*\])+/[\p{Alpha}\d_$]*}

  PUNCTUATORS = %w(
    >>>= ... === !== **= <<= >>= >>> &&= ||= ??=
    => == != <= >= += -= *= /= %= &= |= ^= ** ++ -- << >> && || ?? ?.
    { } ( ) [ ] ; , < > + - * / % & | ^ ! ~ ? : = .
  ).map(&:freeze)

  # The punctuators starting with each byte, longest first, as [punctuator,
  # its bytes], so they can be matched without a regex or allocating
  PUNCTUATOR_CANDIDATES = PUNCTUATORS.group_by(&:ord).transform_values do |punctuators|
    punctuators.sort_by { -it.bytesize }.map { [it, it.bytes] }.freeze
  end.freeze

  # Template literal text up to `${` or the closing backtick, as written
  TEMPLATE_TEXT = /(?:[^`\\$]|\\.|\$(?!\{))*/m

  # How to read a token, by its first byte
  BYTE_CLASS = Array.new(256, :punctuator).tap do |classes|
    [*'a'..'z', *'A'..'Z', '_', '$'].each { classes[it.ord] = :name }
    (0x80..0xFF).each { classes[it] = :name } # a non-ASCII letter
    ('0'..'9').each { classes[it.ord] = :number }
    '{}()[];,~:'.each_char { classes[it.ord] = :single }
    classes['.'.ord] = :dot
    classes['/'.ord] = :slash
    classes['"'.ord] = classes["'".ord] = :string
    classes['`'.ord] = :template
    classes['#'.ord] = :hash
  end.freeze

  # Punctuators that are always one character, by byte, shared so reading
  # one doesn't allocate
  SINGLE_PUNCTUATORS = '{}()[];,~:'.each_char.to_h { [it.ord, it.freeze] }.freeze

  # Bytes that can start whitespace or a comment: ASCII whitespace, `/`, and
  # the first byte of a non-ASCII character (which may be a space)
  SKIP_START = Array.new(256, false).tap do |starts|
    [9, 10, 11, 12, 13, 32, '/'.ord, *0x80..0xFF].each { starts[it] = true }
  end.freeze

  DIGIT = Array.new(256, false).tap { |digits| ('0'..'9').each { digits[it.ord] = true } }.freeze

  # The most recently consumed token
  attr_reader :last

  # The `#!` line at the start of the source, if there is one
  attr_reader :hashbang

  def initialize(source)
    @source = source
    @scanner = StringScanner.new(source)
    @hashbang = @scanner.scan(/#![^\n]*/) # e.g. #!/usr/bin/env node
    # Tokens read but not consumed, the next first; the scanner is after the
    # last of them
    @buffer = []
    @last = nil
  end

  # The next token, without consuming it
  def peek(regex: false)
    if (token = @buffer.first)
      # A token read as `/` (division) is a regex in the other mode, and
      # the other way around, so read it and what follows again
      return token unless token.regex != regex && slash?(token)
      @scanner.pos = token.lex_start
      @buffer.clear
    end

    token = lex(regex)
    @buffer << token
    token
  end

  # Consumes and returns the next token
  def next(regex: false)
    token = peek(regex: regex)
    @buffer.shift
    @last = token
  end

  # Puts back `token`, the most recently consumed one (or, after putting
  # that back, the one before it), so that it's the next token again
  def unread(token)
    @buffer.unshift(token)
  end

  # Reads template literal text, after the opening backtick or the `}` that
  # ends an interpolation. Returns the text and whether an interpolation
  # (`${`) or the end of the template (:end) follows.
  def template_chunk
    unless @buffer.empty?
      @scanner.pos = @buffer.first.lex_start
      @buffer.clear
    end

    text = @scanner.scan(TEMPLATE_TEXT)
    if @scanner.skip(/\$\{/)
      [text, :interpolation]
    elsif @scanner.skip(/`/)
      [text, :end]
    else
      raise syntax_error("unterminated template literal", @scanner.pos)
    end
  end

  # A JSParser::SyntaxError at `position`, with the line and column and the
  # source around it
  def syntax_error(message, position = @scanner.pos)
    before = @source.byteslice(0, [position, @source.bytesize].min)
    after = @source.byteslice(before.bytesize..)
    line = before.count("\n") + 1
    line_before = before[((before.rindex("\n") || -1) + 1)..]
    line_after = after[/\A[^\n]*/]

    # Show at most 80 characters either side, so minified files stay readable
    shown_before = line_before[-80..] || line_before
    JSParser::SyntaxError.new(
      "#{message} at #{line}:#{line_before.size + 1}\n  #{shown_before}#{line_after[0, 80]}\n  #{' ' * shown_before.size}^"
    )
  end

  private

  SLASHES = %w(/ /=).freeze

  def slash?(token)
    token.type == :regex || token.punctuator_in?(SLASHES)
  end

  SLASH = '/'.ord

  # Whether the source from `from` up to `to` has a line break (\n, \r, or
  # U+2028/U+2029, which are E2 80 A8/A9 in UTF-8), and whether it has a `/`
  # (so possibly a comment). Looks at the bytes so skipping whitespace
  # doesn't allocate a string.
  def scan_skipped(from, to)
    newline = slash = false
    i = from
    while i < to
      byte = @source.getbyte(i)
      if byte == 10 || byte == 13
        newline = true
      elsif byte == SLASH
        slash = true
      elsif byte == 0xE2 && @source.getbyte(i + 1) == 0x80 && (@source.getbyte(i + 2) | 1) == 0xA9
        newline = true
      end
      i += 1
    end
    [newline, slash]
  end

  # The comments in the skipped source from `from` up to `to`. A comment is
  # trailing if no line break comes between the code before it and it.
  def comments_between(from, to)
    skipped = @source.byteslice(from, to - from)
    comments = []
    skipped.scan(COMMENT) do
      offset = from + $~.bytebegin(0)
      trailing = !scan_skipped(from, offset)[0]
      comments << JSParser::Node::Comment.new($~[0], offset...(offset + $~[0].bytesize), trailing: trailing)
    end
    comments
  end

  # The punctuator at `start`, moving past it, or nil
  def lex_punctuator(start)
    PUNCTUATOR_CANDIDATES[@source.getbyte(start)]&.each do |punctuator, bytes|
      # A plain loop: an enumerator here allocated more than anything else
      size = bytes.size
      i = 1
      i += 1 while i < size && @source.getbyte(start + i) == bytes[i]
      next unless i == size
      # `?.` isn't optional chaining before a digit: `a?.5:1` is a ternary
      next if punctuator == '?.' && DIGIT[@source.getbyte(start + 2) || 0]

      @scanner.pos = start + bytes.size
      return punctuator
    end
    nil
  end

  def lex(regex)
    lex_start = @scanner.pos
    @scanner.skip(SKIP) if SKIP_START[@source.getbyte(lex_start) || 0]
    start = @scanner.pos
    newline = false
    comments = nil
    if start > lex_start
      newline, slash = scan_skipped(lex_start, start)
      comments = comments_between(lex_start, start) if slash
    end
    byte = @source.getbyte(start)
    return Token.new(:eof, nil, start, start, newline, lex_start, regex, comments) unless byte

    type = :punctuator
    value = case BYTE_CLASS[byte]
    when :name
      type = :name
      @scanner.scan(NAME)
    when :single
      @scanner.pos = start + 1
      SINGLE_PUNCTUATORS[byte]
    when :number
      type = :number
      @scanner.scan(NUMBER)
    when :dot
      if DIGIT[@source.getbyte(start + 1) || 0]
        type = :number
        @scanner.scan(NUMBER)
      else
        lex_punctuator(start)
      end
    when :slash
      raise syntax_error("unterminated comment") if @source.getbyte(start + 1) == 0x2A # /*
      if regex && (re = @scanner.scan(REGEX))
        type = :regex
        re
      else
        lex_punctuator(start)
      end
    when :string
      type = :string
      @scanner.scan(STRING) || raise(syntax_error("unterminated string"))
    when :template
      type = :template
      @scanner.pos = start + 1
      '`'
    when :hash
      type = :private_name
      @scanner.scan(PRIVATE_NAME)
    else
      lex_punctuator(start)
    end
    raise syntax_error("unexpected #{@source.byteslice(start, 4).scrub[0].inspect}") unless value

    Token.new(type, value, start, @scanner.pos, newline, lex_start, regex, comments)
  end

end
