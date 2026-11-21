require 'clone_helper'

# Every published recitation, translation, tafsir and transliteration gives a preview for the
# first and the last surah, without error (Previews.for in process, as the deferred prop does).
RSpec.describe 'Previews.for over every published audio and text resource' do
  it 'returns preview props for surah 1 and surah 114' do
    resources = DownloadableResource.published.where(resource_type: %w[recitation translation tafsir transliteration])
                                    .order(:id).preload(:resource_content).to_a
    counts = Hash.new(0)
    resources.product(%w[1 114]).each do |resource, surah|
      props = Previews.as_json(Previews.for(resource, 'surah' => surah))
      expect(props).to be_present, "#{resource.id} surah #{surah}"
      expect(props['kind']).to be_in(%w[recitation text unavailable]), "#{resource.id} surah #{surah}: #{props}"
      if props['kind'] == 'unavailable'
        counts["#{resource.resource_type} unavailable"] += 1
      else
        expect(props.dig('surah', 'number')).to eq(surah.to_i)
        counts["#{resource.resource_type} #{props['granularity']}"] += 1
      end
    end

    RSpec.configuration.reporter.message(
      "Swept #{resources.size} resources × 2 surahs: #{counts.sort.map { |key, count| "#{key} #{count}" }.join(', ')}"
    )
    expect(counts.values.sum).to eq(resources.size * 2)
  end
end
