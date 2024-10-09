module Export
  class TafsirJson < ApplicationJob
    sidekiq_options retry: 2, backtrace: true

    attr_reader :file_name,
                :resource_content

    STORAGE_PATH = "#{Rails.root}/tmp/exported_databases"

    def perform(resource_id, original_file_name, user_id)
      user = User.find(user_id)
      @resource_content = ResourceContent.find(resource_id)

      setup(original_file_name)
      export_data
      compress
      send_email("#{file_name}.bz2", user) if user.present?

      # return the db file path
      "#{file_name}.bz2"
    end

    protected

    def setup(original_file_name)
      require 'fileutils'

      name = get_file_name(original_file_name)
      timestamp = Time.now
      file_path = "#{STORAGE_PATH}/#{timestamp.to_i}"
      file_path = STORAGE_PATH if Rails.env.development?
      FileUtils::mkdir_p file_path

      @file_name = "#{file_path}/#{name}-#{resource_content.updated_at.to_i}.json"
    end

    def get_file_name(original_file_name)
      skip = [91, 908, 816] #saadi old, sirraj, id jalalin empty

      mapping = {
        '14': 'ar-tafsir-ibn-kathir',
        '15': 'ar-tafsir-tabari',
        '16': 'ar-tafsir-muyassar',
        '90': 'ar-tafsir-qurtubi',
        '92': 'ar-tafsir-tanweer',
        '93': 'ar-tafsir-waseet',
        '94': 'ar-tafsir-baghawy',
        '912': 'ar-tafsir-saddi',
        '905': 'ar-tafsir-mukhtasar',

        '171': 'en-tafsir-mokhtasar',
        '169': 'en-tafsir-ibn-kathir',
        '817': 'en-tafsir-tazkirul-quran',
        '168': 'en-tafsir-maarif-quran',

        '164': 'bn-tafsir-ibn-kathir',
        '165': 'bn-tafsir-ahsanul-bayaan',
        '166': 'bn-tafsir-zakaria',
        '180': 'bn-tafsir-mukhtasar',
        '381': 'bn-tafsir-fathul-majid', #need review

        '160': 'ur-tafsir-ibn-kathir',
        '906': 'ur-tafsir-saadi',
        '157': 'ur-tafsir-fi-zilal-al-quran',
        '159': 'ur-tafsir-bayan-ul-quran',
        '818': 'ur-tafsir-tazkirul-quran',

        '172': 'tr-tafsir-mukhtasar',
        '907': 'tr-tafsir-saadi',
        '914': 'tr-tafsir-ibn-kathir',

        '909': 'fa-tafsir-saadi',
        '181': 'fa-tafsir-mokhtasar',

        '910': 'id-tafsir-saadi',
        '174': 'id-tafsir-mokhtasar',

        '911': 'ru-tafsir-saadi',
        '178': 'ru-tafsir-mokhtasar',
        '913': 'ru-tafsir-ibn-kathir',

        '173': 'fr-tafsir-mokhtasar',
        '177': 'vi-tafsir-mokhtasar',
        '183': 'ja-tafsir-mokhtasar',
        '776': 'es-tafsir-mokhtasar',
        '790': 'as-tafsir-mokhtasar',
        '179': 'tl-tafsir-mokhtasar',
        '175': 'bs-tafsir-mokhtasar',
        '791': 'ml-tafsir-mokhtasar',
        '792': 'km-tafsir-mokhtasar',
        '182': 'zh-tafsir-mokhtasar',
        '176': 'it-tafsir-mokhtasar',
        '804': 'ku-tafsir-rebar',
        '915': 'sq-tafsir-saadi'
      }

      name = mapping[resource_content.id.to_s.to_sym].presence
      name ||= (original_file_name.presence || resource_content.sqlite_file_name)

      name.gsub(/\s+/, '-').chomp('.json').strip
    end

    def format_text(text)
      doc = Nokogiri::HTML::DocumentFragment.parse(text)
      doc.css('h3').each do |h3|
        h3.name = 'div'
      end

      doc.to_html
    end

    def export_data
      json = {}

      Verse.find_each do |verse|
        if json[verse.verse_key]
          next
        end

        json[verse.verse_key] = {}

        tafsir = Tafsir.for_verse(verse, resource_content)

        if (tafsir)
          group = tafsir.ayah_group_list

          json[tafsir.verse_key] = {
            text: format_text(tafsir.text)
          }

          if group.length > 1
            json[verse.verse_key][:ayah_keys] = group

            group.each do |key|
              json[key] = tafsir.verse_key if json[key].blank?
            end
          end
        end
      end

      File.open(file_name, 'wb') do |file|
        file << JSON.generate(json, { state: JsonNoEscapeHtmlState.new })
      end
    end

    def compress
      `bzip2 #{file_name}`
    end

    def send_email(zip_path, admin_user)
      DeveloperMailer.notify(
        to: admin_user.email,
        subject: "#{@resource_content.name} files export",
        message: "Please see the attached zip",
        file_path: zip_path
      ).deliver_now
    end
  end
end