# frozen_string_literal: true

module Internal
  # The ayah tables of a numbering for the browser tools (P4.5):
  #   GET /internal/numberings/kufi.json
  #   { "slug": "kufi", "total": 6236, "surah_ayah": [7, 286, ...], "first_ayah": [1, 8, ...] }
  # surah_ayah is counted ayahs per surah (index 0 = surah 1); first_ayah is
  # the 1-based global index of each surah's first ayah, so ayah arithmetic
  # in app/javascript/utils/quran.js can run against any numbering.
  class NumberingsController < ApplicationController
    skip_before_action :init_presenter, raise: false

    def show
      numbering = AyahNumbering.find_by!(slug: params[:slug])
      expires_in 1.day, public: true
      render json: {
        slug: numbering.slug,
        kind: numbering.kind,
        counting_system: numbering.counting_system&.slug,
        basmalah_counted: numbering.basmalah_counted,
        total: numbering.tables[:total],
        surah_ayah: numbering.surah_ayah_counts,
        first_ayah: numbering.first_ayah_indexes
      }
    end
  end
end
