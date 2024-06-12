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
#  surah_ruku_number  :integer
#  url                :text
#  verse_key          :string
#  verse_number       :integer
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
  belongs_to :recitation

  serialize :segments

  def audio_url
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
    if total_segments.zero?
      0
    else
      (verse.words_count / total_segments.to_f) * 100
    end
  end

  def total_segments
    segments.count
  end

  def print_segments
    segments.map do |s|
      s.drop(1)
    end.to_json
  end

  def set_segments(segments_list)
    # TODO: fix ayah by ayah segments, remove the segment index
    padded = segments_list.map do |s|
      if s.length == 3
        [s[0].to_i - 1, s[0].to_i, s[1].to_i, s[2].to_i]
      end
    end

    update segments: padded.compact_blank
  end
end
