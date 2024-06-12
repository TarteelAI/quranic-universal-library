class QuranEnc::ImportDraftTranslationJob < ApplicationJob
  sidekiq_options retry: 1, backtrace: true

  def perform(id)
    resource = ResourceContent.find(id)

    if resource.tafsir?
      importer = Importer::QuranEncTafsir.new
      importer.import_abridge_tafsir resource.quran_enc_key
    else
      importer = Importer::QuranEnc.new
      importer.import resource.quran_enc_key
    end
  end
end
