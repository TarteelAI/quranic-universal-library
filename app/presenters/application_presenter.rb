class ApplicationPresenter
  MAX_RECORDS_PER_PAGE = 50

  include Pagy::Backend
  attr_reader :params,
              :pagination,
              :lookahead,
              :context,
              :resource

  def initialize(context)
    @context = context
    @params = context.params
    @lookahead = Api::ParamLookahead.new(params)
  end

  def action_name
    context.action_name
  end

  def index?
    action_name == 'index'
  end

  def show?
    action_name == 'show'
  end

  def set_resource(resource)
    @resource = resource
  end

  def page_number
    (params[:page_number] || '1').to_i.abs
  end

  def meta_tags
    {
      title: meta_title,
      description: meta_description,
      keywords: meta_keywords,
      image: og_image
    }
  end

  def meta_title
    'Quranic Universal Library'
  end

  def meta_description
    'A comprehensive collection of Quranic digital resources'
  end

  def meta_keywords
    'quran, islamic tools, muslim developers, quran api, quranic library'
  end

  def og_image
    'https://static-cdn.tarteel.ai/qul/og.jpeg'
  end

  protected
  def paginate(list, items: per_page)
    @pagination, list = pagy(list, items: items)
    list
  end

  def current_page
    params[:page].to_i.abs.positive? ? params[:page].to_i : 1
  end

  def mushaf_id
    params[:mushaf] || 5
  end

  def per_page
    items = params[:per_page].to_i.abs
    [items | 10, MAX_RECORDS_PER_PAGE].min
  end
end