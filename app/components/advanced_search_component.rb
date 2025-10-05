class AdvancedSearchComponent < ViewComponent::Base
  def initialize(search_params: {})
    @search_params = search_params.with_indifferent_access
  end

  private

  attr_reader :search_params

  def search_types
    [
      ['Combined Search', 'combined'],
      ['Text Search', 'text'],
      ['Morphology Search', 'morphology'],
      ['Semantic Search', 'semantic'],
      ['Root Search', 'root'],
      ['Lemma Search', 'lemma'],
      ['Stem Search', 'stem'],
      ['Pattern Search (Regex)', 'pattern'],
      ['Script-Specific Search', 'script_specific']
    ]
  end

  def arabic_scripts
    [
      ['QPC Hafs (Default)', 'qpc_hafs'],
      ['Uthmani', 'uthmani'],
      ['Imlaei', 'imlaei'],
      ['Indo-Pak', 'indopak'],
      ['QPC Nastaleeq', 'qpc_nastaleeq'],
      ['Uthmani Simple', 'uthmani_simple']
    ]
  end

  def morphology_categories
    [
      ['Noun (اسم)', 'noun'],
      ['Verb (فعل)', 'verb'],
      ['Particle (حرف)', 'particle'],
      ['Pronoun (ضمير)', 'pronoun'],
      ['Proper Noun', 'proper_noun'],
      ['Adjective', 'adjective']
    ]
  end

  def chapters_for_select
    @chapters_for_select ||= Chapter.order(:chapter_number).pluck(:name_simple, :id)
  end

  def current_query
    search_params[:query] || ''
  end

  def current_type
    search_params[:type] || 'combined'
  end

  def current_script
    search_params[:script] || 'qpc_hafs'
  end

  def current_morphology_category
    search_params[:morphology_category] || ''
  end

  def current_chapter_id
    search_params[:chapter_id] || ''
  end

  def include_translations?
    search_params[:include_translations] != 'false'
  end

  def include_tafsirs?
    search_params[:include_tafsirs] == 'true'
  end
end