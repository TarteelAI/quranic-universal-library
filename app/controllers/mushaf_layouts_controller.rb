class MushafLayoutsController < CommunityController
  include ActiveStorage::SetCurrent

  before_action :find_resource
  before_action :authenticate_user!, only: [:update, :save_page_mapping, :save_line_alignment, :edit]
  before_action :load_mushaf_page, only: [:show, :save_page_mapping, :edit, :save_line_alignment]
  before_action :authorize_access!, only: [:update, :save_page_mapping, :save_line_alignment, :edit]
  before_action :load_page_words, only: [:edit, :show, :save_line_alignment]
  before_action :init_presenter

  def index
    @mushafs = Mushaf.order("#{sort_key} #{sort_order}")
  end

  def save_line_alignment
    @record = MushafLineAlignment.where(
      mushaf_id: @mushaf.id,
      page_number: params[:page_number],
      line_number: params[:line]
    ).first_or_initialize

    alignment = get_alignment(params[:commit])

    if !['center', 'bismillah', 'surah_name'].include?(alignment) || @record.alignment == alignment
      # We don't need to save justified lines, by default all lines are justified
      # clicking same alignment should remove the data(there is no other way of clear the miss-click)
      @record.clear! if @record.persisted?
    else
      @record.alignment = alignment if @record.alignment.blank?
      @record.set_meta_value(alignment, true)

      @record.save(validate: false)

      if @record.is_surah_name?
        @mushaf.update_surah_numbers_in_layout
      end
    end
  end

  def save_page_mapping
    @mushaf_page.attributes = params_for_page_mapping
    @mushaf_page.save(validate: false)
    flash[:notice] = "Page #{@mushaf_page.page_number} is saved"
  end

  def show
    @access = can_manage?(@resource)
    @presenter.set_resource(@resource)

    if params[:view_type] == 'select_compare'
      render partial: 'select_compare', layout: false
    elsif params[:view_type] == 'select_page'
      render partial: 'select_page', layout: false
    end
  end

  def edit
    @lines_per_page = @resource.resource.lines_per_page

    first_verse = @mushaf_page.first_verse
    last_verse = @mushaf_page.last_verse

    if first_verse.nil? || last_verse.nil?
      return redirect_to mushaf_layout_path(@mushaf.id, page_number: page_number, mapping: true), alert: "Please fix the ayah range for #{page_number} before editing the layout"
    end
    @verses = Verse.eager_load(:words).order("verses.verse_index asc, words.position asc").where("verse_index >= ? AND verse_index <= ?", first_verse.verse_index, last_verse.verse_index)
  end

  def update
    MushafLayoutJob.perform_now(@resource.resource_id, page_number, layout_params.to_json)
    load_mushaf_page
    load_page_words
    flash[:notice] = "Saved successfully, please verify the layout before moving to next page"
  rescue Exception => e
    File.open("data/mapping-#{@resource.resource_id}-#{page_number}.json", "wb") do |f|
      f << "MushafLayoutJob.perform_now(#{@resource.resource_id}, #{page_number},#{layout_params.to_json.to_json})"
    end
  end

  protected

  def get_alignment(alignment)
    {
      c: 'center',
      n: 'surah_name',
      b: 'bismillah'
    }[alignment.to_s.downcase.to_sym]
  end

  def layout_params
    params.require(:layout).permit(words: {}).to_h
  end

  def load_page_words
    @words = MushafWord.where(
      mushaf_id: @resource.resource_id,
      page_number: page_number
    ).order('position_in_page ASC')

    if @compared_mushaf
      @compare_mushaf_words = MushafWord
                                .where(
                                  mushaf_id: @compared_mushaf.id,
                                  page_number: page_number
                                ).order('position_in_page ASC')
    end
  end

  def page_number
    (params[:page_number] || 1).to_i
  end

  def authorize_access!
    if @resource.blank? || !can_manage?(@resource)
      redirect_to mushaf_layout_path(@resource.id, mushaf_id: @resource.id, page_number: page_number), alert: "Sorry you don't have access to this resource"
    end
  end

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def find_resource
    return @resource if @resource

    if params[:id]
      @mushaf = Mushaf.find(params[:id])
      @resource = @mushaf.resource_content

      if params[:compare].present?
        @compared_mushaf = Mushaf.find(params[:compare])
      end
    end
  end

  def params_for_page_mapping
    mapping = params.require('mushaf_page').permit(:first_verse_id, :last_verse_id)

    mapping['first_verse_id'] = Utils::Quran.get_ayah_id_from_key(mapping['first_verse_id'])
    mapping['last_verse_id'] = Utils::Quran.get_ayah_id_from_key(mapping['last_verse_id'])

    mapping
  end

  def load_mushaf_page
    @mushaf_page = MushafPage.where(mushaf_id: @mushaf.id, page_number: page_number).first_or_initialize

    if @compared_mushaf
      @compare_mushaf_page = MushafPage.where(mushaf_id: @compared_mushaf.id, page_number: page_number).first
    end
  end

  def sort_key
    sortby = params[:sort_keyby] || 'id'

    if ['id', 'name'].include?(sortby)
      sortby
    else
      'id'
    end
  end

  def init_presenter
    @presenter = MushafLayoutPresenter.new(self)
  end
end