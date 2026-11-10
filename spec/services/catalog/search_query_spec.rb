require 'clone_helper'

# The catalog search runs over the published catalog on the clone. Expected rows come from
# direct queries; rows the clone lacks are created inside the example's transaction.
RSpec.describe Catalog::SearchQuery do
  def search(per_page: described_class::PER_PAGE, **filters)
    described_class.new(Catalog::SearchFilters.from(filters), per_page: per_page).call
  end

  def ids(result)
    result.matches.map { |row| row.resource.id }
  end

  let(:published) { DownloadableResource.published }

  # Resource content rows no catalog resource uses yet (a resource needs its own one).
  let(:free_contents) do
    ResourceContent.where.not(id: DownloadableResource.where.not(resource_content_id: nil).pluck(:resource_content_id))
                   .order(:id).limit(5).to_a
  end

  def create_resource(name, **attributes)
    DownloadableResource.create!(name: name, resource_type: 'tafsir', cardinality_type: '1_ayah', published: true,
                                 resource_content: free_contents.shift, **attributes)
  end

  # Script families on a few scripts, fonts and layouts, whether or not the clone has drafted
  # them yet.
  def assign_script_families
    { 'quran-script' => %w[madani madani indopak], 'font' => %w[madani indopak], 'mushaf-layout' => %w[other] }
      .each do |type, families|
        published.where(resource_type: type).order(:id).first(families.size).zip(families)
                 .each { |resource, family| resource.update_columns(script_family: family) }
      end
  end

  # Published resources whose language (the CMS row's, else the content row's) is `language`.
  def published_in(language)
    content_ids = ResourceContent.where(language_id: language.id).ids
    published.where(language_id: language.id).ids +
      published.where(language_id: nil, resource_content_id: content_ids).ids
  end

  describe 'text search' do
    it 'returns every published resource for an empty query' do
      expect(ids(search)).to match_array(published.ids)
      expect(ids(search(q: '   '))).to match_array(published.ids)
    end

    it 'matches an Arabic name with and without diacritics' do
      voweled = create_resource('تَفْسِيرُ السَّعْدِيِّ')
      plain = create_resource('تفسير ابن كثير')

      expect(ids(search(q: 'تفسير السعدي'))).to eq([voweled.id])
      expect(ids(search(q: 'تَفْسِيرُ ابْنِ كَثِيرٍ'))).to eq([plain.id])
      expect(ids(search(q: 'تفسير'))).to include(voweled.id, plain.id)
    end

    it 'matches an Arabic tag with and without diacritics' do
      resource = published.find_by!(resource_type: 'mushaf-layout')
      tag = DownloadableResourceTag.create!(name: 'مُصْحَفُ المَدِينَةِ')
      DownloadableResourceTagging.create!(downloadable_resource: resource, downloadable_resource_tag: tag)

      expect(ids(search(q: 'مصحف المدينة'))).to eq([resource.id])
      expect(ids(search(q: 'مُصْحَف'))).to eq([resource.id])
    end

    it "matches a language's native name in Arabic, with and without diacritics" do
      arabic = Language.find_by!(iso_code: 'ar')
      expected = published_in(arabic)
      expect(expected).not_to be_empty

      expect(ids(search(q: 'العربية'))).to include(*expected)
      expect(ids(search(q: 'الْعَرَبِيَّة'))).to include(*expected)
      expect(ids(search(q: 'العربيه'))).to include(*expected)
    end

    it 'matches Latin text without regard to case or accents' do
      czech = Language.find_by!(iso_code: 'cs')
      expect(czech.native_name).to eq('Čeština')
      expected = published_in(czech)
      expect(expected).not_to be_empty

      %w[Čeština cestina CESTINA ČEŠTINA].each do |query|
        expect(ids(search(q: query))).to include(*expected), query
      end
      expect(ids(search(q: 'ENGLISH'))).to eq(ids(search(q: 'english')))
    end

    it "finds a language's translations by the language name" do
      urdu = Language.find_by!(iso_code: 'ur')
      translations = published.where(resource_type: 'translation').where(id: published_in(urdu)).ids
      expect(translations).not_to be_empty

      expect(ids(search(q: 'Urdu'))).to include(*translations)
      expect(ids(search(q: 'urdu', type: 'translation'))).to match_array(translations)
    end

    it 'needs every word of the query to match' do
      resource = create_resource('Tafsir Zyxwv Qwertz')

      expect(ids(search(q: 'zyxwv qwertz'))).to eq([resource.id])
      expect(ids(search(q: 'zyxwv nothing-else'))).to be_empty
    end
  end

  describe 'filters' do
    it 'filters by type' do
      expect(ids(search(type: 'font'))).to match_array(published.where(resource_type: 'font').ids)
    end

    it 'filters by language' do
      urdu = Language.find_by!(iso_code: 'ur')
      expect(ids(search(language: 'ur'))).to match_array(published_in(urdu))
    end

    it 'filters by one script family, and by two together' do
      assign_script_families
      expect(published.where(script_family: 'indopak').count).to be >= 2

      expect(ids(search(script: ['indopak']))).to match_array(published.where(script_family: 'indopak').ids)
      expect(ids(search(script: %w[madani indopak])))
        .to match_array(published.where(script_family: %w[madani indopak]).ids)
    end

    it 'filters by format, through the published files' do
      sqlite_types = DownloadableFile.distinct.pluck(:file_type).compact
                                     .select { |type| type.downcase.end_with?('sqlite') }
      expected = published.joins(:downloadable_files)
                          .where(downloadable_files: { published: true, file_type: sqlite_types }).distinct.ids
      expect(expected).not_to be_empty

      expect(ids(search(format: 'sqlite'))).to match_array(expected)
    end

    it 'filters by granularity' do
      expect(ids(search(granularity: '1_word'))).to match_array(published.where(cardinality_type: '1_word').ids)
    end

    it 'filters by status, and stable keeps the recommended resources' do
      recommended = published.find_by!(resource_type: 'translation', status: 'stable')
      recommended.update_columns(recommended: true)

      stable = ids(search(status: 'stable'))
      expect(stable).to match_array(published.where(status: 'stable').ids)
      expect(stable).to include(recommended.id)
      expect(ids(search(status: 'legacy'))).to match_array(published.where(status: 'legacy').ids)
    end

    it 'combines filters with the text query' do
      expected = published.where(resource_type: 'translation', cardinality_type: '1_word').ids
      expect(ids(search(type: 'translation', granularity: '1_word'))).to match_array(expected)
    end

    it 'ignores values outside the vocabularies, and a language no published resource has' do
      assign_script_families
      result = search(type: 'nope', language: 'xx', script: %w[madani nope], format: 'exe', granularity: '2_ayah',
                      status: 'gone', sort: 'random', page: 'two')

      expect(result.filters.to_h).to include(type: nil, language: nil, script: ['madani'], format: nil,
                                             granularity: nil, status: nil, sort: 'popular', page: 1)
      expect(ids(result)).to match_array(published.where(script_family: 'madani').ids)
    end
  end

  describe 'facets' do
    before { assign_script_families }

    # For a sample of each facet's values, the count shown equals the total after selecting it.
    [{}, { type: 'translation' }, { q: 'quran' }, { granularity: '1_ayah', status: 'stable' }].each do |base|
      it "counts each facet value as the total that selecting it gives (#{base.inspect})" do
        result = search(**base)
        sampled = 0

        described_class::FACETS.each do |facet|
          counts = result.facets.fetch(facet)
          expect(counts).to be_present, facet.to_s if base.empty?

          counts.first(6).each do |value, count|
            selected = facet == :script ? [value] : value
            total = search(**base, facet => selected).total
            expect(count).to eq(total), "#{facet}=#{value} under #{base.inspect}"
            sampled += 1
          end
        end
        expect(sampled).to be >= (base.empty? ? 20 : 6)
      end
    end

    it "keeps each facet's own selection out of its counts" do
      result = search(type: 'font', script: ['madani'])

      expect(result.facets[:type].keys).to contain_exactly(
        *published.where(script_family: 'madani').distinct.pluck(:resource_type)
      )
      expect(result.facets[:type]['font']).to eq(published.where(resource_type: 'font', script_family: 'madani').count)
      indopak_fonts = published.where(resource_type: 'font', script_family: 'indopak').count
      expect(result.facets[:script]['indopak']).to eq(indopak_fonts)
    end
  end

  describe 'sorting' do
    let(:direct_totals) do
      published.joins('LEFT JOIN downloadable_files f ON f.downloadable_resource_id = downloadable_resources.id ' \
                      'AND f.published')
               .group('downloadable_resources.id')
               .sum('COALESCE(f.download_count, 0) + COALESCE(f.anonymous_download_count, 0)')
    end

    it 'orders by the combined download totals by default (popular)' do
      result = search
      expect(result.filters.sort).to eq('popular')

      totals = ids(result).map { |id| direct_totals.fetch(id) }
      expect(totals).to eq(direct_totals.values.sort.reverse)
      expect(totals.first).to be > 0
    end

    it 'counts anonymous downloads in the popular order' do
      least = ids(search).last
      DownloadableFile.create!(downloadable_resource_id: least, file_type: 'csv', anonymous_download_count: 10**9)

      expect(ids(search).first).to eq(least)
    end

    it 'never counts unpublished files, and never shows unpublished resources' do
      least = ids(search).last
      file = DownloadableFile.create!(downloadable_resource_id: least, file_type: 'csv', published: false,
                                      download_count: 10**9)
      hidden = create_resource('Zyxwv hidden tafsir', published: false)

      result = search
      expect(ids(result).last).to eq(least)
      expect(ids(result)).not_to include(hidden.id)
      expect(ids(search(q: 'zyxwv hidden'))).to be_empty
      expect(search(format: 'csv').matches.map { |row| row.resource.id }).not_to include(file.downloadable_resource_id)
      expect(result.facets[:type]['tafsir']).to eq(published.where(resource_type: 'tafsir').count)
    end

    it 'orders by name' do
      names = search(sort: 'name').matches.map { |row| Catalog::TextKey.call(row.resource.display_name) }
      expect(names).to eq(names.sort)
    end

    it 'orders by last update, newest first' do
      dates = search(sort: 'updated').matches.map(&:updated_at)
      expect(dates).to eq(dates.sort.reverse)
    end
  end

  describe 'paging' do
    it 'returns one page of the matches, and clamps the page number' do
      all = ids(search(sort: 'name'))
      second = search(sort: 'name', page: 2, per_page: 10)

      expect(second.results.map { |row| row.resource.id }).to eq(all[10, 10])
      expect(second).to have_attributes(total: all.size, page: 2, pages: (all.size / 10.0).ceil)

      last = search(sort: 'name', page: 10_000, per_page: 10)
      expect(last.page).to eq(last.pages)
      expect(last.results).to be_present
    end
  end

  it 'gives each row its formats from the published files, in the format vocabulary' do
    keys = Catalog::Taxonomy.formats.map(&:key)
    rows = search.matches

    expect(rows.flat_map(&:formats).uniq).to all(be_in(keys))
    with_json = rows.find { |row| row.resource.resource_type == 'translation' }
    expect(with_json.formats).to include('json')
  end
end
