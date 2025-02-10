class QulExportedFileKeyGenerator
  def self.generate_key(file_path, resource)
    directory = resource.resource_type
    filename = ActiveStorage::Filename.new(file_path)

    "qul-exports/#{directory}/#{Time.now.to_i}-#{SecureRandom.base36(5)}-#{filename.base}.#{filename.extension}"
  end
end