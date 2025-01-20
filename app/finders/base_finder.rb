class BaseFinder
  attr_reader :params,
              :lookahead

  def initialize(params = {})
    @params = params
    @lookahead = Api::ParamLookahead.new(params)
  end
end