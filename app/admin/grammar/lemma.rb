# frozen_string_literal: true

ActiveAdmin.register Lemma do
  menu parent: 'Grammar'
  actions :all, except: :destroy

  permit_params :text_madani, :text_clean, :words_count, :uniq_words_count, :en_translations

  filter :text_clean
  filter :text_madani
  filter :words_count
  filter :uniq_words_count
  filter :en_translations

  searchable_select_options(
    scope: Lemma,
    text_attribute: :text_clean,
    filter: lambda do |term, scope|
      scope.ransack(text_clean_cont: term).result
    end
  )

  index do
    id_column
    column :text_madani do |resource|
      span class: 'qpc-hafs' do
        resource.text_madani
      end
    end
    column :text_clean do |resource|
      span class: 'qpc-hafs' do
        resource.text_clean
      end
    end
    column :words_count
    column :uniq_words_count
    column :en_translations do |resource|
      resource.en_translations.present? ? resource.en_translations.join(', ') : status_tag('None')
    end
    actions
  end

  show do
    attributes_table do
      row :id
      row :text_madani do |resource|
        span class: 'qpc-hafs' do
          resource.text_madani
        end
      end
      row :text_clean do |resource|
        span class: 'qpc-hafs' do
          resource.text_clean
        end
      end
      row :words_count
      row :uniq_words_count
      row :en_translations do |resource|
        if resource.en_translations.present?
          ul do
            resource.en_translations.each do |t|
              li t
            end
          end
        else
          status_tag 'None'
        end
      end
      row :created_at
      row :updated_at
    end

    panel 'Words for this lemma' do
      words_ids = resource.words.pluck(:id)

      per_page = params[:per_page].to_i.zero? ? 10 : params[:per_page].to_i
      per_page = [per_page, 50].min
      params[:per_page] = per_page

      verses = resource.verses.includes(:words).order('verses.verse_index ASC').page(params[:page] || 0).per(per_page)

      table do
        thead do
          td 'Ayah'
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
end
