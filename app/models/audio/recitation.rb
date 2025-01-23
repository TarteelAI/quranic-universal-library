# frozen_string_literal: true
# == Schema Information
#
# Table name: audio_recitations
#
#  id                  :bigint           not null, primary key
#  approved            :boolean
#  arabic_name         :string
#  description         :text
#  files_count         :integer
#  files_size          :float
#  format              :string
#  home                :integer
#  name                :string
#  priority            :integer
#  relative_path       :string
#  segment_locked      :boolean          default(FALSE)
#  segments_count      :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  qirat_type_id       :integer
#  recitation_style_id :integer
#  reciter_id          :integer
#  resource_content_id :integer
#  section_id          :integer
#
# Indexes
#
#  index_audio_recitations_on_approved             (approved)
#  index_audio_recitations_on_name                 (name)
#  index_audio_recitations_on_priority             (priority)
#  index_audio_recitations_on_recitation_style_id  (recitation_style_id)
#  index_audio_recitations_on_reciter_id           (reciter_id)
#  index_audio_recitations_on_relative_path        (relative_path)
#  index_audio_recitations_on_resource_content_id  (resource_content_id)
#  index_audio_recitations_on_section_id           (section_id)
#

module Audio
  class Recitation < QuranApiRecord
    include NameTranslateable
    include Resourceable

    has_many :chapter_audio_files, class_name: 'Audio::ChapterAudioFile', foreign_key: :audio_recitation_id
    has_many :related_recitations, class_name: 'Audio::RelatedRecitation', foreign_key: :audio_recitation_id
    has_many :audio_change_logs, class_name: 'Audio::ChangeLog', foreign_key: :audio_recitation_id
    belongs_to :section, class_name: 'Audio::Section', optional: true
    belongs_to :recitation_style, optional: true
    belongs_to :qirat_type, optional: true
    belongs_to :reciter, optional: true

    scope :approved, -> { where(approved: true) }
    scope :un_approved, -> { where(approved: false) }

    after_update :update_related_resources

    def one_ayah?
      false
    end

    def generate_audio_files
      GenerateSurahAudioFilesJob.perform_now(id, meta: true)
    end

    def create_audio_files
      1.upto(114) do |chapter_number|
        audio_file = chapter_audio_files
                       .where(chapter_id: chapter_number)
                       .first_or_initialize

        audio_file.audio_url ||= "https://download.quranicaudio.com/#{relative_path}/#{chapter_number}.mp3"
        audio_file.save
      end
    end

    def humanize
      "#{id} - #{name}"
    end

    def validate_segments_data(audio_file: nil)
      segments = Audio::Segment.where(audio_recitation_id: id).includes(verse: :actual_words)
      issues = []

      if audio_file
        segments = segments.where(audio_file_id: audio_file.id)
        verses_count = audio_file.chapter.verses_count
      else
        verses_count = 6236
      end

      # Check if we've segments for all ayahs
      if verses_count != segments.size
        issues.push(
          {
            text: "#{verses_count - segments.size} ayahs don't have segments data. Total segments: #{segments.size}",
            severity: 'bg-danger'
          }
        )
      end

      segments.each do |segment|
        if segment.timestamp_to < segment.timestamp_from
          issues.push(
            {
              key: segment.verse_key,
              text: "#{segment.verse_key} timestamp to(#{segment.timestamp_to}) is less than timestamp from(#{segment.timestamp_from})",
              severity: 'bg-danger'
            }
          )
        end

        words_count = segment.verse.actual_words.size
        segments_count = segment.segments.size
        missing_words = words_count - segments_count

        if missing_words > 0
          issues.push (
                        {
                          key: segment.verse_key,
                          text: "#{segment.verse_key} don't have segments for some words(#{missing_words} #{'word'.pluralize(missing_words) } missing).",
                          severity: 'bg-warning'
                        }
                      )
        end

        if segments_count > (words_count + (words_count.to_f * 0.5))
          issues.push (
                        {
                          key: segment.verse_key,
                          text: "Too many words are repeated, debug the repetition.",
                          severity: 'bg-info'
                        }
                      )
        end

        segment.segments.each_with_index do |word_segment, index|
          from = word_segment[1]
          to = word_segment[2]

          if to.blank? || from.blank?
            issues.push({
                          key: segment.verse_key,
                          text: "#{segment.verse_key}:#{index + 1} timestamp to(#{to}) or from(#{from}) is missing",
                          severity: 'bg-warning'
                        }
            )
          elsif to < from
            issues.push({
                          key: segment.verse_key,
                          text: "#{segment.verse_key}:#{index + 1} timestamp to(#{to}) is less than timestamp from(#{from})",
                          severity: 'bg-warning'
                        }
            )
          elsif to == from
            issues.push({
                          key: segment.verse_key,
                          text: "#{segment.verse_key}:#{index + 1} timestamp to(#{to}) is equal to from (#{from}). Word duration is 0",
                          severity: 'bg-warning'
                        }
            )
          end
        end
      end

      issues
    end


    protected

    def update_related_resources
      if get_resource_content.nil?
        resource = build_resource_content
        resource.name = name
        resource.description = description
        resource.resource_info = description

        resource.resource_type = ResourceContent::ResourceType::Audio
        resource.sub_type = ResourceContent::SubType::Audio
        resource.cardinality_type = ResourceContent::CardinalityType::OneChapter
        resource.save(validate: false)

        update_column(:resource_content_id, resource.id)
      end

      reciter&.update_recitation_count
      qirat_type&.update_recitation_count
      recitation_style&.update_recitation_count
    end
  end
end
