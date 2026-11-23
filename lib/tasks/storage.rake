# frozen_string_literal: true

namespace :storage do
  # The object's size, or nil when there is none. Any other error is about the service, not the row.
  size_of = lambda do |service, key|
    if service.respond_to?(:bucket)
      service.bucket.client.head_object(bucket: service.bucket.name, key: key).content_length
    else
      path = service.path_for(key)
      File.size(path) if File.file?(path)
    end
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    nil
  end

  desc 'Check every active_storage_blobs row has its object, at its byte size, in its service ' \
       '(HEAD requests only). Optional: the service names to check, e.g. storage:verify[qul_exports]'
  task verify: :environment do |_task, args|
    names = args.extras.presence || ActiveStorage::Blob.distinct.order(:service_name).pluck(:service_name)

    failed = false
    names.each do |name|
      blobs = ActiveStorage::Blob.where(service_name: name)
      # Registry#fetch takes no default argument, only a block.
      service = ActiveStorage::Blob.services.fetch(name.to_sym) { nil } # rubocop:disable Style/RedundantFetchBlock
      unless service
        puts "#{name}: not configured, #{blobs.count} rows not checked"
        blobs.pluck(:key).each { |key| puts "  unconfigured #{key}" }
        next
      end

      counts = Hash.new(0)
      begin
        blobs.in_batches(of: 1000) do |batch|
          batch.pluck(:key, :byte_size).each do |key, byte_size|
            size = size_of.call(service, key)
            if size.nil?
              counts[:missing] += 1
              puts "  missing #{name} #{key}"
            elsif size == byte_size
              counts[:ok] += 1
            else
              counts[:differ] += 1
              puts "  differs #{name} #{key}: #{size} bytes stored, #{byte_size} in the row"
            end
          end
        end
      rescue StandardError => e
        failed = true
        puts "#{name}: cannot read the storage (#{e.class}: #{e.message.lines.first&.strip}), " \
             "stopped after #{counts.values.sum} of #{blobs.count} rows"
        next
      end

      failed ||= counts[:missing].positive? || counts[:differ].positive?
      puts "#{name}: #{blobs.count} rows, #{counts[:ok]} ok, #{counts[:missing]} missing, #{counts[:differ]} differ"
    end

    abort 'storage:verify: failed' if failed
    puts 'storage:verify: every checked object is present at its size'
  end

  desc 'Set byte_size and checksum from the stored object on rows whose size differs from it. ' \
       'Names the services, e.g. storage:fix_sizes[qul_exports]. Missing objects are left alone.'
  task fix_sizes: :environment do |_task, args|
    abort 'storage:fix_sizes: name the services, e.g. storage:fix_sizes[qul_exports]' if args.extras.empty?

    args.extras.each do |name|
      service = ActiveStorage::Blob.services.fetch(name.to_sym)
      fixed = 0
      ActiveStorage::Blob.where(service_name: name).find_each do |blob|
        size = size_of.call(service, blob.key)
        next if size.nil? || size == blob.byte_size

        digest = Digest::MD5.new
        service.download(blob.key) { |chunk| digest << chunk }
        puts "  fixed #{name} #{blob.key}: #{blob.byte_size} -> #{size} bytes"
        # No callbacks: the row is corrected to match its file, nothing is uploaded.
        blob.update_columns(byte_size: size, checksum: digest.base64digest)
        fixed += 1
      end
      puts "#{name}: #{fixed} rows fixed"
    end
  end
end
