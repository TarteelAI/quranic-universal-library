namespace :catalog do
  desc 'Run every catalog backfill in order and report the rows each one changed'
  task backfill: :environment do
    report = Catalog::Backfill.run
    report.each { |step, rows| puts "#{step}: #{rows} rows changed" }
    puts "total: #{report.values.sum} rows changed"
  end
end
