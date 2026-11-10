# frozen_string_literal: true

namespace :typelizer do
  desc 'Fail when the committed TypeScript types or route helpers differ from what the serializers and routes generate'
  task check: :environment do
    abort 'typelizer:check runs in development (or with TYPELIZER=true).' unless Typelizer.enabled?

    committed = {
      Typelizer.configuration.output_dir => Pathname(Dir.mktmpdir('typelizer-types')),
      Typelizer.configuration.routes.output_dir => Pathname(Dir.mktmpdir('typelizer-routes'))
    }
    types_dir, routes_dir = committed.values

    begin
      Typelizer.configure do |config|
        config.output_dir = types_dir
        config.routes.output_dir = routes_dir
      end
      Typelizer::Generator.call(force: true, skip_check: true)
      Typelizer::RouteGenerator.call(force: true, skip_check: true)

      files_in = ->(dir) { Dir.glob('**/*', base: dir).select { |file| File.file?(File.join(dir, file)) } }
      stale = committed.flat_map do |committed_dir, fresh_dir|
        (files_in.call(committed_dir) | files_in.call(fresh_dir)).reject do |file|
          committed_file = File.join(committed_dir, file)
          fresh_file = File.join(fresh_dir, file)
          File.exist?(committed_file) && File.exist?(fresh_file) && FileUtils.identical?(committed_file, fresh_file)
        end.map { |file| Pathname(committed_dir).join(file).relative_path_from(Rails.root) }
      end

      if stale.any?
        warn "Generated TypeScript is stale. Run bin/rails typelizer:generate:refresh and commit:\n  #{stale.join("\n  ")}"
        exit 1
      end

      puts 'Generated TypeScript types and route helpers are up to date.'
    ensure
      committed.each_value { |dir| FileUtils.rm_rf(dir) }
    end
  end
end
