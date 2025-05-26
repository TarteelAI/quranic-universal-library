# == Schema Information
#
# Table name: morphology_word_segments
#
#  id                        :bigint           not null, primary key
#  aspect_type               :string
#  case_type                 :string
#  derivation_type           :string
#  gender_type               :string
#  grammar_term_desc_arabic  :string
#  grammar_term_desc_english :string
#  grammar_term_key          :string
#  grammar_term_name         :string
#  hidden                    :boolean
#  lemma_name                :string
#  mood_type                 :string
#  number_type               :string
#  part_of_speech_key        :string
#  part_of_speech_name       :string
#  person_type               :string
#  pos_tags                  :string
#  position                  :integer
#  pronoun_type              :string
#  root_name                 :string
#  segment_type              :string
#  special_type              :string
#  state_type                :string
#  text_qpc_hafs             :string
#  text_uthmani              :string
#  verb_form                 :string
#  voice_type                :string
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
#  index_morphology_word_segments_on_aspect_type          (aspect_type)
#  index_morphology_word_segments_on_case_type            (case_type)
#  index_morphology_word_segments_on_derivation_type      (derivation_type)
#  index_morphology_word_segments_on_gender_type          (gender_type)
#  index_morphology_word_segments_on_grammar_concept_id   (grammar_concept_id)
#  index_morphology_word_segments_on_grammar_role_id      (grammar_role_id)
#  index_morphology_word_segments_on_grammar_sub_role_id  (grammar_sub_role_id)
#  index_morphology_word_segments_on_grammar_term_id      (grammar_term_id)
#  index_morphology_word_segments_on_lemma_id             (lemma_id)
#  index_morphology_word_segments_on_mood_type            (mood_type)
#  index_morphology_word_segments_on_number_type          (number_type)
#  index_morphology_word_segments_on_part_of_speech_key   (part_of_speech_key)
#  index_morphology_word_segments_on_person_type          (person_type)
#  index_morphology_word_segments_on_pos_tags             (pos_tags)
#  index_morphology_word_segments_on_position             (position)
#  index_morphology_word_segments_on_pronoun_type         (pronoun_type)
#  index_morphology_word_segments_on_root_id              (root_id)
#  index_morphology_word_segments_on_segment_type         (segment_type)
#  index_morphology_word_segments_on_special_type         (special_type)
#  index_morphology_word_segments_on_state_type           (state_type)
#  index_morphology_word_segments_on_text_qpc_hafs        (text_qpc_hafs)
#  index_morphology_word_segments_on_topic_id             (topic_id)
#  index_morphology_word_segments_on_voice_type           (voice_type)
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
  POS_TAG_COLORS = {
    n: 'sky', # Noun
    pn: 'blue', # Proper Noun
    pron: 'sky', # Pronoun #TODO: Set Pronoun color based on pronoun type.
    dem: 'brown', # Demonstrative
    rel: 'gold', # Relative pronoun
    adj: 'purple', # Adjective
    v: 'seagreen', # Verb
    p: 'rust', # Preposition
    intg: 'rose', # Interrogative
    voc: 'green', # Vocative
    neg: 'red', # Negative
    emph: 'navy', # Emphatic particle
    prp: 'gold', # Purpose
    impv: 'orange', # Imperative verb
    fut: 'orange', # Future particle
    conj: 'navy', # Conjunction
    det: 'gray', # Determiner
    inl: 'orange', # Initials (disconnected letters at the start of surahs)
    t: 'orange', # Time adverb
    loc: 'orange', # Location adverb
    acc: 'orange', # Accusative case marker
    cond: 'orange', # Conditional particle
    sub: 'gold', # Subordinating conjunction
    res: 'navy', # Restriction
    exp: 'orange', # Exceptive particle
    avr: 'orange', # Aversion particle
    cert: 'orange', # Certainty particle
    ret: 'orange', # Retraction particle
    prev: 'orange', # Preventive particle
    ans: 'navy', # Answer particle
    inc: 'orange', # Inceptive particle
    sur: 'orange', # Surprise particle
    sup: 'navy', # Supplemental particle
    exh: 'orange', # Exhortation particle
    impn: 'orange', # Imperative verbal noun
    exl: 'orange', # Explanation particle
    eq: 'navy', # Equalization particle
    rem: 'navy', # Resumption particle
    caus: 'orange', # Cause particle
    amd: 'navy', # Amendment particle
    pro: 'red', # Prohibition particle
    circ: 'navy', # Circumstantial (حال)
    rslt: 'navy', # Result clause particle
    int: 'orange', # Interpretation particle
    com: 'navy' # Comitative particle (e.g., مع)
  }.freeze

  belongs_to :word, class_name: 'Morphology::Word'
  belongs_to :grammar_concept, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_sub_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_term, class_name: 'Morphology::GrammarTerm', optional: true

  belongs_to :root, optional: true
  belongs_to :topic, optional: true
  belongs_to :lemma, optional: true

  default_scope { order 'position asc' }

  def pronoun_type
    tag = self[:pronoun_type]
    Corpus::Morphology::PronounType.new(tag: tag)
  end

  def get_segment_color
    pos_tag = part_of_speech_key.to_s.downcase.to_sym

=begin
TODO: Set Pronoun color based on pronoun type.
    if pos_tag == :pron
      {
        subj: 'sky',
        obj: 'orange',
      }[pronoun_type.tag.to_sym] || 'metal'
    end
=end

    POS_TAG_COLORS[pos_tag]
  end

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
