# frozen_string_literal: true
# == Schema Information
#
# Table name: resource_contents
#
#  id                     :integer          not null, primary key
#  approved               :boolean
#  author_name            :string
#  cardinality_type       :string
#  description            :text
#  language_name          :string
#  meta_data              :jsonb
#  name                   :string
#  priority               :integer
#  records_count          :integer          default(0)
#  resource_info          :text
#  resource_type          :string
#  resource_type_name     :string
#  slug                   :string
#  sqlite_db              :string
#  sqlite_db_generated_at :datetime
#  sub_type               :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  author_id              :integer
#  data_source_id         :integer
#  language_id            :integer
#  mobile_translation_id  :integer
#  resource_id            :string
#
# Indexes
#
#  index_resource_contents_on_approved               (approved)
#  index_resource_contents_on_author_id              (author_id)
#  index_resource_contents_on_cardinality_type       (cardinality_type)
#  index_resource_contents_on_data_source_id         (data_source_id)
#  index_resource_contents_on_language_id            (language_id)
#  index_resource_contents_on_meta_data              (meta_data) USING gin
#  index_resource_contents_on_mobile_translation_id  (mobile_translation_id)
#  index_resource_contents_on_priority               (priority)
#  index_resource_contents_on_resource_id            (resource_id)
#  index_resource_contents_on_resource_type_name     (resource_type_name)
#  index_resource_contents_on_slug                   (slug)
#  index_resource_contents_on_sub_type               (sub_type)
#



