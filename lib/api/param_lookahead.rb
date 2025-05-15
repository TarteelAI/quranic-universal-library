class Api::ParamLookahead
  attr_reader :params

  # A singleton, so that misses don't come with overhead.
  def null_lookahead
    @null_lookahead ||= Api::NullLookahead.new
  end

  def initialize(params)
    @params = params
  end

  def selected?
    params.present?
  end

  def selects?(attribute)
    selection(attribute).selected?
  end

  def selection(attribute)
    query = params[attribute]

    if query
      case query
      when Hash
        Api::ParamLookahead.new(params[attribute])
      when String, Symbol, TrueClass, FalseClass
        if ActiveRecord::Type::Boolean::FALSE_VALUES.include?(query)
          null_lookahead
        else
          Api::ParamLookahead.new(query)
        end
      when Array
        Api::ParamLookahead.new(query)
      end
    else
      null_lookahead
    end
  end
end