class MushafLayoutsController < CommunityController
  include ActiveStorage::SetCurrent

  before_action :authenticate_user!, except: [:index, :show]
  before_action :authorize_access!, only: [:update, :save_page_mapping, :save_line_alignment, :edit]

  def index
  end

  def show
    modal_views = ['select_compare', 'select_page']
    if modal_views.include?(params[:view_type].to_s)
      render partial: params[:view_type], layout: false
    elsif params[:page_number].present?
      render 'show_page'
    end
  end

  def save_line_alignment
    @words = @presenter.words

    @record = MushafLineAlignment.where(
      mushaf_id: @presenter.mushaf.id,
      page_number: params[:page_number],
      line_number: params[:line]
    ).first_or_initialize

    alignment = get_alignment(params[:commit])

    if !['center', 'bismillah', 'surah_name'].include?(alignment) || @record.alignment == alignment
      # We don't need to save justified lines, by default all lines are justified
      # clicking same alignment should remove the data(there is no other way of clear the miss-click)
      @record.destroy if @record.persisted?
    else
      @record.alignment = alignment if @record.alignment.blank?
      @record.set_meta_value(alignment, true)

      @record.save(validate: false)

      if @record.is_surah_name?
        @presenter.mushaf.update_surah_numbers_in_layout
      end
    end
  end

  def save_page_mapping
    @mushaf_page = @presenter.mushaf_page
    @mushaf_page.attributes = params_for_page_mapping
    @mushaf_page.save(validate: false)
    @mushaf_page.reload
    @pages = [@mushaf_page]
    @words = @presenter.words
    @words_counts = { @mushaf_page.page_number => @words.count }
    @lines_counts = { @mushaf_page.page_number => @words.where.not(line_number: [0, nil]).count }

    flash[:notice] = "Page #{@mushaf_page.page_number} is saved"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to mushaf_layout_path(@presenter.mushaf.id, page_number: @mushaf_page.page_number) }
    end
  end

  def edit
    @lines_per_page = @presenter.lines_per_page
    @verses = @presenter.verses
    @ayah_range_missing = @presenter.ayah_range_missing?
    @words = @presenter.words unless @ayah_range_missing
  end

  def update
    MushafLayoutJob.perform_now(@presenter.resource.resource_id, page_number, layout_params.to_json)
    @presenter.reload_mushaf_page!
    @words = @presenter.words
    flash[:notice] = "Saved successfully, please verify the layout before moving to next page"
  rescue Exception => e
    File.open("data/mapping-#{@presenter.resource.resource_id}-#{page_number}.json", "wb") do |f|
      f << "MushafLayoutJob.perform_now(#{@presenter.resource.resource_id}, #{page_number},#{layout_params.to_json.to_json})"
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

  def page_number
    (params[:page_number] || 1).to_i
  end

  def authorize_access!
    if @presenter.resource.blank? || !can_manage?(@presenter.resource)
      redirect_to mushaf_layout_path(@presenter.resource.id, mushaf_id: @presenter.resource.id, page_number: page_number), alert: "Sorry you don't have access to this resource"
    end
  end

  def load_resource_access
    @access = can_manage?(@presenter.resource)
  end

  def params_for_page_mapping
    mapping = params.require('mushaf_page').permit(:first_verse_id, :last_verse_id)

    mapping['first_verse_id'] = Utils::Quran.get_ayah_id_from_key(mapping['first_verse_id'])
    mapping['last_verse_id'] = Utils::Quran.get_ayah_id_from_key(mapping['last_verse_id'])

    mapping
  end

  def init_presenter
    @presenter = MushafLayoutPresenter.new(self)
  end
end