class ResourceContent < QuranApiRecord
  scope :translations, -> { where sub_type: SubType::Translation }
  scope :transliteration, -> { where sub_type: SubType::Transliteration }
  scope :media, -> { where sub_type: SubType::Video }
  scope :tafsirs, -> { where sub_type: SubType::Tafsir }
  scope :chapter_info, -> { where sub_type: SubType::Info }
  scope :one_verse, -> { where cardinality_type: CardinalityType::OneVerse }
  scope :one_chapter, -> { where cardinality_type: CardinalityType::OneChapter }
  scope :one_word, -> { where cardinality_type: CardinalityType::OneWord }
  scope :quran_topics, -> { where sub_type: SubType::Topic }
  scope :recitations, -> { where sub_type: SubType::Audio }
  scope :general, -> { where sub_type: SubType::Data }
  scope :quran_script, -> { where sub_type: SubType::QuranText }
  scope :from_quranenc, -> { where("meta_data ->> 'source' = 'quranenc'").or(where data_source_id: 14) }
  scope :with_footnotes, -> { where("meta_data ->> 'has-footnote' = 'yes'") }
  scope :approved, -> { where approved: true }
  scope :for_language, lambda {|lang| where(language: Language.find_by_iso_code(lang)) }
  scope :permission_to_host_eq, lambda { |val|
    where(id: ResourcePermission.where(permission_to_host: val).pluck(:resource_content_id))
  }

  scope :permission_to_share_eq, lambda { |val|
    where(id: ResourcePermission.where(permission_to_share: val).pluck(:resource_content_id))
  }

  scope :quran_enc_key_equals, lambda { |val|
    where("meta_data ->> 'quranenc-key' = ?", val)
  }

  scope :quran_enc_key_contains, lambda { |val|
    where("meta_data ->> 'quranenc-key' ilike ?", "%#{val}%")
  }

  def self.ransackable_scopes(*)
    %i[permission_to_host_eq permission_to_share_eq quran_enc_key_contains quran_enc_key_equals quran_enc_key_starts_with quran_enc_key_ends_with]
  end

  belongs_to :author, optional: true
  belongs_to :language, optional: true
  belongs_to :data_source, optional: true
  belongs_to :resource, polymorphic: true, optional: true

  has_many :translated_names, as: :resource
  has_many :resource_tags, as: :resource
  has_many :tags, through: :resource_tags

  has_one :en_translation_name, -> { where language_id: 38 }, as: :resource, class_name: 'TranslatedName'
  has_one :resource_permission
  has_many :user_projects

  after_update :update_related_content

  attr_reader :include_footnote,
              :export_format,
              :export_file_name

  #TODO: replace uploader with ActiveStorage
  mount_uploader :sqlite_db, DatabaseBackupUploader
  has_many_attached :source_files

  module CardinalityType
    OneVerse = '1_ayah'
    OneWord = '1_word'
    NVerse = 'n_ayah'
    OneChapter = '1_chapter'
  end

  module ResourceType
    Audio = 'audio'
    Content = 'content'
    Quran = 'quran'
    Media = 'media'
  end

  module SubType
    Mutashabihat = 'mutashabihat'
    Translation = 'translation'
    Tafsir = 'tafsir'
    Transliteration = 'transliteration'
    Image = 'image'
    Info = 'info'
    FootNote = 'footnote'
    Video = 'video'
    Audio = 'audio'
    Data = 'data'
    QuranText = 'quran_text'
    Topic = 'topic'
  end

  def allow_publish_sharing?
    permission = resource_permission

    permission.blank? || permission.share_permission_is_granted? || permission.share_permission_is_unknown?
  end

  def one_word?
    cardinality_type == CardinalityType::OneWord
  end

  def one_ayah?
    cardinality_type == CardinalityType::OneVerse
  end

  def has_footnote?
    meta_value('has-footnote') == 'yes'
  end

  def get_source_pdf_url
    url = meta_value('source-pdf-url')

    if url.blank?
      file = source_pdf_file
      url = file&.blob&.url
    end

    url
  end

  def source_pdf_file
    source_files.includes(:blob).where(
      blob: { content_type: 'application/pdf' }
    ).first
  end

  def author_id=(val)
    super(val)

    author = Author.find_by(id: val)
    write_attribute :author_name, author&.name
  end

  # Generate sqlite db file name
  def sqlite_file_name
    export_name = slug || translated_names.english&.first&.name
    export_name ||= name

    export_name.to_s.downcase.gsub(/\s+/, '-')
  end

  #
  # Check if we've added links to referenced ayah in the footnotes manually
  #
  def has_referenced_ayah_in_footnotes?
    !!meta_value('ref-ayah-in-footnotes')
  end

  def quran_enc_key
    meta_value('quranenc-key').to_s
  end

  def meta_value(key)
    key = format_meta_key(key)

    fetch_metadata[key]
  end

  def meta_data=(val)
    json = Oj.load(val)

    json.keys.each do |key|
      formatted_key = format_meta_key(key)

      if formatted_key != key
        json[formatted_key] = json[key]
        json.delete(key)
      end
    end

    super json
  end

  def set_meta_value(key, val)
    key = format_meta_key(key)

    meta_data = fetch_metadata
    meta_data[key] = val
  end

  def delete_meta_value(key)
    key = format_meta_key(key)
    meta_data = fetch_metadata

    meta_data.delete(key)
  end

  def set_meta_value!(key, val)
    set_meta_value(key, val)
    save
  end

  def humanize
    "#{id}-#{name} - #{language_name}(#{sub_type})"
  end

  def topic?
    sub_type == SubType::Topic
  end

  def transliteration?
    sub_type == SubType::Transliteration
  end

  def translation?
    sub_type == SubType::Translation
  end

  def tafsir?
    sub_type == SubType::Tafsir
  end

  def chapter_info?
    sub_type == SubType::Info
  end

  def foot_note?
    sub_type == SubType::FootNote
  end

  def video?
    sub_type == SubType::Video
  end

  def recitation?
    sub_type == SubType::Audio || resource_type_name == ResourceType::Audio
  end

  def chapter?
    cardinality_type == CardinalityType::OneChapter
  end

  def verse?
    cardinality_type == CardinalityType::OneVerse
  end

  def word?
    cardinality_type == CardinalityType::OneWord
  end

  def tokens?
    sub_type == SubType::QuranText
  end

  def draft_translations
    if tafsir?
      Draft::Tafsir.where(resource_content_id: id)
    else
      Draft::Translation.where(resource_content_id: id)
    end
  end

  def has_draft_translation?
    draft_translations.any?
  end

  def sourced_from_quranenc?
    meta_value('source') == 'quranenc' || quran_enc_key.present?
  end

  class << self
    def collection_for_resource_type
      ResourceContent::ResourceType.constants.map do |c|
        ResourceContent::ResourceType.const_get c
      end
    end

    def collection_for_sub_type
      ResourceContent::SubType.constants.map do |c|
        ResourceContent::SubType.const_get c
      end
    end

    def collection_for_cardinality_type
      ResourceContent::CardinalityType.constants.map do |c|
        ResourceContent::CardinalityType.const_get c
      end
    end
  end

  def update_records_count
    count = if translation?
              if one_word?
                WordTranslation.where(resource_content_id: id).size
              else
                Translation.where(resource_content_id: id).size
              end
            elsif tafsir?
              Tafsir.where(resource_content_id: id).size
            elsif chapter_info?
              ChapterInfo.where(resource_content_id: id).size
            elsif foot_note?
              FootNote.where(resource_content_id: id).size
            elsif transliteration?
              Transliteration.where(resource_content_id: id).size
            elsif tokens?
              Token.where(resource_content_id: id).size
            elsif video?
              MediaContent.where(resource_content_id: id).size
            elsif recitation?
              if chapter?
                Audio::ChapterAudioFile.where(resource_content_id: id).size
              else
                AudioFile.where(recitation_id: Recitation.where(resource_content_id: id).pluck(:id)).size
              end
            end

    update_column :records_count, count
  end

  def run_draft_import_hooks
    if tafsir?
      generate_text_digest
      check_duplicate_tafsir_draft_text
      create_draft_tafsir_groups
      #check_for_missing_draft_tafsirs
    end
  end

  def run_after_import_hooks
    update_records_count

    if translation?
      language.update_translations_count
      issues = check_for_missing_translation

      if issues.blank?
        puts "Looks good!"
      else
        AdminTodo.create(
          resource_content_id: id,
          tags: 'translation-issue',
          is_finished: false,
          description: issues.join("\n")
        )

        puts issues
      end

      issues.join(', ')
    elsif tafsir?
      issues = check_for_missing_tafsirs
      puts issues

      if issues.present?
        AdminTodo.create(
          resource_content_id: id,
          tags: 'tafsir-issue',
          is_finished: false,
          description: issues.join("\n")
        )
      end
    end
  end

  #TODO: refactor this, running 6000+ queries will fail on production
  def check_for_missing_draft_tafsirs
    tafsirs = Draft::Tafsir.where(resource_content_id: id)
    issues = []

    Verse.find_each do |verse|
      tafsir = tafsirs.where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)

      if tafsir.blank? || tafsir.first.draft_text.blank?
        issues.push(text: "#{name}: Tafsir is missing for #{verse.verse_key}")
      end
    end

    issues
  end

  def create_draft_tafsir_groups
    draft_tafsirs = Draft::Tafsir.where(resource_content_id: id)

    duplicates = draft_tafsirs.select('md5, array_agg(id) as duplicate_ids')
                              .group(:md5)
                              .having('COUNT(*) > 1')

    duplicate_tafsirs = draft_tafsirs.where(id: duplicates.map(&:duplicate_ids).flatten.uniq)
    duplicate_tafsirs.each do |dup|
      duplicates_drafts = draft_tafsirs.where(md5: dup.md5)
      group = get_adjacent_ayah_keys(dup.verse_key, duplicates_drafts.pluck(:verse_key))

      if group.size > 1
        first_ayah = Verse.find_by(verse_key: group.first)
        last_ayah = Verse.find_by(verse_key: group.last)

        draft_tafsirs
          .where(verse_key: group)
          .update_all(
            group_verse_key_from: first_ayah.verse_key,
            group_verse_key_to: last_ayah.verse_key,
            group_verses_count: group.size,
            start_verse_id: first_ayah.id,
            end_verse_id: last_ayah.id,
            group_tafsir_id: first_ayah.id
          )
      end
    end
  end

  def export_draft_tafsir
    return unless tafsir?
    json = {}

    Draft::Tafsir.where(resource_content_id: id).each do |t|
      json[t.verse_key] = {
        draft_text: t.draft_text,
        current_text: t.current_text,
        group_verse_key_from: t.group_verse_key_from,
        group_verse_key_to: t.group_verse_key_to,
        group_verses_count: t.group_verses_count,
        group_tafsir_id: t.group_tafsir_id,
        start_verse_id: t.start_verse_id,
        end_verse_id: t.end_verse_id
      }
    end

    File.open("data/exported_files/tafsir-#{id}.json", 'wb') do |file|
      file << JSON.generate(json, { state: JsonNoEscapeHtmlState.new })
    end
  end

  def import_draft_tafsir(id)
    resource = ResourceContent.find id
    data = JSON.parse(File.read("exported_tafsirs/tafsir-#{id}.json"))

    data.keys.each do |key|
      verse = Verse.find_by(verse_key: key)
      draft = Draft::Tafsir.where(resource_content_id: resource.id, verse_id: verse.id).first_or_initialize
      draft.attributes = data[key]

      existing_tafsir = Tafsir
                          .where(resource_content_id: resource.id)
                          .where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)
                          .first

      draft.tafsir_id = existing_tafsir&.id
      draft.current_text = existing_tafsir&.text.presence || draft.current_text
      draft.text_matched = draft.current_text == draft.draft_text
      draft.verse_key = verse.verse_key
      draft.imported = false
      draft.save

      puts "#{id} - #{verse.verse_key}"
    end

    resource.run_draft_import_hooks
  end

  def export_file_name
    ExportService.new(self).get_export_file_name
  end
  protected

  def generate_text_digest
    digest_for_empty_text = Digest::MD5.hexdigest('')
    draft_tafsirs = Draft::Tafsir.where(resource_content_id: id)

    draft_tafsirs.each do |draft|
      if draft.draft_text.blank?
        draft.update_columns(md5: digest_for_empty_text)
      else
        checksum = Digest::MD5.hexdigest(draft.draft_text.to_s)
        draft.update_column(:md5, checksum)
      end
    end
  end

  def check_duplicate_tafsir_draft_text
    draft_tafsirs = Draft::Tafsir.where(resource_content_id: id)

    draft_tafsirs.each do |draft|
      if draft.draft_text.blank?
        draft.update_columns(
          need_review: true,
          comments: "No text, maybe we need to group this ayah with previous ayah?"
        )
        next
      end

      duplicates = draft_tafsirs
                     .where(md5: draft.md5)
                     .order('verse_id ASC')

      if duplicates.length > 1
        duplicates = duplicates.pluck(:verse_key)
        group = get_adjacent_ayah_keys(draft.verse_key, duplicates)

        comment = "#{duplicates.join(', ')} has exact same text, maybe we're missing the grouping?"

        if group.size > 1
          comment = "#{comment}\n Possible grouping #{group.first}-#{group.last}"
        end

        draft.update_columns(
          need_review: true,
          comments: comment
        )
      end
    end
  end

  def get_adjacent_ayah_keys(target_key, keys)
    target_surah = target_key.split(':').first

    sorted_keys = keys.select do |key|
      target_surah == key.split(':').first
    end
    sorted_keys = sorted_keys.sort_by { |key| key.split(':').last.to_i }

    connected_keys = [target_key]

    target_index = sorted_keys.index(target_key)
    return [] if target_index.nil?

    current = target_index - 1

    while current >= 0
      current_key = sorted_keys[current]
      current_ayah = current_key.split(':').last.to_i
      prev_ayah = sorted_keys[current + 1].split(':').last.to_i

      break unless current_ayah + 1 == prev_ayah

      connected_keys.unshift(current_key)
      current -= 1
    end

    current = target_index + 1

    while current < sorted_keys.length
      current_key = sorted_keys[current]
      current_ayah = current_key.split(':').last.to_i
      next_ayah = sorted_keys[current - 1].split(':').last.to_i

      break unless current_ayah - 1 == next_ayah

      connected_keys << current_key
      current += 1
    end

    connected_keys.sort_by { |key| key.split(':').last.to_i }
  end

  def format_meta_key(key)
    key.gsub(/[\s_]/, '-').gsub('--', '-').downcase
  end

  def check_for_missing_tafsirs
    tafsirs = Tafsir.where(resource_content_id: id)
    issues = []

    Verse.find_each do |verse|
      tafsir = tafsirs.where(":ayah >= start_verse_id AND :ayah <= end_verse_id ", ayah: verse.id)

      if tafsir.blank?
        issues.push "#{id}-#{name}: Tafsir is missing for #{verse.verse_key}"
      end
    end

    issues
  end

  def check_for_missing_translation
    translations = Translation.where(resource_content_id: id)
    issues = []

    if !(6236 - translations.size).zero?
      issues.push("#{6236 - translations.size} missing translation record for (#{id} - #{name})")
    end

    if (missing_text = translations.where(text: [nil, ''])).any?
      issues.push "#{missing_text.size} translation with missing text(#{id} - #{name})"
    end

    issues
  end

  def update_related_content
    if translation?
      if priority_changed? || name_changed? || language_id_changed?
        Translation.where(resource_content_id: id).update_all(
          priority: priority,
          resource_name: name,
          language_name: language_name,
          language_id: language_id
        )
      end
    elsif tafsir?
      if priority_changed? || name_changed? || language_id_changed?
        Tafsir.where(resource_content_id: id).update_all(
          priority: priority,
          resource_name: name,
          language_name: language_name,
          language_id: language_id
        )
      end
    end
  end

  def fetch_metadata
    meta_data || {}
  end
end
