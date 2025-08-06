class ResourcesPresenter < BasePresenter
  def initialize(params, resource = nil)
    super(params)
    @resource = resource
  end

  def meta_title
    prefix = if @resource
               @resource.name
             elsif @params[:id].present?
               @params[:id].to_s.humanize
             else
               'Quranic Resources'
             end
    "#{prefix}"
  end

  def meta_description
    if @resource
      @resource.respond_to?(:description) && @resource.description.present? ?
        @resource.description :
        super
    elsif @params[:id].present?
      type_desc = {
        'recitations'      => 'Listen to diverse Quranic recitations by renowned Qaris with adjustable audio clarity and variable playback speeds for personalized study.',
        'tafsir'           => 'Comprehensive Quranic exegesis detailing contextual insights and verse-by-verse explanations for deeper understanding.',
        'quran-script'     => 'Explore high-resolution Quranic Arabic scripts with authentic orthography and clear calligraphy for precise reading.',
        'font'             => 'Browse and download elegant, Quran-specific Arabic fonts optimized for readability and beautification across all devices.',
        'quran-metadata'   => 'Access detailed Quranic metadata including chapter and verse indices, classification, and structural information.',
        'similar-ayah'     => 'Discover verses with similar linguistic patterns and themes to enhance study and reflection on related passages.',
        'ayah-theme'       => 'Explore thematic categorization of Quranic verses for focused study on moral lessons and key topics.',
        'mutashabihat'     => 'Study the ambiguous (Mutashabihat) verses alongside scholarly interpretations for comprehensive comprehension.',
        'ayah-topics'      => 'Browse Quranic verses organized by topics to quickly find guidance on specific subjects and themes.',
        'transliteration'   => 'Read accurate transliterations of Quranic Arabic in Latin script to aid pronunciation and memorization of verses.'
      }
      type_desc[@params[:id]] || super
    else
      'Explore a curated collection of Quranic digital resources including recitations, tafsir, metadata, themes, and more — designed for developers, researchers, and students.'
    end
  end

  def meta_keywords
    base_keywords = super
    seo_defaults = 'quran resources, tafsir resources, transaltions, quran translations, quran recitations'
    keywords = [base_keywords, seo_defaults]
    if @resource
      tags = @resource.downloadable_resource_tags.pluck(:name)
      keywords << tags.join(', ')
    elsif @params[:id].present?
      keywords << @params[:id].to_s
    end
    keywords.join(', ').split(', ').map(&:strip).uniq.join(', ')
  end
end