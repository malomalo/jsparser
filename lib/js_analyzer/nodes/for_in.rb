class JSAnalyzer::Node::ForIn

  attr_accessor :left, :kind, :right, :body, :await

  # kind is "in" or "of"; await is true for `for await (... of ...)`
  def initialize(left, kind, right, body=[], await: false)
    @left = left
    @kind = kind
    @right = right
    @body = body
    @await = await
  end

  def to_js(indentation="")
    "for #{'await ' if @await}(#{@left.to_js} #{@kind} #{@right.to_js}) #{JSAnalyzer::Node.block_to_js(@body, indentation)}"
  end

end
