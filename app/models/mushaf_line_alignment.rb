# == Schema Information
#
# Table name: mushaf_line_alignments
#
#  id          :bigint           not null, primary key
#  alignment   :string
#  line_number :integer
#  meta_data   :jsonb
#  page_number :integer
#  properties  :jsonb
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  mushaf_id   :integer
#
# Indexes
#
#  index_mushaf_line_alignments_on_line_number  (line_number)
#  index_mushaf_line_alignments_on_mushaf_id    (mushaf_id)
#  index_mushaf_line_alignments_on_page_number  (page_number)
#
class MushafLineAlignment < ApplicationRecord
  include HasMetaData
  belongs_to :mushaf

  scope :with_surah_names, -> { where alignment: 'surah_name' }

  after_commit :update_page_lines_count

  LineAlignments = [
    'center',
    'bismillah',
    'surah_name',
    'justified'
  ]

  def self.dummy
    MushafLineAlignment.new
  end

  def chapter
    if is_surah_name?
      Chapter.find_by(id: get_surah_number)
    end
  end

  def get_surah_number
    meta_value('surah_number') if is_surah_name?
  end

  def is_center_aligned?
    meta_value('center') || alignment == 'center'
  end

  def is_bismillah?
    meta_value('bismillah') || alignment == 'bismillah'
  end

  def is_surah_name?
    meta_value('surah_name') || alignment == 'surah_name'
  end

  def is_justified?
    meta_data.blank? && alignment.blank?
  end

  def clear!
    self.alignment = nil
    self.meta_data = {}
    self.destroy
  end

  def update_page_lines_count
    MushafPage.find_by(
      mushaf_id: mushaf_id,
      page_number: page_number
    )&.update_lines_count
  end
end
