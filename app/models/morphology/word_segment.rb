# == Schema Information
#
# Table name: morphology_word_segments
#
#  id                        :integer          not null, primary key
#  word_id                   :integer
#  root_id                   :integer
#  topic_id                  :integer
#  lemma_id                  :integer
#  grammar_concept_id        :integer
#  grammar_role_id           :integer
#  grammar_sub_role_id       :integer
#  grammar_term_id           :integer
#  grammar_term_key          :string
#  grammar_term_name         :string
#  part_of_speech_key        :string
#  part_of_speech_name       :string
#  position                  :integer
#  text_uthmani              :string
#  grammar_term_desc_english :string
#  grammar_term_desc_arabic  :string
#  pos_tags                  :string
#  root_name                 :string
#  lemma_name                :string
#  verb_form                 :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  hidden                    :boolean
#  segment_type              :string
#  person_type               :string
#  voice_type                :string
#  gender_type               :string
#  number_type               :string
#  aspect_type               :string
#  mood_type                 :string
#  derivation_type           :string
#  state_type                :string
#  case_type                 :string
#  pronoun_type              :string
#  special_type              :string
#  text_qpc_hafs             :string
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

class Morphology::WordSegment < QuranApiRecord
  include PaperTrailAttribution
  has_paper_trail

  VERB_FORMS = %w[I II III IV V VI VII VIII IX X XI].freeze
  POS_TAG_COLORS = {
    n: 'sky', # Noun
    pn: 'blue', # Proper Noun
    #TODO: Set Pronoun color based on pronoun type
    pron: 'sky', # Pronoun
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

  belongs_to :word, class_name: 'Morphology::Word', optional: true
  belongs_to :grammar_concept, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_sub_role, class_name: 'Morphology::GrammarConcept', optional: true
  belongs_to :grammar_term, class_name: 'Morphology::GrammarTerm', optional: true

  belongs_to :root, optional: true
  belongs_to :topic, optional: true
  belongs_to :lemma, optional: true
  has_one :graph_node, class_name: 'Morphology::DependencyGraph::GraphNode', foreign_key: :segment_id

  default_scope { order 'position asc' }

  # Saves an edit from the corpus tool.
  # params: part_of_speech ("KEY|name"), pos_tags (array), verb_form, root_id, lemma_name,
  # grammar_term_desc_arabic, grammar_term_desc_english
  def save_edit(params, user)
    pos_key, pos_name = params[:part_of_speech].to_s.split('|', 2)
    self.part_of_speech_key = pos_key.presence
    self.part_of_speech_name = pos_name.presence

    self.verb_form = params[:verb_form].presence
    tags = Array(params[:pos_tags]).map { |tag| tag.to_s.delete_prefix('new:').strip.upcase }
    tags = tags.compact_blank.reject { |tag| tag.start_with?('VF:') }
    tags << "VF:#{verb_form}" if verb_form
    self.pos_tags = tags.uniq.join(',').presence

    # Some segments have a root name without a linked root, keep it unless a root is picked
    had_root = root_id.present?
    self.root = Root.find_by(id: params[:root_id])
    self.root_name = root.value.delete(' ') if root
    self.root_name = nil if root.nil? && had_root

    self.lemma_name = params[:lemma_name].to_s.strip.presence
    self.lemma = find_lemma(lemma_name)

    self.grammar_term_desc_arabic = params[:grammar_term_desc_arabic].to_s.strip.presence
    self.grammar_term_desc_english = params[:grammar_term_desc_english].to_s.strip.presence

    if part_of_speech_key.blank?
      errors.add(:part_of_speech_key, "can't be blank")
      return false
    end

    attribute_versions_to(user) { save }
  end

  # Lemmas don't always store diacritics in the canonical order (shadda before fatha), compare normalized
  def find_lemma(name)
    return if name.blank?

    normalized = name.unicode_normalize(:nfc)
    clean = name.remove(/[\u064B-\u065F\u0670\u06D6-\u06ED]/)
    Lemma.where(text_madani: name).or(Lemma.where(text_clean: clean)).find { |lemma| lemma.text_madani.to_s.unicode_normalize(:nfc) == normalized }
  end

  def pronoun_type
    tag = self[:pronoun_type]
    Corpus::Morphology::PronounType.new(tag: tag)
  end

  def get_segment_color
    pos_tag = part_of_speech_key.to_s.downcase.to_sym

    # TODO: Set Pronoun color based on pronoun type.
    # if pos_tag == :pron
    #   {
    #     subj: 'sky',
    #     obj: 'orange',
    #   }[pronoun_type.tag.to_sym] || 'metal'
    # end

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
