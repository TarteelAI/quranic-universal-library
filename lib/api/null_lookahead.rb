class Api::NullLookahead < Api::ParamLookahead
  # No inputs required here.
  def initialize
  end

  def selected?
    false
  end

  def selects?(*)
    false
  end

  def selection(*)
    null_lookahead
  end

  def selections(*)
    []
  end

  def inspect
    '#<Api::NullLookahead>'
  end
end