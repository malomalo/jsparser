# `this`, `super`, `null`, and `import` (as in import() and import.meta),
# which look like variables but aren't
class JSParser::Node::Keyword

  attr_reader :keyword

  def initialize(keyword)
    @keyword = keyword
  end

  def to_js(indentation="")
    @keyword.dup
  end

end

# A private class member name used on its own, as in `#x in obj`
class JSParser::Node::PrivateName

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def to_js(indentation="")
    @name.dup
  end

end
