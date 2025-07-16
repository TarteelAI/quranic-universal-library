# == Schema Information
#
# Table name: recitations
#
#  id                  :integer          not null, primary key
#  approved            :boolean          default(TRUE)
#  description         :text
#  files_count         :integer
#  name                :string
#  reciter_name        :string
#  relative_path       :string
#  segment_locked      :boolean          default(TRUE)
#  segments_count      :integer          default(0)
#  style               :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  qirat_type_id       :integer
#  recitation_style_id :integer
#  reciter_id          :integer
#  resource_content_id :integer
#
# Indexes
#
#  index_recitations_on_qirat_type_id        (qirat_type_id)
#  index_recitations_on_recitation_style_id  (recitation_style_id)
#  index_recitations_on_reciter_id           (reciter_id)
#  index_recitations_on_resource_content_id  (resource_content_id)
#
class Recitation < QuranApiRecord
  belongs_to :reciter
  belongs_to :recitation_style
  belongs_to :qirat_type, optional: true
  belongs_to :resource_content, optional: true

  has_many :audio_files
  alias get_resource_content resource_content

  scope :approved, -> { where(approved: true) }
  scope :un_approved, -> { where(approved: false) }

  def one_ayah?
    true
  end

  def missing_audio_files?
    audio_files.size < 6236
  end

  def audio_format
    read_attribute('format') || 'mp3'
  end

  def export_segments(export_type, chapter_id = nil)
    service = AudioSegment::AyahByAyah.new(self)

    service.export(export_type, chapter_id)
  end

  def tarteel_key
    resource_content.meta_value('tarteel_key')
  end

  def validate_segments_data(chapter_id: nil)
    if chapter_id
      chapter = Chapter.find(chapter_id)
      files = audio_files.where(chapter_id: chapter.id)
      verses_count = chapter.verses_count
    else
      files = audio_files
      verses_count = 6236
    end

    files = files.includes(:verse)
    issues = []

    # Check if we've segments for all ayahs
    if verses_count != files.size
      issues.push(
        {
          text: "#{verses_count - files.size} ayahs don't have segments data. Total segments: #{files.size}",
          severity: 'bg-danger'
        }
      )
    end

    files.each do |file|
      segments = file.segments
      verse = file.verse
      words_count = verse.words_count
      segments_count = segments.size
      missing_words = words_count - segments_count

      if missing_words > 0
        issues.push (
                      {
                        key: verse.verse_key,
                        text: "#{verse.verse_key} don't have segments for some words(#{missing_words} #{'word'.pluralize(missing_words) } missing).",
                        severity: 'bg-warning'
                      }
                    )
      end

      if segments_count > (words_count + (words_count.to_f * 0.5))
        issues.push (
                      {
                        key: verse.verse_key,
                        text: "Too many words are repeated, debug the repetition.",
                        severity: 'bg-info'
                      }
                    )
      end

      segments.each_with_index do |word_segment, index|
        from = word_segment[1]
        to = word_segment[2]

        if to.blank? || from.blank?
          issues.push({
                        key: verse.verse_key,
                        text: "#{verse.verse_key}:#{index + 1} timestamp to(#{to}) or from(#{from}) is missing",
                        severity: 'bg-warning'
                      }
          )
        elsif to < from
          issues.push({
                        key: verse.verse_key,
                        text: "#{verse.verse_key}:#{index + 1} timestamp to(#{to}) is less than timestamp from(#{from})",
                        severity: 'bg-warning'
                      }
          )
        elsif to == from
          issues.push({
                        key: verse.verse_key,
                        text: "#{verse.verse_key}:#{index + 1} timestamp to(#{to}) is equal to from (#{from}). Word duration is 0",
                        severity: 'bg-warning'
                      }
          )
        end
      end
    end

    issues
  end

  def name
    reciter_name
  end

  def humanize
    "#{id} - #{reciter_name}"
  end

  def self.ransackable_associations(auth_object = nil)
    ["audio_files", "qirat_type", "recitation_style", "reciter", "resource_content"]
  end

  def update_audio_stats
    files = AudioFile.includes(:verse).where(recitation: self)

    files.each do |file|
      words = file.verse.words_count
      segments = (file.segments || []).count

      file.update_columns(
        words_count: words,
        segments_count: segments
      )
    end

    update(
      files_count: files.count,
      segments_count: files.sum(:segments_count)
    )
  end
end
