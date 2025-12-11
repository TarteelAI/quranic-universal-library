class WordMistakesController < AdminsController
  before_action :set_mushaf
  before_action :set_page_number

  def show
    @words = MushafWord.where(
      mushaf_id: @mushaf.id,
      page_number: @page_number
    ).order('position_in_page ASC')

    word_ids = @words.pluck(:word_id)
    @mistakes = WordMistake.where(word_id: word_ids)
                           .group_by(&:word_id)
  end

  def edit
    @words = MushafWord.where(
      mushaf_id: @mushaf.id,
      page_number: @page_number
    ).order('position_in_page ASC')

    word_ids = @words.pluck(:word_id)
    @mistakes = WordMistake.where(word_id: word_ids)
                           .group_by(&:word_id)
  end

  def update
    mistakes_params = params[:mistakes] || {}

    WordMistake.transaction do
      mistakes_params.each do |key, mistake_data|
        next unless mistake_data.is_a?(ActionController::Parameters) || mistake_data.is_a?(Hash)
        
        word_id, char_start, char_end = parse_mistake_key(key)
        
        if char_start.present? && char_end.present?
          char_start, char_end = [char_start, char_end].minmax
        end
        
        mistake_count = mistake_data[:mistake_count]&.to_i || 0
        
        if mistake_count > 0
          mistake = WordMistake.find_or_initialize_by(
            word_id: word_id,
            char_start: char_start,
            char_end: char_end
          )
          
          mistake.assign_attributes(mistake_count: mistake_count)
          mistake.save!
        else
          WordMistake.where(
            word_id: word_id,
            char_start: char_start,
            char_end: char_end
          ).or(
            WordMistake.where(
              word_id: word_id,
              char_start: char_end,
              char_end: char_start
            )
          ).destroy_all
        end
      end
    end

    respond_to do |format|
      format.html { redirect_to mistake_heatmap_path(page: @page_number), notice: 'Mistakes saved successfully.' }
      format.json { head :ok }
    end
  rescue => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Error saving mistakes: #{e.message}"
        redirect_to edit_mistake_heatmap_path(page: @page_number)
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def set_mushaf
    @mushaf = Mushaf.find(5)
  end

  def set_page_number
    @page_number = params[:page]&.to_i || 1
  end

  def parse_mistake_key(key)
    parts = key.split('_')
    word_id = parts[0].to_i
    char_start = parts[1] == 'nil' ? nil : parts[1].to_i
    char_end = parts[2] == 'nil' ? nil : parts[2].to_i
    
    [word_id, char_start, char_end]
  end
end
