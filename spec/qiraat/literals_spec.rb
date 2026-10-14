# frozen_string_literal: true

require 'rails_helper'

# P7.1: the Kufi/Hafs numbers that used to be typed into the code now come
# from the numbering or mushaf in scope. This spec is the audit: every
# remaining 6236 / 604 / FIRST_AYAH in app/ and lib/ must be one of the
# allowed sites below (comments, the Kufi table the JS helper ships with,
# the fallback constant, and one-off data scripts about specific prints).
RSpec.describe 'numeric Quran literals (P7.1)' do
  ALLOWED = [
    'app/javascript/utils/quran.js',                      # the Kufi first-ayah table and its explanation (P4.5)
    'app/models/mushaf.rb',                                # FALLBACK_PAGES_COUNT, with its comment
    'app/controllers/internal/numberings_controller.rb',   # comment showing the JSON shape
    'app/views/admin/_compare_draft_tafsir_ayah_grouping.html.erb', # comment
    'app/views/shared/_mushaf_page_svg.html.erb',          # prose about the SVG dataset
    'lib/utils/quran.rb',                                  # legacy fallback tables (P4.5)
    'lib/internal/',                                       # downloaders of specific 604-page sources
    'lib/tasks/one_time.rake', 'lib/tasks/grammar.rake', 'lib/tasks/tajweed.rake', # one-off creation of specific Hafs prints
    'lib/tasks/qiraat/', 'lib/qiraat/'                     # the riwayah tooling checks the Kufi totals on purpose
  ].freeze

  it 'leaves 6236, 604 and FIRST_AYAH only at the allowed sites' do
    out = `grep -rnE '6236|\\b604\\b|FIRST_AYAH' app lib --include='*.rb' --include='*.rake' --include='*.erb' --include='*.js' --include='*.haml' 2>/dev/null`
    hits = out.lines.map { |l| l.split(':', 2).first }.reject { |f| f.start_with?('app/assets/builds/') }.uniq
    unexpected = hits.reject { |f| ALLOWED.any? { |a| f.start_with?(a) } }
    expect(unexpected).to eq([])
  end

  it 'reads the Kufi total and the glyph page count from the data' do
    expect(Utils::Quran.total_ayahs).to eq(6236)
    expect(Script.glyph_pages_count).to eq(Mushaf::FALLBACK_PAGES_COUNT) # the slice has no glyph mushaf: the fallback
  end
end
