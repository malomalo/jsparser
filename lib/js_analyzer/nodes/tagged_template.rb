# tag`template`
class JSAnalyzer::Node::TaggedTemplate

  attr_reader :tag, :template

  def initialize(tag, template)
    @tag = tag
    @template = template
  end

  def to_js(indentation="")
    "#{@tag.to_js}#{@template.to_js}"
  end

end
