namespace :one_time do
  desc "Normalize spacing between letters in roots.arabic_trilateral to a single space"
  task fix_root_spacing: :environment do
    fixed = 0

    Root.find_each do |root|
      value = root.arabic_trilateral
      next if value.blank?

      normalized = value.strip.gsub(/\s+/, ' ')
      next if normalized == value

      root.update_columns(arabic_trilateral: normalized)
      fixed += 1
    end

    puts "Normalized #{fixed} roots"
  end
end
