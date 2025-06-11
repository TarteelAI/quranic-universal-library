# frozen_string_literal: true

ActiveAdmin.register_page 'Mushaf Page Preview' do
  action_item :previous_page, group: :page do
    page = params[:page].to_i
    mushaf_id = params[:mushaf] || 2
    page = page > 1 ? page - 1 : 1

    link_to 'Previous page', "/cms/mushaf_page_preview?page=#{page}&mushaf=#{mushaf_id}&compare=#{params['compare']}&mushtabiat=#{params[:mushtabiat]}",
            class: 'btn'
  end

  action_item :next_page, group: :page do
    page = params[:page].to_i
    mushaf_id = params[:mushaf] || 2
    mushaf = Mushaf.find(mushaf_id)

    page = page < mushaf.pages_count ? page + 1 : mushaf.pages_count

    link_to 'Next page', "/cms/mushaf_page_preview?page=#{page}&mushaf=#{mushaf_id}&compare=#{params['compare']}&mushtabiat=#{params[:mushtabiat]}",
            class: 'btn'
  end

  action_item :fix_page do
    page = params[:page].to_i
    mushaf_id = params[:mushaf] || 2


    link_to 'Fix page', "/mushaf_layouts/#{mushaf_id}?page_number=#{page}",
            class: 'btn'
  end



  sidebar 'Mushaf Layouts' do
    page = params[:page].to_i

    table do
      thead do
        th 'Select Mushaf'
        th 'Pages'
        th 'Lines Per page'
      end

      tbody do
        Mushaf.find_each do |mushaf|
          tr do
            td do
              link_to mushaf.name, "/cms/mushaf_page_preview?mushaf=#{mushaf.id}&page=#{page}",
                      class: "#{'text-success' if mushaf.id == params['mushaf'].to_i}"
            end

            td mushaf.pages_count
            td mushaf.lines_per_page
          end
        end
      end
    end
  end

  sidebar 'Compare with' do
    page = params[:page].to_i
    current_mushaf = params['mushaf'].to_i
    compare_with = params['compare'].to_i

    table do
      thead do
        th 'Mushaf'
        th 'Actions'
      end

      tbody do
        Mushaf.find_each do |mushaf|
          tr do
            td do
              link_to mushaf.name
            end

            td do
              if compare_with == mushaf.id
                link_to 'Stop comparison', "/cms/mushaf_page_preview?mushaf=#{current_mushaf}&page=#{page}"
              else
                link_to 'Compare',
                        "/cms/mushaf_page_preview?mushaf=#{current_mushaf}&compare=#{mushaf.id}&page=#{page}&word=#{params[:word]}"
              end
            end
          end
        end
      end
    end
  end

  content do
    if params[:mushaf].blank?
      div "Please select a Mushaf to from the sidebar to see the page preview"
    else
      page = params[:page].to_i
      mushaf_id = (params[:mushaf].presence || Mushaf.find_by(name: 'QCF V1').id).to_i
      mushaf = Mushaf.find(mushaf_id)
      compare_with = params['compare'].to_i

      words = MushafWord
                .where(
                  mushaf_id: mushaf_id,
                  page_number: page
                )
                .order('position_in_page ASC, position_in_line ASC')

      columns do
        column do
          title = if page.zero?
                    "Select page for #{mushaf.name}"
                  else
                    "#{mushaf.name} - Page #{page}. Total words: #{words.size}"
                  end
          panel title do
            div do
              if page.zero?
                div class: 'placeholder' do
                  h4 'Select page'

                  ul do
                    1.upto mushaf.pages_count do |p|
                      li link_to("Page #{p}", "/cms/mushaf_page_preview?page=#{p}&mushaf=#{mushaf_id}")
                    end
                  end
                end
              else
                div class: 'mushaf-layout' do
                  render 'shared/mushaf_page',
                         words: words,
                         page: page,
                         mushaf: mushaf,
                         name: mushaf.name
                end
              end
            end
          end
        end

        if compare_with.positive?
          compare_mushaf = Mushaf.find(compare_with)
          compare_with_words = MushafWord
                                 .where(
                                   mushaf_id: compare_with,
                                   page_number: page)
                                 .order('position_in_page ASC, position_in_line ASC')
          column do
            panel "#{compare_mushaf.name} - Page #{page}. Total words: #{compare_with_words.size}" do
              div class: 'mushaf-layout' do
                render 'shared/mushaf_page',
                       words: compare_with_words,
                       page: page,
                       mushaf: compare_mushaf,
                       name: compare_mushaf.name
              end
            end
          end
        end
      end
    end
  end
end
