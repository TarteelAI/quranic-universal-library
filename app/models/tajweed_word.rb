# == Schema Information
#
# Table name: tajweed_words
#
#  id         :bigint           not null, primary key
#  letters    :jsonb
#  location   :string
#  position   :integer
#  text       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  mushaf_id  :bigint           not null
#  verse_id   :bigint           not null
#  word_id    :bigint           not null
#
# Indexes
#
#  index_tajweed_words_on_location   (location)
#  index_tajweed_words_on_mushaf_id  (mushaf_id)
#  index_tajweed_words_on_position   (position)
#  index_tajweed_words_on_verse_id   (verse_id)
#  index_tajweed_words_on_word_id    (word_id)
#
# Foreign Keys
#
#  fk_rails_...  (mushaf_id => mushafs.id)
#  fk_rails_...  (verse_id => verses.id)
#  fk_rails_...  (word_id => words.id)
#
class TajweedWord < QuranApiRecord
  belongs_to :mushaf
  belongs_to :word
  belongs_to :verse
  belongs_to :resource_content

  scope :rule_eq, lambda { |rule|
    where("EXISTS (SELECT 1 FROM jsonb_array_elements(letters) AS elem WHERE elem->>'r' = '#{rule}')")
  }

  after_commit :update_word_text_if_letters_changed

  def self.ransackable_scopes(*)
    %i[rule_eq]
  end

  def has_tajweed_rule?
    letter = letters.detect do|l|
      l['r'].present?
    end

    !!letter
  end

  def update_letter_rule(letter_index, rule_id)
    letter = letters[letter_index.to_i]
    letter['r'] = rule_id
    save

    letter
  end

  def humanize
    location
  end

  def update_word_text!
    tajweed_text = prepare_text_from_rule
    update_column(:text, tajweed_text)
    word.update(text_qpc_hafs_tajweed: tajweed_text)
  end

  def prepare_text_from_rule(tag = 'r')
    text = []
    current_rule = nil
    current_group = ""
    tajweed = TajweedRules.new('new')

    letters.each do |l|
      next if l['c'].blank?

      if l['r'] == current_rule
        current_group << l['c']
      else
        if current_group.present?
          if current_rule
            text << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
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
      text << "<#{tag} class=#{tajweed.name(current_rule)}>#{current_group}</#{tag}>"
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
