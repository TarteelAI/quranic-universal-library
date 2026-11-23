# frozen_string_literal: true

namespace :catalog do
  desc 'Give a slug to every resource that has none and report the rows changed'
  task backfill: :environment do
    report = Catalog::Backfill.run
    report.each { |step, rows| puts "#{step}: #{rows} rows changed" }
    puts "total: #{report.values.sum} rows changed"
  end

  desc 'Write the review report (known data errors) to a file under tmp/'
  task :review_report, [:path] => :environment do |_task, args|
    tmp = Rails.root.join('tmp')
    path = Pathname(args[:path].presence || tmp.join('catalog-review-report.md')).expand_path
    raise ArgumentError, "the report goes under #{tmp}/" unless path.to_s.start_with?("#{tmp}/")

    rows = Catalog::ReviewReport.new.write(path)
    puts "#{path}: #{rows} rows"
  end
end
