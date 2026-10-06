# == Schema Information
#
# Table name: ayah_texts
#
#  text      :text             not null
#  ayah_id   :integer          not null, primary key
#  script_id :integer          not null, primary key
#
# Cache of the joined ayah text per script, keyed by the numbered ayah
# (numbered_ayahs, phase 4; equal to the Kufi verse id for Kufi scripts).
# The analogue of verses.text_qpc_hafs for every script stored as rows.
class AyahText < QuranApiRecord
  self.primary_key = %i[script_id ayah_id]

  belongs_to :script

  validates :text, presence: true

  scope :for_script, ->(script) { where(script_id: script) }

  def self.ransackable_associations(_auth_object = nil)
    %w[script]
  end
end
