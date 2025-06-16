# frozen_string_literal: true

# == Schema Information
#
# Table name: qirat_types
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
ActiveAdmin.register QiratType do
  menu parent: 'Audio'
  actions :all, except: :destroy
  filter :name

  permit_params do
    %i[name description]
  end

  searchable_select_options(
    scope: QiratType,
    text_attribute: :name
  )

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :recitations_count
      row :created_at
      row :updated_at
    end

    panel 'Mushafs for this Qirat' do
      table do
        thead do
          td 'ID'
          td 'Name'
        end

        tbody do
          resource.mushafs.each do |r|
            tr do
              td link_to(r.id, [:cms, r])

              td r.name
            end
          end
        end
      end
    end

    panel 'Ayah recitations' do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Style'
        end

        tbody do
          resource.verse_recitations.includes(:recitation_style).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.recitation_style&.name
            end
          end
        end
      end
    end

    panel 'Surah recitations' do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Style'
        end

        tbody do
          resource.audio_recitations.includes(:recitation_style).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.recitation_style&.name
            end
          end
        end
      end
    end
  end
end
