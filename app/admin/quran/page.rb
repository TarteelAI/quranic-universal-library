# frozen_string_literal: true

ActiveAdmin.register_page 'Page' do
  menu parent: 'Quran'

  action_item :previous_page do
    page = params[:page].to_i
    page = page > 1 ? page - 1 : 1
    link_to 'Previous page', "/admin/page?page=#{page}", class: 'btn'
  end

  action_item :next_page do
    page = params[:page].to_i
    page = page < 604 ? page + 1 : 604

    link_to 'Next page', "/admin/page?page=#{page}", class: 'btn'
  end

  content do
    page = params[:page].to_i

    verses = Verse.unscoped.includes(:words).where(page_number: page).order('verse_index ASC')
    panel 'Page verses' do
      render 'shared/page_font', verses: verses

      table do
        thead do
          td 'Ayah'
          td 'Uthmani'
          td 'V1 font'
          td 'V2 font'
        end

        tbody do
          verses.each do |verse|
            tr do
              td do
                link_to verse.verse_key, admin_verse_path(verse)
              end

              td class: 'quran-text me_quran' do
                verse.text_uthmani
              end

              td class: 'quran-text' do
                div do
                  verse.words.order('position ASC').each do |w|
                    span class: "p#{w.page_number}-v1 quran-text", id: w.id do
                      w.code_v1
                    end
                  end
                end
              end

              td class: 'quran-text' do
                div do
                  verse.words.order('position ASC').each do |w|
                    span class: "p#{w.v2_page}-v2", id: w.id do
                      w.code_v2
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    panel 'Debug font' do
      form do
        div style: 'margin-top: 10px; line-height: 2' do
          label 'Code font - v1'
          textarea class: "p#{page}-v1 quran-text"
        end

        div style: 'margin-top: 10px; line-height: 2' do
          label 'Code font - v2'
          textarea class: "p#{page}-v2 quran-text"
        end

        div style: 'margin-top: 10px; line-height: 2' do
          label 'Uthmani text'
          textarea class: 'me_quran quran-text'
        end
      end
    end
  end
end
