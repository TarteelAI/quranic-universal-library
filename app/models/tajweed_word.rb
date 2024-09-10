class TajweedWord < QuranApiRecord
  belongs_to :mushaf
  belongs_to :word

  after_commit :update_word_text_if_letters_changed

  def humanize
    location
  end

  def update_word_text!
    update_column(:text, prepare_text_from_rule)
  end

  def prepare_text_from_rule(tag = 'r')
    text = []
    current_rule = nil
    current_group = ""

    letters.each do |l|
      if l['r'] == current_rule
        current_group << l['c']
      else
        if current_group.present?
          if current_rule
            text << "<#{tag} class=#{TajweedRules.name(current_rule)}>#{current_group}</#{tag}>"
          else
            text << current_group
          end
        end

        if l['r']
          current_rule = l['r']
          current_group = l['c']
        else
          text << l['c']
          current_rule = nil
          current_group = ""
        end
      end
    end

    if current_rule
      text << "<#{tag} class=#{TajweedRules.name(current_rule)}>#{current_group}</#{tag}>"
    else
      text << current_group
    end

    text.join('')
  end

  def update_word_text_if_letters_changed
    if previous_changes.key?('letters')
      update_word_text!
    end
  end
end
