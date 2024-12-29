# == Schema Information
#
# Table name: mushaf_line_alignments
#
#  id          :bigint           not null, primary key
#  alignment   :string
#  line_number :integer
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
  belongs_to :mushaf
  after_commit :update_page_lines_count

  def self.dummy
    MushafLineAlignment.new
  end

  def get_surah_number
    properties['surah_number'] if is_surah_name?
  end

  def is_center_aligned?
    properties['center'] || alignment == 'center'
  end

  def is_bismillah?
    properties['bismillah'] || alignment == 'bismillah'
  end

  def is_surah_name?
    properties['surah_name'] || alignment == 'surah_name'
  end

  def is_justified?
    properties.blank? && alignment.blank?
  end

  def clear!
    self.alignment = nil
    self.properties = {}
    self.destroy
  end

  def update_page_lines_count
    MushafPage.find_by(
      mushaf_id: mushaf_id,
      page_number: page_number
    )&.update_lines_count
  end
end
