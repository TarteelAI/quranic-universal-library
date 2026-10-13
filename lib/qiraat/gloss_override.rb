# frozen_string_literal: true

module Qiraat
  # Writes and removes per-riwayah word glosses (P6.3): the override rows of
  # word_translations (riwayah_id set, see RiwayahOverride) for the riwayat
  # that share one spelling of a differing word.
  #
  #   Qiraat::GlossOverride.new(difference, resource_content).apply(group: 2, text: 'King', by: user)
  #     # => one row per riwayah of spelling group 2 (Hafs excluded: its gloss is the shared row)
  #   Qiraat::GlossOverride.new(difference, resource_content).remove(riwayah)
  #
  # The shared row of the word (riwayah_id NULL) is never touched; it stays
  # what every riwayah without an override reads. Overrides take effect in
  # the for_riwayah readers at once: nothing public reads them yet (P6.4+),
  # and the resource's own approval still gates the whole resource.
  class GlossOverride
    attr_reader :difference, :resource_content

    def initialize(difference, resource_content)
      @difference = difference
      @resource_content = resource_content
    end

    def word_id
      difference.word_id
    end

    # The shared gloss every riwayah reads unless overridden (nil when the resource has none for this word).
    def shared
      WordTranslation.shared.find_by(word_id: word_id, resource_content_id: resource_content.id)
    end

    # riwayah slug => override row
    def overrides
      WordTranslation.overrides.where(word_id: word_id, resource_content_id: resource_content.id).includes(:riwayah).index_by { |t| t.riwayah.slug }
    end

    # One override row per riwayah of spelling group `group` (Hafs excluded),
    # created or updated; marks the word overridden. Returns the rows.
    def apply(group:, text:, by:)
      text = text.to_s.strip
      raise ArgumentError, 'empty gloss' if text.blank?

      riwayat = difference.override_riwayat(group.to_i)
      raise ArgumentError, "spelling group #{group} has no riwayah to override (Hafs reads the shared row)" if riwayat.empty?

      base = shared
      rows = WordTranslation.transaction do
        riwayat.map do |riwayah|
          row = WordTranslation.find_or_initialize_by(word_id: word_id, resource_content_id: resource_content.id, riwayah_id: riwayah.id)
          row.assign_attributes(text: text, language_id: base&.language_id || resource_content.language_id, language_name: base&.language_name || resource_content.language_name, priority: base&.priority)
          row.save!
          row
        end
      end
      difference.decide!('overridden', by: by, note: difference.review['note'])
      rows
    end

    # Drops the override of one riwayah; the word goes back to "needs decision" when no override is left.
    def remove(riwayah, by:)
      WordTranslation.overrides.where(word_id: word_id, resource_content_id: resource_content.id, riwayah_id: riwayah.id).destroy_all
      left = WordTranslation.overrides.where(word_id: word_id).exists?
      difference.decide!(left ? 'overridden' : nil, by: by) if difference.decision == 'overridden'
    end
  end
end
