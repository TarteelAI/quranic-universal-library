# frozen_string_literal: true

# The riwayah a tool page is looked at through (P6.4/P6.5): read from the
# `riwayah` parameter, nil for Hafs or when absent, so every page keeps its
# old (shared, Kufi) behaviour unless another riwayah is chosen. Presenters
# that include it expose the riwayah's resolver, script, mushaf and the ayah
# keys of Kufi verses in its numbering; `resource` is the presenter's.
module RiwayahSelection
  def riwayah
    return @riwayah if defined?(@riwayah)

    slug = params[:riwayah].presence
    @riwayah = slug && slug != 'hafs' ? Riwayah.find_by(slug: slug) : nil
  end

  # riwayat a reviewer can pick: those whose text QUL holds as rows (the quran-text scripts)
  def riwayah_options
    [['Hafs (default)', 'hafs']] + Script.row_backed.includes(:riwayah).map(&:riwayah).compact.uniq.sort_by(&:id).map { |r| [r.name, r.slug] }
  end

  def resolver
    @resolver ||= riwayah && Qiraat::Resolver.for(riwayah)
  end

  def riwayah_script
    @riwayah_script ||= riwayah && Script.row_backed.find_by(riwayah_id: riwayah.id)
  end

  # the generated (or verified) layout of the riwayah, for page bounds
  def riwayah_mushaf
    @riwayah_mushaf ||= riwayah && Mushaf.where(riwayah_id: riwayah.id, layout_source: Mushaf::GENERATED_LAYOUT_SOURCES).order(:id).first
  end

  def pages_count
    riwayah_mushaf&.pages_count || 604
  end

  def font_class
    riwayah_script&.font_css_class || 'qpc-hafs'
  end

  # url params that keep the selection across a tool's links
  def link_params(extra = {})
    { resource_id: resource&.id, riwayah: riwayah&.slug }.compact.merge(extra)
  end

  # the numbered ayahs of the riwayah a Kufi verse lands on (two for a split)
  def mapped_ayahs(verse)
    resolver ? resolver.from_kufi(verse) : []
  end

  # verse_id => [ayah keys in the riwayah numbering], one query for a page of verses
  def ayah_keys_for(verses)
    return {} unless riwayah

    ids = verses.map(&:id)
    AyahMapping.where(numbering_id: resolver.numbering.id, verse_id: ids).includes(:ayah).to_h { |m| [m.verse_id, m.ayahs.map(&:ayah_key)] }
  end

  # "3 (Kufi 4)", "6–7 (Kufi 7)" for a split; the plain Kufi number without a riwayah
  def ayah_label(verse)
    return verse.verse_number.to_s unless riwayah

    keys = mapped_ayahs(verse).map { |a| a.ayah_key.split(':').last }
    keys.any? ? "#{keys.join('–')} (Kufi #{verse.verse_number})" : "(Kufi #{verse.verse_number})"
  end
end
