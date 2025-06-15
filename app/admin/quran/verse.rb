# frozen_string_literal: true

ActiveAdmin.register Verse do
  searchable_select_options(
    scope: Verse,
    text_attribute: :verse_key,
    filter: lambda do |term, scope|
      if term.include?(':')
        scope.ransack(
          verse_key_cont: term,
          m: 'or'
        ).result.order('verse_index asc')
      else
        scope.ransack(
          verse_key_cont: term,
          id_eq: term,
          m: 'or'
        ).result.order('verse_index asc')
      end
    end
  )
  menu parent: 'Quran', priority: 2

  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)
  ActiveAdminViewHelpers.versionate(self)

  actions :all, except: %i[destroy new]

  filter :id
  filter :chapter, as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse_number
  filter :verse_index
  filter :verse_key
  filter :juz_number
  filter :hizb_number
  filter :rub_el_hizb
  filter :sajdah
  filter :text_uthmani
  filter :text_uthmani_simple
  filter :text_qpc_hafs
  filter :page_number
  filter :sajdah_number, as: :select, collection: proc { 1..14 }

  index do
    id_column
    column :chapter do |verse|
      link_to verse.chapter_id, cms_chapter_path(verse.chapter_id)
    end
    column :verse_number
    column :verse_key
    column :juz_number
    column :hizb_number
    column :sajdah_number
    column :page_number
    column :text_uthmani
  end

  show do
    render 'shared/page_font', verses: [resource]

    attributes_table do
      row :id
      row :chapter do
        link_to resource.chapter_id, cms_chapter_path(resource.chapter_id)
      end
      row :verse_number
      row :verse_index
      row :verse_key
      row :juz_number
      row :hizb_number
      row :rub_el_hizb
      row :sajdah_number
      row :sajdah_type
      row :page_number
      row :mushaf_pages_mapping
      row :mushaf_juzs_mapping

      row :verse_lemma do
        link_to_if resource.verse_lemma, resource.verse_lemma&.text_madani, [:cms, resource.verse_lemma]
      end

      row :verse_stem do
        link_to_if resource.verse_stem, resource.verse_stem&.text_madani, [:cms, resource.verse_stem]
      end

      row :verse_root do
        link_to_if resource.verse_root, resource.verse_root&.value, [:cms, resource.verse_root]
      end

      row 'Indopak' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_indopak.to_s.html_safe, class: 'quran-text indopak')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_indopak}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'Indopak Nastaleeq' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_indopak_nastaleeq.to_s.html_safe, class: 'quran-text indopak-nastaleeq')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_indopak_nastaleeq}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'QPC Indopak Nastaleeq' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_nastaleeq.to_s.html_safe, class: 'quran-text indopak-nastaleeq')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_nastaleeq}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'QPC Nastaleeq Hafs' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_nastaleeq_hafs.to_s.html_safe, class: 'quran-text qpc-nastaleeq')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_nastaleeq_hafs}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'QPC Nastaleeq' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_nastaleeq.to_s.html_safe, class: 'quran-text indopak-nastaleeq')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_nastaleeq}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'DigitalKhatt indopak' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_digital_khatt_indopak.to_s.html_safe, class: 'quran-text digitalkhatt-indopak')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_digital_khatt_indopak}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'Imlaei script' do
        div class: 'quran-text me_quran' do
          resource.text_imlaei
        end
      end

      row 'Imlaei Simple' do
        div class: 'quran-text me_quran' do
          resource.text_imlaei_simple
        end
      end

      row 'Text Uthmani' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_uthmani.to_s.html_safe, class: 'quran-text me_quran')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_uthmani}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'Uthmani Simple' do
        div class: 'quran-text me_quran' do
          resource.text_uthmani_simple
        end
      end

      row 'KFQC Hafs' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_hafs.to_s.html_safe, class: 'quran-text qpc-hafs')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_hafs}", target: '_blank', class: 'fs-sm')
        end
      end

      row :text_qpc_hafs_colored, class: 'quran-text' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_hafs.to_s.html_safe, class: 'qpc-hafs-color')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_hafs}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'Uthmani Tajweed(ReciteQuran)' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_uthmani_tajweed.to_s.html_safe, class: 'quran-text qpc-hafs', 'data-controller': 'tajweed-highlight')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_uthmani_tajweed}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'KFQC Hafs Tajweed(New)' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_qpc_hafs_tajweed.to_s.html_safe, class: 'quran-text qpc-hafs tajweed-new', 'data-controller': 'tajweed-highlight')

          div link_to('Chars', "/community/chars_info?text=#{resource.text_qpc_hafs_tajweed}", target: '_blank', class: 'fs-sm')
        end
      end

      row :v4_tajweed_code do
        div class: "quran-text p#{resource.v2_page}-v4-tajweed", 'data-controller': 'tajweed-font' do
          resource.code_v2
        end
      end

      row 'Digital Khatt' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_digital_khatt, class: 'quran-text digitalkhatt')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_digital_khatt}", target: '_blank', class: 'fs-sm')
        end
      end

      row 'Digital Khatt V1' do
        div class: 'd-flex flex-column align-item-end' do
          div(resource.text_digital_khatt_v1, class: 'quran-text digitalkhatt')
          div link_to('Chars', "/community/chars_info?text=#{resource.text_digital_khatt_v1}", target: '_blank', class: 'fs-sm')
        end
      end

      row :v1_code do
        div class: "quran-text p#{resource.page_number}-v1" do
          resource.code_v1
        end
      end

      row :v2_code do
        div class: "quran-text p#{resource.v2_page}-v2" do
          resource.code_v2
        end
      end

      row :image do
        div class: 'quran-text' do
          image_tag resource.image_url, class: 'w-100'
        end
      end

      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]

    panel "Words (#{verse.words.size})", id: 'verse-words' do
      table border: 1 do
        thead do
          td 'ID'
          td 'Index'
          td 'Position'
          td 'Code v1'
          td 'Code V2'
          td 'Code V4'
          td 'Uth tadjweed'
          td 'QPC Tajweed'
          td 'Uthmani'
          td 'Uth-Simple'
          td 'KFQC Hafs'
          td 'Imlaei'
          td 'Im-Simle'
          td 'Nastaleeq(Indopak)'
          td 'Nastaleeq(QPC)'
          td 'Nastaleeq Hafs(QPC)'
          td 'Indopak'
          td 'Char type'
        end

        tbody class: 'quran-text' do
          verse.words.order('position ASC').each do |w|
            tr do
              td link_to(w.id, cms_word_path(w))
              td w.word_index
              td w.position

              td class: "p#{w.page_number}-v1" do
                w.code_v1
              end

              td class: "p#{w.v2_page}-v2" do
                w.code_v2
              end

              td class: "p#{w.v2_page}-v4-tajweed" do
                w.code_v2
              end

              td do
                div(w.text_uthmani_tajweed.to_s.html_safe, class: 'quran-text qpc-hafs', 'data-controller': 'tajweed-highlight')
              end

              td do
                div(w.text_qpc_hafs_tajweed.to_s.html_safe, class: 'quran-text qpc-hafs tajweed-new', 'data-controller': 'tajweed-highlight')
              end

              td class: 'me_quran' do
                w.text_uthmani
              end

              td class: 'me_quran' do
                w.text_uthmani_simple
              end

              td class: 'qpc-hafs' do
                w.text_qpc_hafs
              end

              td class: 'me_quran' do
                w.text_imlaei
              end

              td class: 'me_quran' do
                w.text_imlaei_simple
              end

              td class: 'indopak-nastaleeq' do
                w.text_indopak_nastaleeq
              end

              td class: 'indopak-nastaleeq' do
                w.text_qpc_nastaleeq
              end

              td class: 'qpc-nastaleeq' do
                w.text_qpc_nastaleeq_hafs
              end

              td class: 'indopak' do
                w.text_indopak
              end

              td w.char_type_name
            end
          end
        end
      end
    end

    panel "<div data-bs-toggle='collapse' data-bs-target='#recitations' class='d-flex collapable'>Available Recitations(#{verse.audio_files.size}) <span class='ms-auto'></span></div>".html_safe do
      div id: 'recitations', class: 'collapse', 'aria-labelledby': 'recitations' do
        table do
          thead do
            td 'ID'
            td 'Reciter'
            td 'Recitation style'
            td 'Duration'
            td 'Audio'
          end

          tbody do
            verse.audio_files.each do |file|
              tr do
                td link_to(file.id, cms_audio_file_path(file))
                td file.recitation&.reciter_name
                td file.recitation&.style
                td file.duration
                td do
                  if file.url
                    (link_to('play', '#_', class: 'play') +
                      audio_tag('', data: { url: file.audio_url }, controls: true,
                                class: 'audio'))
                  end
                end
              end
            end
          end
        end
      end
    end

    panel "<div data-bs-toggle='collapse' data-bs-target='#translations' class='d-flex collapable scrollable'>Translations(#{verse.translations.size}) <span class='ms-auto'></span></div>".html_safe do
      div id: 'translations', class: 'collapse', 'aria-labelledby': 'translations' do
        table do
          thead do
            td 'ID'
            td 'Language'
            td 'Text'
          end

          tbody do
            verse.translations.order('language_id DESC').each do |trans|
              tr do
                td link_to(trans.id, cms_translation_path(trans))
                td "#{trans.language_name}-#{trans.get_resource_content.name}"
                td do
                  div class: "#{trans.language_name} translation" do
                    safe_html trans.text
                  end
                end
              end
            end
          end
        end
      end
    end

    other_matching_verses = resource.get_matching_verses
    panel "Ayahs similar to #{resource.verse_key} (#{other_matching_verses.size})", id: 'verse-words' do
      table do
        thead do
          th '#'
          th 'Key'
          th 'Score'
          th 'Text', colspan: 5
        end

        tbody do
          other_matching_verses.each_with_index do |matching, i|
            matching_verse = matching.is_source_verse?(resource) ? matching.matched_verse : matching.verse
            positions = matching.matched_word_positions.map(&:to_i)

            tr do
              td "#{i + 1} - #{link_to matching_verse.id, [:cms, matching]}".html_safe
              td link_to(matching_verse.verse_key, [:cms, matching_verse])
              td matching.score

              td class: 'quran-text qpc-hafs' do
                matching_verse.words.map do |w|
                  span w.text_qpc_hafs, class: "#{'text-success' if positions.include?(w.position)}"
                end
              end
            end
          end
        end
      end
    end

    panel "Shared phrases" do
      table do
        thead do
          th '#'
          th 'Id'
          th 'Src'
          th 'Word from'
          th 'Word to'
          th 'Occurrence'
          th 'Text', colspan: 5
        end

        tbody do
          Morphology::PhraseVerse.includes(:phrase).where(verse_id: resource.id).where(phrase: { words_count: 4 }).each_with_index do |pv, i|
            phrase = pv.phrase

            tr do
              td i + 1
              td link_to(phrase.id, [:cms, phrase])
              td phrase.source_verse.verse_key
              td pv.word_position_from
              td pv.word_position_to
              td phrase.occurrence

              td class: 'quran-text qpc-hafs' do
                phrase.text_qpc_hafs_simple
              end
            end
          end
        end
      end
    end
  end

  sidebar 'Search ayah', only: :index do
    render 'admin/ayah_search'
  end

  sidebar 'Media content', only: :show do
    table do
      thead do
        td :id
        td :language
        td :author
      end

      tbody do
        resource.media_contents.each do |c|
          tr do
            td link_to(c.id, [:cms, c])
            td c.language_name
            td c.get_resource_content.author_name
          end
        end
      end
    end
  end

  sidebar 'Tafsirs', only: :show do
    table do
      thead do
        td :id
        td :name
        td :language
        td :author
      end

      tbody do
        resource.tafsirs.each do |c|
          resource_content = c.get_resource_content
          tr do
            td link_to(c.id, [:cms, c])
            td "#{resource_content.id} - #{resource_content.name}"
            td c.language_name
            td c.get_resource_content.author_name
          end
        end
      end
    end
  end

  permit_params do
    %i[
      text_uthmani
      text_indopak
      text_indopak_nastaleeq
      text_qpc_nastaleeq
      text_qpc_nastaleeq_hafs
      text_uthmani_tajweed
      text_uthmani_simple
      text_qpc_hafs
      text_digital_khatt
      text_digital_khatt_v1
      text_digital_khatt_indopak
      text_imlaei
      text_imlaei_simple
      code_v1
      code_v2
      verse_key
      line_v2
      page_number
      v2_page
    ]
  end

  form do |f|
    f.inputs 'Verse detail' do
      f.input :text_uthmani, input_html: { class: 'quran-text me_quran' }
      f.input :text_uthmani_simple, input_html: { class: 'quran-text me_quran' }
      f.input :text_uthmani_tajweed, input_html: { class: 'quran-text me_quran' }
      f.input :text_imlaei, input_html: { class: 'quran-text me_quran' }
      f.input :text_imlaei_simple, input_html: { class: 'quran-text me_quran' }
      f.input :text_qpc_hafs, input_html: { class: 'quran-text me_quran' }
      f.input :text_digital_khatt, input_html: { class: 'quran-text digitalkhatt' }
      f.input :text_digital_khatt_v1, input_html: { class: 'quran-text digitalkhatt' }

      f.input :text_indopak, input_html: { class: 'quran-text pdms' }
      f.input :text_indopak_nastaleeq, input_html: { class: 'quran-text indopak-nastaleeq' }
      f.input :text_qpc_nastaleeq, input_html: { class: 'quran-text indopak-nastaleeq' }
      f.input :text_qpc_nastaleeq_hafs, input_html: { class: 'quran-text qpc-nastaleeq' }
      f.input :text_digital_khatt_indopak, input_html: { class: 'quran-text digitalkhatt-indopak' }

      f.input :code_v1, input_html: { class: 'quran-text' }
      f.input :code_v2, input_html: { class: 'quran-text' }
    end
    f.actions
  end

  controller do
    def find_resource
      collection = scoped_collection
                     .includes(
                       :chapter,
                       :media_contents,
                       :tafsirs,
                       :translations,
                       audio_files: :recitation
                     )

      if params[:id].to_s.include?(':')
        collection.find_by(verse_key: params[:id]) || raise(ActiveRecord::RecordNotFound.new("Couldn't find Verse with 'verse_key'=#{params[:id]}"))
      else
        collection.find(params[:id])
      end
    end
  end
end
