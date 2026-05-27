class ApplicationPresenter
  MAX_RECORDS_PER_PAGE = 50

  include Pagy::Backend
  attr_reader :params,
              :pagination,
              :lookahead,
              :context,
              :resource

  attr_accessor :translated_names_cache


  def initialize(context)
    @context = context
    @params = context.params
    @lookahead = Api::ParamLookahead.new(params)
    @translated_names_cache = {}
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
    params[:page] || '1'
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
    'Quranic Universal Library — Download Quran Data, JSON & APIs'
  end

  def meta_description
    'Download free Quran data as JSON — translations, tafsir, word-by-word, audio recitations and Uthmani/IndoPak scripts — plus developer tools and APIs from the Quranic Universal Library.'
  end

  def meta_keywords
    'quran data, quran json data, quran json, download quran data, quran database, quran translations json, quran tafsir json, uthmani script json, indopak script, quran word by word data, quran audio recitation data, quran api, quranic library, islamic developer tools'
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

  def sort_order
    s = (params[:sort_order].presence || 'asc').downcase

    if ['asc', 'desc'].include?(s)
      s
    else
      'asc'
    end
  end
end