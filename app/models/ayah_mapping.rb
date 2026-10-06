# == Schema Information
#
# Table name: ayah_mappings
#
#  merges_with_next :boolean          default(FALSE), not null
#  relation         :string           not null
#  ayah_id          :integer          not null
#  ayah_last_id     :integer
#  numbering_id     :integer          not null, primary key
#  verse_id         :integer          not null, primary key
#
# Indexes
#
#  index_ayah_mappings_on_ayah_id  (ayah_id)
#
# Forward map: Kufi verse -> ayah (or ayah range, when the verse splits) in
# one numbering. Precomputed from numbered_ayahs anchors so a conversion is
# one primary-key read. The reverse direction uses the anchors on
# numbered_ayahs and is lossy at splits, as the upstream docs warn.
class AyahMapping < QuranApiRecord
  self.primary_key = %i[numbering_id verse_id]

  belongs_to :numbering, class_name: 'AyahNumbering'
  belongs_to :verse
  belongs_to :ayah, class_name: 'NumberedAyah'
  belongs_to :ayah_last, class_name: 'NumberedAyah', optional: true

  validates :relation, inclusion: { in: NumberedAyah::RELATIONS }

  # Every numbered ayah the Kufi verse lands on, in order (one, or the split range).
  def ayahs
    return [ayah] unless ayah_last_id

    NumberedAyah.where(numbering_id: numbering_id, chapter_id: ayah.chapter_id, ayah_number: ayah.ayah_number..ayah_last.ayah_number).in_order.to_a
  end

  def split?
    relation == 'split'
  end
end
