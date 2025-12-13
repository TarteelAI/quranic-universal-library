class WordMistakeUpdatePresenter
  attr_reader :success, :error_message

  def initialize(mistakes_params, page_number)
    @mistakes_params = mistakes_params || {}
    @page_number = page_number
    @success = false
    @error_message = nil
  end

  def update!
    WordMistake.transaction do
      @mistakes_params.each do |key, mistake_data|
        next unless mistake_data.is_a?(ActionController::Parameters) || mistake_data.is_a?(Hash)
        
        word_id, char_start, char_end = parse_mistake_key(key)
        
        if char_start.present? && char_end.present?
          char_start, char_end = [char_start, char_end].minmax
        end
        
        frequency = mistake_data[:frequency]&.to_f
        frequency = nil if frequency && frequency <= 0
        
        if frequency && frequency > 0
          mistake = WordMistake.find_or_initialize_by(
            word_id: word_id,
            char_start: char_start,
            char_end: char_end
          )
          
          mistake.assign_attributes(frequency: frequency)
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
      
      @success = true
    end
  rescue => e
    @success = false
    @error_message = e.message
    raise
  end

  private

  def parse_mistake_key(key)
    parts = key.split('_')
    word_id = parts[0].to_i
    char_start = parts[1] == 'nil' ? nil : parts[1].to_i
    char_end = parts[2] == 'nil' ? nil : parts[2].to_i
    
    [word_id, char_start, char_end]
  end
end
