# frozen_string_literal: true

ActiveAdmin.register Word do
  menu parent: 'Quran', priority: 3
  searchable_select_options(
    scope: Word,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        verse_key_cont: term,
        location_cont: term,
        m: 'or'
      ).result
    end
  )

  actions :all, except: :destroy
  ActiveAdminViewHelpers.versionate(self)

  filter :id
  filter :verse_key
  filter :location
  filter :char_type
  filter :page_number
  filter :text_uthmani
  filter :text_uthmani_simple
  filter :text_imlaei_simple
  filter :text_qpc_nastaleeq_hafs
  filter :text_qpc_hafs
  filter :word_index

  filter :code_hex
  filter :verse,
         as: :searchable_select,
         ajax: { resource: Verse }

  permit_params do
    %i[
      verse_id
      word_index
      position
      location
      text_uthmani
      text_uthmani_simple
      text_uthmani_tajweed
      text_indopak
      code_v1
      code_v2
      verse_key
      line_number
      line_v2
      page_number
      v2_page
      char_type_id
      audio_url
      char_type_name
      en_transliteration
      text_qpc_hafs
      text_imlaei
      text_imlaei_simple
      text_indopak_nastaleeq
      text_qpc_nastaleeq
      text_qpc_nastaleeq_hafs
      text_digital_khatt
    ]
  end

  form do |f|
    f.inputs 'Word detail' do
      f.input :verse_id
      f.input :word_index
      f.input :position
      f.input :location

      f.input :text_uthmani, input_html: { class: 'quran-text me_quran' }
      f.input :text_uthmani_simple, input_html: { class: 'quran-text me_quran' }
      f.input :text_indopak, input_html: { class: 'quran-text indopak' }
      f.input :text_indopak_nastaleeq, input_html: { class: 'quran-text indopak-nastaleeq' }
      f.input :text_qpc_nastaleeq, input_html: { class: 'quran-text indopak-nastaleeq' }
      f.input :text_qpc_nastaleeq_hafs, input_html: { class: 'quran-text indopak-nastaleeq' }
      f.input :text_digital_khatt, input_html: { class: 'quran-text digitalkhatt' }
      f.input :text_imlaei, input_html: { class: 'quran-text me_quran' }
      f.input :text_imlaei_simple, input_html: { class: 'quran-text me_quran' }
      f.input :text_qpc_hafs, input_html: { class: 'quran-text qpc-hafs' }
      f.input :text_uthmani_tajweed, input_html: { class: 'quran-text me_quran' }

      f.input :code_v1, input_html: { class: 'quran-text' }
      f.input :code_v2, input_html: { class: 'quran-text' }

      f.input :en_transliteration

      f.input :verse_key
      f.input :class_name
      f.input :char_type
      f.input :audio_url

      f.input :page_number
      f.input :v2_page
      f.input :line_number
      f.input :line_v2
    end
    f.actions
  end

  show do
    render 'shared/page_font', verses: [resource.verse]

    attributes_table do
      row :id
      row :word_index
      row :verse
      row :verse_key
      row :position
      row :location
      row :line_number
      row :line_v2
      row :char_type

      row :page_number, 'V1 Page' do
        link_to resource.page_number, "/admin/page?page#{resource.page_number}"
      end

      row :v2_page, 'V2 Page' do
        link_to resource.v2_page, "/admin/page?page#{resource.v2_page}"
      end

      row :text_uthmani, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_uthmani.to_s.html_safe, class: 'me_quran')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_uthmani}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_uthmani_simple, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_uthmani_simple.to_s.html_safe, class: 'me_quran')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_uthmani_simple}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_imlaei, class: 'quran-text' do
        span resource.text_imlaei, class: 'me_quran'
      end

      row :text_imlaei_simple, class: 'quran-text' do
        span resource.text_imlaei_simple, class: 'me_quran'
      end

      row :text_qpc_hafs, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_hafs.to_s.html_safe, class: 'qpc-hafs')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_hafs}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_digital_khatt, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_digital_khatt, class: 'digitalkhatt')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_digital_khatt}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_uthmani_tajweed, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_uthmani_tajweed.to_s.html_safe, class: 'qpc-hafs')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_uthmani_tajweed}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_v4_tajweed, class: 'quran-text' do
        div class: "p#{resource.v2_page}-v4-tajweed", 'data-controller': 'tajweed-font' do
          resource.code_v2
        end
      end

      row :text_indopak, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_indopak.to_s.html_safe, class: 'indopak')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_indopak}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_indopak_nastaleeq, class: 'quran-text' do
        span resource.text_indopak_nastaleeq, class: 'indopak-nastaleeq'
      end

      row :text_qpc_nastaleeq, class: 'quran-text' do
        span resource.text_qpc_nastaleeq, class: 'indopak-nastaleeq'
      end

      row 'QPC Nastaleeq Hafs', class: 'quran-text' do
        span resource.text_qpc_nastaleeq_hafs, class: 'qpc-nastaleeq'
      end

      row :code_v1, class: 'quran-text' do
        span class: "p#{resource.page_number}-v1" do
          resource.code_v1
        end
      end

      row :code_v2, class: 'quran-text' do
        span class: "p#{resource.v2_page}-v2" do
          resource.code_v2
        end
      end

      row :transliteration do
        resource.en_transliteration
      end

      row :morphology_word
      row :word_lemma, class: 'quran-text' do
        span do
          if lemma = resource.word_lemma
            link_to(lemma.to_s, [:admin, lemma], class: 'me_quran')
          end
        end
      end

      row :word_stem, class: 'quran-text' do
        span do
          if stem = resource.word_stem
            link_to(stem.to_s, [:admin, stem], class: 'me_quran')
          end
        end
      end

      row :root, class: 'quran-text' do
        span do
          if root = resource.word_root
            link_to(root.root.value, [:admin, root], class: 'me_quran')
          end
        end
      end

      row :synonyms do
        resource.synonyms.each do |s|
          span do
            link_to s.text, [:admin, s], class: 'ml-2'
          end
        end
        nil
      end

      row :created_at
      row :updated_at
      row :mushaf_words do
        table do
          thead do
            th :id
            th :mushaf
            th :line_number
            th :page_number
            th :page_position
            th :line_position
            th :verse_position
            th :text
          end

          tbody do
            MushafWord.includes(:mushaf).where(word_id: resource.id).includes(:mushaf).each do |mushaf_word|
              mushaf = mushaf_word.mushaf

              tr do
                td link_to(mushaf_word.id, [:admin, mushaf_word])
                td link_to(mushaf.name, [:admin, mushaf])
                td mushaf_word.line_number
                td link_to(mushaf_word.page_number,
                           "/admin/mushaf_page_preview?mushaf=#{mushaf_word.mushaf_id}&page=#{mushaf_word.page_number}&word=#{mushaf_word.word_id}")
                td mushaf_word.position_in_page
                td mushaf_word.position_in_line
                td mushaf_word.position_in_verse

                td class: "p#{mushaf_word.page_number}-#{mushaf.default_font_name} #{mushaf.default_font_name}" do
                  if mushaf.use_images?
                    image_tag mushaf_word.image_url
                  else
                    mushaf_word.text.html_safe
                  end
                end
              end
            end
          end
        end
      end
    end

    active_admin_comments

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  index do
    column :id do |resource|
      link_to resource.id, admin_word_path(resource)
    end
    column :word_index
    column :verse do |resource|
      link_to resource.verse_id, admin_verse_path(resource.verse_id)
    end

    column :char_type, &:char_type_name
    column :position

    #     column :pause_name do |resource|
    #       if resource.char_type_id == 4
    #         if resource.pause_marks.present?
    #           resource.pause_marks.pluck(:mark).join ', '
    #         else
    #           div do
    #             (link_to("Jeem", admin_pause_marks_path(word_id: resource.id, mark: 'jeem'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'}) +
    #                 (link_to "Sad lam ya", admin_pause_marks_path(word_id: resource.id, mark: 'Sad lam ya'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})+
    #                 (link_to "Three dots", admin_pause_marks_path(word_id: resource.id, mark: 'Three dots'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})+
    #                 (link_to "Qaf lam ya", admin_pause_marks_path(word_id: resource.id, mark: 'qaf lam ya'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})+
    #                 (link_to "Lam Alif", admin_pause_marks_path(word_id: resource.id, mark: 'lam alif'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})+
    #                 (link_to "Meem", admin_pause_marks_path(word_id: resource.id, mark: 'Meem'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})+
    #                 (link_to "Seen", admin_pause_marks_path(word_id: resource.id, mark: 'Seen'), class: 'mark-btn', data: {method: :post, remote: true, disable_with: 'Wait'})
    #             ).html_safe
    #           end
    #         end
    #       end
    #     end

    column :text_uthmani
    column :text_uthmani_simple
    column :text_imlaei
    column :text_qpc_hafs, class: 'qpc-hafs'

    actions
  end

  def scoped_collection
    super.includes :verse, :char_type
  end

  sidebar 'Audio', only: :show do
    table do
      thead do
        td :id
        td :play
      end

      tbody do
        tr do
          td do
            if word.audio_url
              (link_to('play', '#_', class: 'play') +
                audio_tag('', data: { url: "//audio.qurancdn.com/#{word.audio_url}" }, controls: true,
                          class: 'audio'))
            end
          end
        end
      end
    end
  end

  sidebar 'Transliterations', only: :show do
    table do
      thead do
        td :id
        td :language
        td :text
      end

      tbody do
        word.transliterations.each do |trans|
          tr do
            td link_to(trans.id, [:admin, trans])
            td link_to(trans.language_name, admin_language_path(trans.language_id)) if trans.language_id
            td trans.text
          end
        end
      end
    end
  end

  sidebar 'Translations', only: :show do
    table do
      thead do
        td :id
        td :language
        td :text
      end

      tbody do
        word.word_translations.each do |trans|
          tr do
            td link_to(trans.id, [:admin, trans])
            td link_to(trans.language_name, admin_language_path(trans.language_id)) if trans.language_id
            td trans.text
          end
        end
      end
    end
  end

  collection_action :export_sqlite_db, method: 'put' do
    file_name = params[:file_name].to_s.strip || 'words'
    mushaf_id = params[:mushaf_id].to_s.strip
    language = params[:word_translation_language].to_s
    include_word_audio = params[:include_word_audio].to_s == 'on'

    if mushaf_id.blank? && language.blank?
      return redirect_back(fallback_location: '/admin',
                           error: 'Please select Mushaf or Translation language( or both ) to export to database.')
    end

    word_fields = []

    if include_word_audio
      word_fields << 'audio_url'
    end

    ExportWordsJob.perform_later(
      file_name: file_name,
      admin_id: current_user.id,
      mushaf_id: mushaf_id,
      language_id: language,
      word_fields: word_fields
    )

    redirect_back(fallback_location: '/admin', notice: 'Words dump will be prepared and sent to your email soon')
  end

  controller do
    def find_resource
      collection = scoped_collection
                     .includes(
                       :verse,
                       :char_type,
                       :word_translations,
                       :word_stem,
                       :word_root,
                       :word_lemma
                     )

      if params[:id].to_s.include?(':')
        collection.find_by(location: params[:id])
      else
        collection.find(params[:id])
      end
    end
  end
end
