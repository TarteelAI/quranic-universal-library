# frozen_string_literal: true

# A record that belongs to one riwayah (mushafs, recitations, audio_recitations)
# through riwayah_id. The legacy qirat_type_id column, the QiratType alias and
# the qirat_type readers were dropped in P7.5.
module HasRiwayah
  extend ActiveSupport::Concern

  included do
    belongs_to :riwayah, class_name: 'Riwayah', optional: true
  end

  class_methods do
    def riwayah_ransackable_associations
      %w[riwayah]
    end
  end
end
