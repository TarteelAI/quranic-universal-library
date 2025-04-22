module DraftContent
  class ImportDraftContentJob < ApplicationJob
    sidekiq_options retry: 1, backtrace: true

    def perform(id)
      resource = ResourceContent.find(id)

      if resource.sourced_from_quranenc?
        import_from_quranenc(resource)
      elsif resource.sourced_from_tafsir_app?
        import_from_tafsir_app(resource)
      else
        raise "Unsupported source for resource content with ID: #{id}"
      end
    end

    protected

    def import_from_quranenc(resource)
      if resource.tafsir?
        importer = Importer::QuranEncTafsir.new
        importer.import resource.quran_enc_key
      else
        importer = Importer::QuranEnc.new
        importer.import resource.quran_enc_key
      end
    end

    def import_from_tafsir_app(resource)
      importer = Importer::TafsirApp.new
      importer.import resource.tafsir_app_key
    end
  end
end