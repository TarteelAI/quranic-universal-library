# == Schema Information
#
# Table name: audio_files
#
#  id                 :integer          not null, primary key
#  duration           :integer
#  format             :string
#  hizb_number        :integer
#  is_enabled         :boolean
#  juz_number         :integer
#  manzil_number      :integer
#  mime_type          :string
#  page_number        :integer
#  rub_el_hizb_number :integer
#  ruku_number        :integer
#  segments           :text
#  segments_count     :integer
#  surah_ruku_number  :integer
#  url                :text
#  verse_key          :string
#  verse_number       :integer
#  words_count        :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  chapter_id         :integer
#  recitation_id      :integer
#  verse_id           :integer
#
# Indexes
#
#  index_audio_files_on_chapter_id                   (chapter_id)
#  index_audio_files_on_chapter_id_and_verse_number  (chapter_id,verse_number)
#  index_audio_files_on_hizb_number                  (hizb_number)
#  index_audio_files_on_is_enabled                   (is_enabled)
#  index_audio_files_on_juz_number                   (juz_number)
#  index_audio_files_on_manzil_number                (manzil_number)
#  index_audio_files_on_page_number                  (page_number)
#  index_audio_files_on_recitation_id                (recitation_id)
#  index_audio_files_on_rub_el_hizb_number           (rub_el_hizb_number)
#  index_audio_files_on_ruku_number                  (ruku_number)
#  index_audio_files_on_verse_id                     (verse_id)
#  index_audio_files_on_verse_key                    (verse_key)
#

class AudioFile < QuranApiRecord
  belongs_to :verse
  belongs_to :chapter
  belongs_to :recitation

  serialize :segments

  scope :missing_segments, -> { where(segments_count: 0) }

  def segments=(val)
    if val.is_a?(String)
      val = JSON.parse(val.strip)
    end

    super(val)
  end

  def surah_number
    chapter_id
  end

  def ayah_number
    verse_number
  end

  def duration_sec
    duration
  end

  def audio_url
    return read_attribute(:audio_url) if read_attribute(:audio_url).present?

    if url.start_with?('http')
      url
    elsif url.include?('//')
      "https:#{url}"
    else
      "https://audio.qurancdn.com/#{url}"
    end
  end

  def file_name
    url.split('/').last
  end

  def segment_progress
    if segments_count.zero?
      0
    else
      (verse.words_count / segments_count.to_f) * 100
    end
  end

  def print_segments
    segments.map do |s|
      s.drop(1)
    end.to_json
  end

  def segment_data
    get_segments.to_s.gsub(/\s+/, '')
  end

  def get_segments
    segments.map do |s|
      if s.size == 4
        s.drop(1)
      else
        s
      end
    end
  end

  def set_segments(segments_list, user=nil)
    #TODO: generate activity if data is changed and assign user to it
    # TODO: fix ayah by ayah segments, remove the segment index
    padded = segments_list.map do |s|
      if s.length == 3
        [s[0].to_i - 1, s[0].to_i, s[1].to_i, s[2].to_i]
      end
    end

    update segments: padded.compact_blank
  end
end
