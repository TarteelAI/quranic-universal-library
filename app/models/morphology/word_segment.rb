# == Schema Information
#
# Table name: morphology_word_segments
#
#  id                        :bigint           not null, primary key
#  grammar_term_desc_arabic  :string
#  grammar_term_desc_english :string
#  grammar_term_key          :string
#  grammar_term_name         :string
#  hidden                    :boolean
#  lemma_name                :string
#  part_of_speech_key        :string
#  part_of_speech_name       :string
#  pos_tags                  :string
#  position                  :integer
#  root_name                 :string
#  text_uthmani              :string
#  verb_form                 :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  grammar_concept_id        :bigint
#  grammar_role_id           :bigint
#  grammar_sub_role_id       :bigint
#  grammar_term_id           :bigint
#  lemma_id                  :bigint
#  root_id                   :bigint
#  topic_id                  :bigint
#  word_id                   :bigint
#
# Indexes
#
#  index_morphology_word_segments_on_grammar_concept_id   (grammar_concept_id)
#  index_morphology_word_segments_on_grammar_role_id      (grammar_role_id)
#  index_morphology_word_segments_on_grammar_sub_role_id  (grammar_sub_role_id)
#  index_morphology_word_segments_on_grammar_term_id      (grammar_term_id)
#  index_morphology_word_segments_on_lemma_id             (lemma_id)
#  index_morphology_word_segments_on_part_of_speech_key   (part_of_speech_key)
#  index_morphology_word_segments_on_pos_tags             (pos_tags)
#  index_morphology_word_segments_on_position             (position)
#  index_morphology_word_segments_on_root_id              (root_id)
#  index_morphology_word_segments_on_topic_id             (topic_id)
#  index_morphology_word_segments_on_word_id              (word_id)
#
# Foreign Keys
#
#  fk_rails_...  (lemma_id => lemmas.id)
#  fk_rails_...  (root_id => roots.id)
#  fk_rails_...  (topic_id => topics.id)
#  fk_rails_...  (word_id => words.id)
#

class Morphology::WordSegment < QuranApiRecord
  belongs_to :word, class_name: 'Morphology::Word'
  belongs_to :grammar_concept, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_sub_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_term, class_name: 'Morphology::GrammarTerm', optional: true

  belongs_to :root, optional: true
  belongs_to :topic, optional: true
  belongs_to :lemma, optional: true
  default_scope { order 'position asc' }

  def is_prefix?
    has_pos_feature? 'PREF'
  end

  def humanize
    "#{location} - #{text_uthmani}"
  end

  def location
    "#{word.location}:#{position}"
  end

  def preposition?
    part_of_speech_key == 'P'
  end

  def has_pos_feature?(feature)
    if pos_features.include?(feature)
      true
    else
      if feature == 'P' && part_of_speech_key == 'N'
        # https://github.com/mustafa0x/quran-morphology/commit/8f38b39016824284f9ed16ae15069ff9102c4acf
        pos_features.include? 'LOC'
      end
    end
  end

  def add_feature(feature)
    self.pos_tags = pos_features.push(feature).compact_blank.uniq.join(',')
  end

  def pos_features
    @features ||= pos_tags.to_s.split(',') + [part_of_speech_key]
  end
end
