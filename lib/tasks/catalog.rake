namespace :catalog do
  desc 'Run every catalog backfill in order and report the rows each one changed'
  task backfill: :environment do
    report = Catalog::Backfill.run
    report.each { |step, rows| puts "#{step}: #{rows} rows changed" }
    puts "total: #{report.values.sum} rows changed"
  end

  desc 'Mark the drafted values of a resource (slug or id) reviewed, or one field of it, without changing them'
  task :mark_reviewed, %i[resource field] => :environment do |_task, args|
    resource = DownloadableResource.find_by_slug_or_id!(args.fetch(:resource))
    field = args[:field].presence
    raise ArgumentError, "#{field} holds no drafted value on #{resource.to_param}" if field && resource.reviewed?(field)

    marked = resource.mark_reviewed!(field)
    puts "#{resource.to_param}: marked reviewed #{marked.empty? ? 'nothing' : marked.join(', ')}"
  end

  desc 'Write the review report (drafted values and known data errors) to a file under tmp/'
  task :review_report, %i[path] => :environment do |_task, args|
    tmp = Rails.root.join('tmp')
    path = Pathname(args[:path].presence || tmp.join('catalog-review-report.md')).expand_path
    raise ArgumentError, "the report goes under #{tmp}/" unless path.to_s.start_with?("#{tmp}/")

    rows = Catalog::ReviewReport.new.write(path)
    puts "#{path}: #{rows} drafted values"
  end
end
