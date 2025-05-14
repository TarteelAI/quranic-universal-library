namespace :import do
  desc "Import scraped Arabic topics into Topics under 'Arabic Topics' ResourceContent"
  task arabic_topics: :environment do

    arabic = Language.where(name: "Arabic").first_or_create!(code: "ar")


    resource = ResourceContent
                 .where(name: "Arabic Topics")
                 .first_or_create

    resource.sub_type         = ResourceContent::SubType::Topic
    resource.cardinality_type = ResourceContent::CardinalityType::NVerse
    resource.language         = arabic
    resource.save!

    puts "Using ResourceContent ##{resource.id} – #{resource.name} (lang=#{resource.language_name})"

    file = Rails.root.join("lib", "data", "Complete_Topics_cleaned.json")
    unless File.exist?(file)
      puts "JSON file missing at #{file}"
      exit(1)
    end

    topics_data = JSON.parse(File.read(file))
    puts "#{topics_data.size} main topics to import."

    topics_data.each_with_index do |entry, i|
      main_name     = entry["main_topic"]
      children_data = entry["children"] || []

      puts "\n[#{i+1}/#{topics_data.size}] Main topic: #{main_name}"

      main_topic = Topic.where(
        resource_content_id: resource.id,
        name:                main_name
      ).first_or_initialize

      if main_topic.new_record?
        main_topic.save!
        puts "Created main topic"
      else
        puts "Main topic exists (ID=#{main_topic.id})"
      end

      children_data.each do |child|
        child_topic = Topic.where(
          resource_content_id: resource.id,
          name:                child["name"],
          parent_id:           main_topic.id
        ).first_or_initialize

        if child_topic.new_record?
          child_topic.save!
          puts "Child: #{child_topic.name}"
        else
          puts "Child exists: #{child_topic.name} (ID=#{child_topic.id})"
        end
      end
    end

    resource.update_records_count
    puts "\nFinished! ResourceContent.records_count = #{resource.reload.records_count}"
    puts "In Admin: ResourceContents → filter by ‘Arabic Topics’ to review."
  end
end
