module Api
  class ResourcesController < ApplicationController
    respond_to :json
    
    def index
      @resources = {
        recitations: format_recitations(get_recitations),
        translations: format_translations(get_translations),
        tafsirs: format_tafsirs(get_tafsirs),
        scripts: get_scripts,
        mushafs: format_mushafs(get_mushafs)
      }
      
      render json: @resources
    end
    
    def recitations
      @recitations = format_recitations(get_recitations)
      render json: @recitations
    end
    
    def translations
      @translations = format_translations(get_translations)
      render json: @translations
    end
    
    def tafsirs
      @tafsirs = format_tafsirs(get_tafsirs)
      render json: @tafsirs
    end
    
    def scripts
      @scripts = get_scripts
      render json: @scripts
    end
    
    def mushafs
      @mushafs = format_mushafs(get_mushafs)
      render json: @mushafs
    end
    
    private
    
    def format_recitations(recitations)
      recitations.map do |recitation|
        {
          id: recitation.id,
          name: recitation.reciter_name,
          description: recitation.style,
          resource_type: 'recitation',
          created_at: recitation.created_at,
          updated_at: recitation.updated_at
        }
      end
    end
    
    def format_translations(translations)
      translations.map do |translation|
        {
          id: translation.id,
          name: translation.resource_name,
          language: translation.language_name,
          resource_type: 'translation',
          created_at: translation.created_at,
          updated_at: translation.updated_at
        }
      end
    end
    
    def format_tafsirs(tafsirs)
      tafsirs.map do |tafsir|
        {
          id: tafsir.id,
          name: tafsir.resource_name,
          language: tafsir.language_name,
          resource_type: 'tafsir',
          created_at: tafsir.created_at,
          updated_at: tafsir.updated_at
        }
      end
    end
    
    def format_mushafs(mushafs)
      mushafs.map do |mushaf|
        {
          id: mushaf.id,
          name: mushaf.name,
          description: mushaf.description,
          pages_count: mushaf.pages_count,
          lines_per_page: mushaf.lines_per_page,
          enabled: mushaf.enabled,
          is_default: mushaf.is_default,
          default_font_name: mushaf.default_font_name,
          qirat_type_id: mushaf.qirat_type_id
        }
      end
    end
    
    def get_recitations
      Recitation.approved
    end
    
    def get_translations
      resource_content_ids = Translation.distinct.pluck(:resource_content_id)
      result = []
      
      resource_content_ids.each do |rc_id|
        sampleTranslation = Translation.where(resource_content_id: rc_id).first
        result << sampleTranslation if sampleTranslation
      end
      
      result
    end
    
    def get_tafsirs
      resource_content_ids = Tafsir.distinct.pluck(:resource_content_id)
      result = []
      
      resource_content_ids.each do |rc_id|
        sampleTafsir = Tafsir.where(resource_content_id: rc_id).first
        result << sampleTafsir if sampleTafsir
      end
      
      result
    end
    
    def get_scripts
      []
    end
    
    def get_mushafs
      Mushaf.approved
    end
  end
end
