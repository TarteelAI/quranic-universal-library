# frozen_string_literal: true

# A record that belongs to one riwayah (mushafs, recitations, audio_recitations).
#
# The column is riwayah_id. The legacy qirat_type_id column is still present
# and is kept equal to riwayah_id on every save, in both directions, so code
# that still reads or writes the old name keeps working until phase 7 drops it.
# `qirat_type` / `qirat_type=` are plain aliases of the association.
module HasRiwayah
  extend ActiveSupport::Concern

  included do
    belongs_to :riwayah, class_name: 'Riwayah', optional: true

    before_save :sync_legacy_qirat_type_id

    alias_method :qirat_type, :riwayah
    alias_method :qirat_type=, :riwayah=
  end

  class_methods do
    # Ransack: let admin filters use either name.
    def riwayah_ransackable_associations
      %w[riwayah qirat_type]
    end
  end

  private

  def sync_legacy_qirat_type_id
    return unless has_attribute?(:qirat_type_id)

    if will_save_change_to_riwayah_id?
      self[:qirat_type_id] = riwayah_id
    elsif will_save_change_to_qirat_type_id?
      self[:riwayah_id] = self[:qirat_type_id]
    end
  end
end
