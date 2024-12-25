namespace :create_font_resources do
  task :create do
    fonts = [
      {
        name: "V4 Surah Name Font",
        tags: ["v4", "surah-names"],
        cardinality: ResourceContent::CardinalityType::OneChapter,
        meta_data: {
          text: 's001',
          font_face: 'v4-surah-name'
        }
      },
      {
        name: "QPC V1 Font",
        cardinality: ResourceContent::CardinalityType::OnePage,
        tags: ["QPC", "V1", "Glyph based"],
        meta_data: {
          script: 'code_v1',
          font_face: 'p1-v1'
        }
      },
      {
        name: "QPC V2 Font",
        cardinality: ResourceContent::CardinalityType::OnePage,
        tags: ["QPC", "V2", "Glyph based"],
        meta_data: {
          script: 'code_v2',
          font_face: 'p1-v2'
        }
      },
      {
        name: "QPC V4 Tajweed Font",
        cardinality: ResourceContent::CardinalityType::OnePage,
        tags: ["QPC", "V4", "Glyph based", "Tajweed"],
        meta_data: {
          script: 'code_v2',
          font_face: 'p1-v4'
        }
      },
      {
        name: 'Digital Khatt',
        cardinality: ResourceContent::CardinalityType::OnePage,
        tags: ["Variable font", "Unicode text"],
        meta_data: {
          script: 'text_digital_khatt',
          font_face: 'digitalkhatt'
        }
      },
      {
        name: "Indopak Nastaleeq",
        cardinality: ResourceContent::CardinalityType::Quran,
        tags: ["Indopak", "Unicode text"],
        meta_data: {
          script: 'text_indopak_nastaleeq',
          font_face: 'indopak-nastaleeq'
        }
      },
      {
        name: "Me Quran Font",
        cardinality: ResourceContent::CardinalityType::Quran,
        tags: ["Madani", "Unicode text"],
        meta_data: {
          script: 'text_uthmani',
          font_face: 'me_quran'
        }
      },
      {
        name: "PDMS Saleem Font",
        cardinality: ResourceContent::CardinalityType::Quran,
        tags: ["Indopak", "Unicode text"],
        meta_data: {
          script: 'text_indopak'
        }
      },
      {
        name: "QPC Hafs font",
        cardinality: ResourceContent::CardinalityType::Quran,
        tags: ["QPC", "Unicode text"],
        meta_data: {
          script: 'text_qpc_hafs',
          font_face: 'qpc-hafs'
        }
      }
    ]

    fonts.each do |font|
      resource = ResourceContent.where(name: font[:name], sub_type: 'font').first_or_create
      download_resource = DownloadableResource.where(name: font[:name], resource_content: resource).first_or_create
      download_resource.cardinality_type = font[:cardinality]
      download_resource.resource_type = 'fonts'
      download_resource.tags = font[:tags].join(', ')
      download_resource.meta_data= font[:meta_data] || {}
      download_resource.save!
    end
  end
end