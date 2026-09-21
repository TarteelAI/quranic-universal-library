# frozen_string_literal: true

module DraftContent
  class ImportDraftTafsirDbJob < ApplicationJob
    queue_as :default

    def perform(resource_content_id, db_path, user_id: nil, remove_existing: false)
      @resource_content = ResourceContent.find(resource_content_id)
      @user = User.find_by(id: user_id) if user_id.present?

      importer = Draft::TafsirSqliteImporter.new(
        @resource_content,
        db_path,
        remove_existing: remove_existing
      )
      stats = importer.import

      @resource_content.run_draft_import_hooks
      notify(stats)

      stats
    rescue StandardError => e
      notify_failure(e)
      raise
    ensure
      # clean up the staged upload, but never a db file from somewhere else
      FileUtils.rm_f(db_path) if db_path.to_s.start_with?(Draft::TafsirSqliteImporter::UPLOAD_PATH)
    end

    protected

    def notify(stats)
      message = [
        "Draft tafsir import finished for #{resource_name}.",
        "Imported: #{stats[:imported]}, skipped: #{stats[:skipped]}."
      ]
      message << "Issues:\n#{stats[:issues].join("\n")}" if stats[:issues].present?

      send_email("#{resource_name} draft tafsir import", message.join("\n"))
    end

    def notify_failure(error)
      send_email(
        "#{resource_name} draft tafsir import failed",
        "Draft tafsir import failed for #{resource_name}.\n\n#{error.class}: #{error.message}"
      )
    end

    def send_email(subject, message)
      return if @user.blank?

      DeveloperMailer.notify(
        to: @user.email,
        subject: subject,
        message: message
      ).deliver_now
    end

    def resource_name
      return 'draft tafsir' if @resource_content.blank?

      "#{@resource_content.name}(#{@resource_content.id})"
    end
  end
end
