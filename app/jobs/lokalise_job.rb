class LokaliseJob < ApplicationJob
  def perform(action:)
    send(action) if action
  end

  protected
  def import
    client.import_new_keys
  end

  def export
    client.export_new_keys
  end

  def update_system_languages
    client.upload_system_languages
  end

  def client
    Utils::LokaliseSync.new
  end
end