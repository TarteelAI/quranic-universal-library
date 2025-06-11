namespace :import do
  task arabic_topics: :environment do
    arabic = Language.find_by(iso_code: 'ar')

    resource = ResourceContent.where(name: "Arabic Topics").first_or_create!
    resource.update!(
      resource_type_name: 'content',
      sub_type: ResourceContent::SubType::Topic,
      cardinality_type: ResourceContent::CardinalityType::NVerse,
      language: arabic
    )
    resource.translated_names.where(language: arabic).first_or_create!(
      name: 'موسوعة موضوعات القرآن الكريم'
    )

    file = Rails.root.join("data", "arabic-topics.json")
    topics_data = JSON.parse(File.read(file))

    topics_data.each_with_index do |entry|
      main_name = entry["main_topic"]
      main_topic = Topic.find_or_initialize_by(
        resource_content_id: resource.id,
        name: main_name
      )
      main_topic.save(validate: false)

      verse_ids = Array(entry["ayah_ids"])
      children = Array(entry["children"])

      if children.one? && children.first["name"] == main_name
        verse_ids += Array(children.first["ayah_ids"])
      end

      verse_ids.uniq.each do |ayah_id|
        VerseTopic.find_or_create_by!(
          topic_id: main_topic.id,
          verse_id: ayah_id,
          ontology: false,
          thematic: false
        )
      end

      next if children.one? && children.first["name"] == main_name

      children.each do |child|
        child_name = child["name"]
        child_topic = Topic.find_or_initialize_by(
          resource_content_id: resource.id,
          name: child_name,
          parent_id: main_topic.id
        )
        child_topic.save!

        Array(entry["ayah_ids"]).uniq.each do |ayah_id|
          VerseTopic.find_or_create_by!(
            topic_id: child_topic.id,
            verse_id: ayah_id,
            ontology: false,
            thematic: false
          )
        end
      end
    end

    resource.update_records_count
    puts "Finished: records_count = #{resource.records_count}"
  end
end
