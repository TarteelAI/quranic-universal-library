# frozen_string_literal: true

ActiveAdmin.register RecitationStyle do
  menu parent: 'Audio', priority: 4
  actions :all, except: :destroy
  permit_params :name, :description, :arabic

  filter :name

  searchable_select_options(
    scope: RecitationStyle,
    text_attribute: :name,
    filter: lambda do |term, scope|
      scope.ransack(name_cont: term).result
    end
  )

  show do
    attributes_table do
      row :id
      row :name
      row :description
      row :audio_recitations_count
      row :created_at
      row :updated_at
    end

    panel 'Ayah recitations' do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Qirat'
        end

        tbody do
          resource.verse_recitations.includes(:qirat_type).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.qirat_type&.name
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
          td 'Qirat'
        end

        tbody do
          resource.audio_recitations.includes(:qirat_type).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.qirat_type&.name
            end
          end
        end
      end
    end
  end
end
