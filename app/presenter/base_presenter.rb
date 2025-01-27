class BasePresenter
  attr_reader :context

  def initialize(context)
    @context = context
  end
  delegate :params, :h, to: :context
end