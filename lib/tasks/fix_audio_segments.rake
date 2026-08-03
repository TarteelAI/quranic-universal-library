namespace :audio do
  desc 'Auto-fix mechanically-fixable segment issues for a gapless recitation. Dry-run by default; pass apply to persist. Usage: rake "audio:fix_segments[1]" or rake "audio:fix_segments[1,apply]"'
  task :fix_segments, [:recitation_id, :mode] => :environment do |_task, args|
    recitation = Audio::Recitation.find(args[:recitation_id])
    apply = args[:mode].to_s == 'apply'

    puts "Recitation #{recitation.id} — #{recitation.name}"
    puts(apply ? 'Mode: APPLY (changes will be saved)' : 'Mode: DRY-RUN (no changes saved, pass apply to persist)')
    puts '=' * 72

    segments = Audio::Segment
                 .where(audio_recitation_id: recitation.id)
                 .includes(:audio_file, verse: :actual_words)
                 .to_a

    result = Audio::SegmentAutoFixer.new(segments).run

    fixable = %w[ayah_timing ayah_overlap ayah_gap word_overlap]
    categories = (result.before.keys | result.after.keys | fixable).sort

    puts sprintf('%-18s %8s %8s %8s %8s', 'category', 'before', 'fixed', 'skipped', 'after')
    puts '-' * 72
    categories.each do |category|
      puts sprintf(
        '%-18s %8d %8d %8d %8d',
        category,
        result.before[category].to_i,
        result.fixed[category].to_i,
        result.skipped[category].to_i,
        result.after[category].to_i
      )
    end
    puts '-' * 72
    puts sprintf(
      '%-18s %8d %8s %8s %8d',
      'TOTAL',
      result.before.values.sum,
      result.fixed.values.sum,
      result.skipped.values.sum,
      result.after.values.sum
    )
    puts '=' * 72
    puts "Segments changed: #{result.changed_segments.size}"

    if result.skipped.values.sum.positive?
      puts "Skipped fixes could not be applied safely (would invert timestamps); review these manually."
    end

    if apply
      result.changed_segments.each { |segment| segment.save(validate: false) }
      recitation.update_columns(segments_count: recitation.audio_segments.count)
      puts "Saved #{result.changed_segments.size} segments."
    else
      puts 'Dry-run only. Re-run with apply to save these fixes.'
    end

    report = Audio::SegmentFixReport.new(
      recitation,
      result,
      applied: apply,
      generated_at: Time.current.strftime('%Y-%m-%d %H:%M %Z')
    )

    report_dir = Rails.root.join('tmp', 'segment_reports')
    FileUtils.mkdir_p(report_dir)
    report_path = report_dir.join("recitation_#{recitation.id}.html")
    File.write(report_path, report.to_html)

    puts '=' * 72
    puts "HTML report: #{report_path}"
  end
end
