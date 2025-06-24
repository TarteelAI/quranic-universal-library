# frozen_string_literal: true

ActiveAdmin.register Root do
  menu parent: 'Grammar'
  actions :index, :show
  permit_params :arabic_trilateral, :english_trilateral, :text_clean, :text_uthmani, :uniq_words_count, :value, :words_count

  searchable_select_options(
    scope: Root,
    text_attribute: :value,
    filter: lambda do |term, scope|
      scope.ransack(value_cont: term).result
    end
  )

  filter :value
  filter :english_trilateral
  filter :arabic_trilateral
  filter :words_count
  filter :uniq_words_count

  index do
    column :id do |r|
      link_to r.id, "/cms/roots/#{r.id}"
    end
    column :value
    column :arabic_trilateral
    column :english_trilateral
    column :words_count
    column :uniq_words_count
  end

  show do
    attributes_table do
      row :id
      row :value
      row :text_uthmani
      row :english_trilateral
      row :arabic_trilateral
      row :dictionary_image_path
      row :en_translations
      row :ur_translations
      row :words_count
      row :uniq_words_count

      row :created_at
      row :updated_at
    end

    panel 'Words for this root' do
      words_ids = resource.words.pluck(:id)

      # TODO: move this to helper
      per_page = params[:per_page].to_i.zero? ? 10 : params[:per_page].to_i
      per_page = [per_page, 50].min
      params[:per_page] = per_page
      direction = params[:direction] == 'asc' ? 'desc' : 'asc'
      verses = resource.verses.unscope(:order).order("verses.id #{direction}").includes(:words).page(params[:page] || 0).per(per_page)

      table do
        thead do
          td do
            link_to 'Ayah', url_for(sort: 'verse_id', direction: params[:direction] == 'asc' ? 'desc' : 'asc')
          end

          td 'Text'
        end

        tbody do
          verses.each do |verse|
            tr do
              td link_to(verse.verse_key, cms_verse_path(verse))
              td class: 'quran-text qpc-hafs' do
                verse.words.map do |word|
                  if words_ids.include?(word.id)
                    "<a class=text-success href='/cms/words/#{word.id}' target=_blank>#{word.text_qpc_hafs}</a>"
                  else
                    "<a href='/cms/words/#{word.id}' target=_blank>#{word.text_qpc_hafs}</a>"
                  end
                end.join(' ').html_safe
              end
            end
          end

          tr do
            td paginated_collection(verses)
          end

          nil
        end
      end
    end
  end

  controller do
    def find_resource
      collection = scoped_collection

      if params[:id].to_s.match?(/\A\d+\z/)
        collection.find(params[:id])
      else
        collection.find_by(value: params[:id].to_s.chars.join(' '))
      end
    end
  end
end
