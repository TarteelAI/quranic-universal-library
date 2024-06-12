class UploadTranslationDbJob < ApplicationJob
  queue_as :default

  def perform(resource, file_path)
    resource.sqlite_db = File.open(file_path)
    resource.sqlite_db_generated_at = DateTime.now
    resource.save(validate: false, touch: false)
  end
end