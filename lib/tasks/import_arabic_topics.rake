namespace :import do
  desc "Import scraped Arabic topics into Topics under 'Arabic Topics' ResourceContent"
  task arabic_topics: :environment do
    arabic = Language.where(name: "Arabic").first_or_create!(code: "ar")

    resource = ResourceContent.where(name: "Arabic Topics").first_or_create
    resource.sub_type = ResourceContent::SubType::Topic
    resource.cardinality_type = ResourceContent::CardinalityType::NVerse
    resource.language = arabic
    resource.save!

    file = Rails.root.join("lib", "data", "Complete_Topics_cleaned.json")
    unless File.exist?(file)
      puts "JSON file missing at #{file}"
      exit(1)
    end

    topics_data = JSON.parse(File.read(file))
    puts "Importing #{topics_data.size} main topics"

    topics_data.each_with_index do |entry, i|
      main_topic = Topic.where(
        resource_content_id: resource.id,
        name: entry["main_topic"]
      ).first_or_initialize
      main_topic.save!

      Array(entry["ayah_ids"]).each do |ayah_id|
        vt = VerseTopic.where(
          topic_id: main_topic.id,
          verse_id: ayah_id,
          ontology: false,
          thematic: false
        ).first_or_initialize
        vt.save!
      end

      Array(entry["children"]).each do |child|
        child_topic = Topic.where(
          resource_content_id: resource.id,
          name: child["name"],
          parent_id: main_topic.id
        ).first_or_initialize
        child_topic.save!

        Array(child["ayah_ids"]).each do |ayah_id|
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
