namespace :import do
  task arabic_topics: :environment do
    arabic = Language.find_by(iso_code: 'ar')

    resource = ResourceContent.where(name: "Arabic Topics").first_or_create
    resource.resource_type_name = 'content'
    resource.sub_type = ResourceContent::SubType::Topic
    resource.cardinality_type = ResourceContent::CardinalityType::NVerse
    resource.language = arabic
    resource.save!
    resource.translated_names.where(language: arabic).first_or_create(
      name: 'موسوعة موضوعات القرآن الكريم'
    )

    file = Rails.root.join("data", "arabic-topics.json.json")
    topics_data = JSON.parse(File.read(file))

    topics_data.each_with_index do |entry, i|
      main_topic = Topic.where(
        resource_content_id: resource.id,
        name: entry["main_topic"]
      ).first_or_initialize
      main_topic.save(validate: false)

      verse_ids = entry["ayah_ids"] || []
      if entry["children"].size == 1
        child_verses = entry["children"][0]["ayah_ids"] || []
        verse_ids += child_verses
      end

      verse_ids.each do |ayah_id|
        vt = VerseTopic.where(
          topic_id: main_topic.id,
          verse_id: ayah_id,
          ontology: false,
          thematic: false
        ).first_or_initialize
        vt.save!
      end
      next if entry["children"].size == 1

      entry["children"].each do |child|
        child_topic = Topic.where(
          resource_content_id: resource.id,
          name: child["name"],
          parent_id: main_topic.id
        ).first_or_initialize
        child_topic.save!
        verse_ids = entry["ayah_ids"] || []

        verse_ids.each do |ayah_id|
          cvt = VerseTopic.where(
            topic_id: child_topic.id,
            verse_id: ayah_id,
            ontology: false,
            thematic: false
          ).first_or_initialize
          cvt.save!
        end
      end
    end

    resource.update_records_count
    puts "Finished: records_count = #{resource.records_count}"
  end
end
