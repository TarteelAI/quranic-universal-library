class WordConcordanceLabelsPresenter < ApplicationPresenter
  def meta_title
    "Quran Word Concordance Tool"
  end

  def meta_description
    "Use the Quran Word Concordance Tool to review and label grammar, part of speech, and morphology for each word in the Quran. Help improve corpus accuracy through detailed word-level tagging."
  end

  def meta_keywords
    'Quran corpus tool, part of speech tagging, Quran morphology labeling, Quranic grammar editor, word concordance, Arabic grammar tagging, Quran word segmentation'
  end

  # Part of speech choices as [label, "KEY|name"], the current one included
  def part_of_speech_options(segment)
    pairs = Morphology::WordSegment.unscoped.where.not(part_of_speech_name: nil)
                                   .where.not(part_of_speech_key: 'FIXME')
                                   .distinct.pluck(:part_of_speech_key, :part_of_speech_name)
    pairs |= [[segment.part_of_speech_key, segment.part_of_speech_name]] if segment.part_of_speech_key
    pairs.sort.map { |key, name| ["#{key} · #{name.presence || 'no name'}", "#{key}|#{name}"] }
  end

  def current_part_of_speech(segment)
    "#{segment.part_of_speech_key}|#{segment.part_of_speech_name}" if segment.part_of_speech_key
  end

  # Tags that aren't a feature, used in the corpus, most used first. Current tags first, select2 submits them in option order
  def other_tag_options(segment)
    tags = Rails.cache.fetch('corpus/other-tags', expires_in: 1.day) do
      counts = Morphology::WordSegment.unscoped.where.not(pos_tags: [nil, '']).group(:pos_tags, :part_of_speech_key).count
      counts.each_with_object(Hash.new(0)) do |((tags, pos), count), all|
        Morphology::SegmentTags.new(tags, pos).other_tags.each { |tag| all[tag] += count }
      end.sort_by { |_, count| -count }.map(&:first)
    end
    segment.tags.other_tags | tags
  end

  # Common reasons for a word's case (إعراب)
  def case_reason_options
    ['فاعل', 'نائب فاعل', 'مبتدأ', 'خبر', 'مفعول به', 'مفعول مطلق', 'مفعول لأجله', 'مفعول فيه', 'مفعول معه',
     'حال', 'تمييز', 'نعت', 'مضاف إليه', 'اسم مجرور', 'بدل', 'معطوف', 'توكيد', 'منادى',
     'اسم إن', 'خبر إن', 'اسم كان', 'خبر كان', 'مستثنى']
  end

  def verb_form_options
    Morphology::WordSegment::VERB_FORMS.each_with_index.map { |roman, i| ["#{roman} (#{i + 1})", (i + 1).to_s] }
  end

  def root_options
    Root.order(:value).pluck(:value, :id)
  end
end
