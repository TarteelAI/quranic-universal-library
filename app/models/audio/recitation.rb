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
#  qua_key             :string
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
#  index_audio_recitations_on_qua_key              (qua_key) UNIQUE
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
    include RecitationDestroyable

    has_many :chapter_audio_files, class_name: 'Audio::ChapterAudioFile', foreign_key: :audio_recitation_id, dependent: :delete_all
    has_many :related_recitations, class_name: 'Audio::RelatedRecitation', foreign_key: :audio_recitation_id, dependent: :delete_all
    has_many :audio_change_logs, class_name: 'Audio::ChangeLog', foreign_key: :audio_recitation_id, dependent: :delete_all
    has_many :audio_segments, class_name: 'Audio::Segment', foreign_key: :audio_recitation_id, dependent: :delete_all
    has_one :gapped_recitation, class_name: 'Recitation', foreign_key: :gapless_recitation_id, dependent: :nullify

    belongs_to :section, class_name: 'Audio::Section', optional: true
    belongs_to :recitation_style, optional: true
    belongs_to :qirat_type, optional: true
    belongs_to :reciter, optional: true


    validates :qua_key, uniqueness: true, allow_nil: true

    scope :approved, -> { where(approved: true) }
    scope :un_approved, -> { where(approved: false) }

    scope :has_verse_segments, ->(value) do
      next all if value.blank?

      segments_present('sample.timestamp_to > sample.timestamp_from', value)
    end

    scope :has_word_segments, ->(value) do
      next all if value.blank?

      segments_present('jsonb_array_length(sample.segments) > 0', value)
    end

    scope :has_letter_segments, ->(value) do
      next all if value.blank?

      segments_present('jsonb_array_length(sample.letter_segments) > 0', value)
    end

    def self.segments_present(condition, value)
      sample = 'SELECT * FROM audio_segments ' \
               'WHERE audio_segments.audio_recitation_id = audio_recitations.id ' \
               'LIMIT 2'
      exists_sql = "EXISTS (SELECT 1 FROM (#{sample}) sample WHERE #{condition})"

      value.to_s == 'yes' ? where(exists_sql) : where("NOT #{exists_sql}")
    end

    def self.ransackable_scopes(*)
      %i[has_verse_segments has_word_segments has_letter_segments]
    end

    after_update :update_related_resources

    def clone_with_audio_files
      attrs = attributes.except('id', 'created_at', 'updated_at', 'resource_content_id')
      cloned = Audio::Recitation.new(attrs)
      cloned.name = "#{name} (cloned)"
      cloned.approved = false
      cloned.save!

      chapter_audio_files.find_each do |file|
        cloned_file = file.dup
        cloned_file.audio_recitation_id = cloned.id
        cloned_file.save!
      end

      cloned.send(:update_related_resources)

      cloned
    end

    # Name the user has to type to confirm destructive actions on this record.
    def confirmation_name
      name.to_s.strip.presence || id.to_s
    end

    # Summary of the rows that `destroy_with_audio_files!` will remove.
    def deletion_summary
      {
        'Chapter audio files' => chapter_audio_files.count,
        'Segments' => Audio::Segment.where(audio_recitation_id: id).count,
        'Change logs' => audio_change_logs.count,
        'Related recitations' => Audio::RelatedRecitation.where(
          'audio_recitation_id = :id OR related_audio_recitation_id = :id', id: id
        ).count,
        'Radio stations (will be unlinked)' => Radio::Station.where(audio_recitation_id: id).count
      }
    end

    def destroy_with_audio_files!(delete_resource_content: false)
      content = get_resource_content
      reciter_record = reciter
      qirat = qirat_type
      style = recitation_style

      transaction do
        Audio::RelatedRecitation.where(related_audio_recitation_id: id).delete_all
        Radio::Station.where(audio_recitation_id: id).update_all(audio_recitation_id: nil)

        # chapter audio files, segments, change logs and related recitations are
        # removed by the `dependent: :delete_all` associations.
        destroy!
      end

      kept_reason = delete_resource_content ? destroy_resource_content(content) : nil

      reciter_record&.update_recitation_count
      qirat&.update_recitation_count
      style&.update_recitation_count

      kept_reason
    end

    def missing_audio_files?
      chapter_audio_files.size < 114
    end

    def one_ayah?
      false
    end

    def has_verse_segments?
      sampled_segments.any? { |segment| segment.timestamp_to.to_i > segment.timestamp_from.to_i }
    end

    def has_word_segments?
      sampled_segments.any? { |segment| segment.segments.present? }
    end

    def has_letter_segments?
      sampled_segments.any? { |segment| segment.letter_segments.present? }
    end

    def audio_format
      read_attribute('format').presence || 'mp3'
    end

    def humanize
      style = recitation_style&.name
      _name = "#{id} - #{name}"
      _name += " (#{style})" if style.present?

      _name
    end

    def total_duration
      (chapter_audio_files.sum(:duration) || 0).round(2)
    end

    def validate_segments_data(audio_file: nil)
      segments = Audio::Segment.where(audio_recitation_id: id).includes(:audio_file, verse: :actual_words)

      if audio_file
        segments = segments.where(audio_file_id: audio_file.id)
        verses_count = audio_file.chapter.verses_count
      else
        verses_count = 6236
      end

      Audio::SegmentValidator.new(segments, expected_verses_count: verses_count).validate
    end

    def update_audio_stats
      chapter_audio_files.update_all(
        resource_content_id: get_resource_content.id
      )

      update(
        files_size: chapter_audio_files.reload.sum(:file_size),
        files_count: chapter_audio_files.count
      )
    end

    protected

    def sampled_segments
      @sampled_segments ||= audio_segments
                              .limit(2)
                              .select(:id, :timestamp_from, :timestamp_to, :segments, :letter_segments)
                              .to_a
    end

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

      update_columns(segments_count: audio_segments.count)
      reciter&.update_recitation_count
      qirat_type&.update_recitation_count
      recitation_style&.update_recitation_count
      chapter_audio_files.each(&:update_segment_percentile)
    end
  end
end
