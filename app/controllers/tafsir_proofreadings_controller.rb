class TafsirProofreadingsController < CommunityController
  before_action :normalize_page_param, only: %i[index]
  before_action :load_resource_access
  before_action :authenticate_user!, only: %i[edit update new create]
  before_action :authorize_access!, only: %i[edit update new create]

  def show
    #TODO: use presenter to load data
    @tafisr = find_tafsir(@resource)

    # Ayah without tafsir, offer to add one
    render :missing if @tafisr.nil?
  end

  def new
    @tafisr = build_tafsir
  end

  def create
    @tafisr = build_tafsir

    if @tafisr.save_suggestions(tafsir_params, current_user)
      redirect_to tafsir_proofreading_path(0, resource_id: @resource.id, verse_key: @tafisr.verse.verse_key),
                  notice: "Your tafsir is saved and will show here once it's approved"
    else
      keep_submitted_values(@tafisr)
      render :new, status: :unprocessable_entity
    end
  end

  # What the new ayah range does to the other tafsirs, shown while editing
  def range_preview
    @tafisr = if params[:tafsir_id].present?
                Tafsir.where(resource_content_id: @resource.id).find(params[:tafsir_id])
              else
                Tafsir.new(resource_content_id: @resource.id)
              end
    @range_change = @tafisr.range_change_for(params[:start_verse_id], params[:end_verse_id])

    render layout: false
  end

  def edit
    @tafisr = find_tafsir(@resource)
  end

  def update
    @tafisr = find_tafsir(@resource)

    if @tafisr.save_suggestions(tafsir_params, current_user)
      redirect_to tafsir_proofreading_path(@tafisr.id, verse_id: @tafisr.group_tafsir_id, resource_id: @resource.id),
                  notice: "Your suggestions are saved successfully"
    else
      keep_submitted_values(@tafisr)
      render :edit, status: :unprocessable_entity
    end
  end

  def index
    @tafsir_list = ResourceContent.tafsirs

    @pagy, @ayah_tafisrs = pagy(filter_tafsirs(@resource))
  end

  protected

  def verse_id
    if params[:verse_id].present?
      params[:verse_id].to_i
    elsif params[:verse_key].present?
      Utils::Quran.get_ayah_id_from_key(params[:verse_key])
    elsif chapter_number && verse_number
      Utils::Quran.get_ayah_id_from_key("#{chapter_number}:#{verse_number}")
    end
  end

  def chapter_number
    params[:filter_chapter].to_i if params[:filter_chapter].present?
  end

  def verse_number
    params[:verse_number].to_i if params[:verse_number].present?
  end

  def tafsir_params
    params
      .require(:tafsir)
      .permit(:text, :start_verse_id, :end_verse_id, :comment)
  end

  def find_resource
    return @resource if @resource

    if params[:id].to_i.positive?
      @resource = Tafsir.find(params[:id]).get_resource_content
    else
      params[:resource_id] ||= 169
      @resource = ResourceContent.find(params[:resource_id])
    end

    @presenter.set_resource(@resource)
  end

  def load_resource_access
    @access = can_manage?(find_resource)
  end

  def filter_tafsirs(resource)
    tafsirs = Tafsir.where(resource_content_id: resource.id, archived: false)

    if verse_id
      tafsirs = tafsirs
                  .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse_id)
    elsif chapter_number
      tafsirs = tafsirs.where(chapter_id: chapter_number)
    end

    if params[:query].present?
      tafsirs = tafsirs.text_search(params[:query])
    end

    tafsirs.order("#{sort_key} #{sort_order}")
  end

  # nil when the ayah has no tafsir
  def find_tafsir(resource)
    if params[:verse_key]
      raise(ActiveRecord::RecordNotFound, "Ayah #{params[:verse_key]} not found") unless verse_id

      filter_tafsirs(resource).first
    else
      Tafsir.where(resource_content_id: resource.id).find(params[:id])
    end
  end

  # Show what the user typed again when the suggestion is rejected
  def keep_submitted_values(tafsir)
    tafsir.text = tafsir_params[:text]
    ids = Verse.where(id: [tafsir_params[:start_verse_id], tafsir_params[:end_verse_id]]).ids
    tafsir.start_verse_id = tafsir_params[:start_verse_id] if ids.include?(tafsir_params[:start_verse_id].to_i)
    tafsir.end_verse_id = tafsir_params[:end_verse_id] if ids.include?(tafsir_params[:end_verse_id].to_i)
  end

  # A new tafsir for an ayah without one, starts and ends on that ayah
  def build_tafsir
    verse = Verse.find(params.dig(:tafsir, :start_verse_id).presence || verse_id)
    tafsir = Tafsir.new(resource_content_id: @resource.id, verse: verse, chapter_id: verse.chapter_id)
    tafsir.start_verse_id = verse.id
    tafsir.end_verse_id = verse.id
    tafsir
  end

  def sort_key
    sort_by = params[:sort_key].to_s.presence || 'id'

    if ['id', 'group_verse_key_from', 'group_verses_count', 'group_verse_key_to'].include?(sort_by)
      sort_by
    else
      'verse_id'
    end
  end

  def init_presenter
    @presenter = TafsirPresenter.new(self)
  end
end
