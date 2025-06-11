# frozen_string_literal: true

# == Schema Information
#
# Table name: authors
#
#  id         :integer          not null, primary key
#  name       :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register_page 'Ayah data preview' do
  menu parent: 'Raw data'

  action_item :previous_page do
    params[:id] ||= 1
    verse = if params[:id].to_s.include?(':')
              Verse.find_by(verse_key: params[:id])
            else
              Verse.find(params[:id])
            end

    if verse&.previous_ayah
      link_to("Previous(#{verse.previous_ayah.verse_key})", "/cms/ayah_data_preview?id=#{verse&.previous_ayah.id}", class: 'btn')
    end
  end

  action_item :next_page do
    params[:id] ||= 1

    verse = if params[:id].to_s.include?(':')
              Verse.find_by(verse_key: params[:id])
            else
              Verse.find(params[:id])
            end

    if verse&.next_ayah
      link_to("Next(#{verse.next_ayah.verse_key})", "/cms/ayah_data_preview?id=#{verse.next_ayah.id}", class: 'btn')
    end
  end

  content do
    params[:id] ||= 1
    verse = if params[:id].to_s.include?(':')
      Verse.find_by(verse_key: params[:id])
    else
      Verse.find(params[:id])
    end

    if verse
      catalog = RawData::AyahRecord.includes(:resource).where(verse_id: verse.id)

      form do
        input :search, type: 'search', placeholder: 'search'
      end

      catalog.each do |content|
        panel "<div data-bs-toggle='collapse' data-bs-target='#content-#{content.id}' class='d-flex collapable scrollable'>#{content.resource&.name} <span class='ms-auto'></span></div>".html_safe do
          div do
            link_to "View record", [:cms, content]
          end

          div id: "content-#{content.id}", class: "collapse show #{content.content_css_class.to_s}", 'aria-labelledby': "content-#{content.id}" do
            content.text.to_s.html_safe
          end
        end
      end
    else
      "Please select an ayah, add ayah id is params like ?id=1"
    end
  end
end
