# == Schema Information
#
# Table name: navigation_search_records
#
#  id                     :bigint           not null, primary key
#  key                    :string
#  name                   :string
#  result_type            :string
#  searchable_record_type :string
#  text                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  searchable_record_id   :bigint
#
# Indexes
#
#  index_navigation_search_records_on_result_type        (result_type)
#  index_navigation_search_records_on_searchable_record  (searchable_record_type,searchable_record_id)
#  index_navigation_search_records_on_text               (text)
#

class NavigationSearchRecord < QuranApiRecord
  belongs_to :searchable_record, polymorphic: true, optional: true
  before_create :set_name_and_key

  scope :for_surah, -> { where(searchable_record_type: 'Chapter') }

  def self.search(text)
    record = where('LOWER(text) = ?', text.to_s.downcase.strip).first
    record&.searchable_record
  end

  protected

  def set_name_and_key
    self.attributes = default_navigation_attributes
  end

  def default_navigation_attributes
    if searchable_record.is_a?(Chapter)
      {
        key: searchable_record.id,
        name: "Surah #{searchable_record.name_simple}",
        result_type: 'surah'
      }
    elsif searchable_record.is_a?(Verse)
      {
        key: searchable_record.verse_key,
        name: "Surah #{searchable_record.chapter.name_simple}, verse #{searchable_record.verse_number}",
        result_type: 'ayah'
      }
    elsif searchable_record.is_a?(MushafPage)
      {
        key: searchable_record.page_number,
        name: "Page #{searchable_record.page_number}",
        result_type: 'page'
      }
    elsif searchable_record.is_a?(Juz)
      {
        key: searchable_record.juz_number,
        name: "Juz #{searchable_record.juz_number}",
        result_type: 'juz'
      }
    end
  end
end
