# frozen_string_literal: true

# == Schema Information
#
# Table name: reciters
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
ActiveAdmin.register Reciter do
  ActiveAdminViewHelpers.render_translated_name_sidebar(self)

  menu parent: 'Audio'
  filter :name
  actions :all, except: :destroy
  searchable_select_options(
    scope: Reciter,
    text_attribute: :name,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        id_eq: term,
        m: 'or'
      ).result
    end
  )

  permit_params do
    %i[name bio cover_image profile_picture]
  end

  index do
    id_column
    column :name
    column :recitations_count
    column :cover_image
    column :profile_picture
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :recitations_count

      row :bio do |resource|
        div do
          safe_html resource.bio
        end
      end

      row :profile_picture do |resource|
        url = resource.profile_picture_url
        if url
          image_tag url
        end
      end

      row :cover_image do |resource|
        url = resource.cover_url
        if url
          image_tag url
        end
      end
      row :created_at
      row :updated_at
    end

    active_admin_comments

    panel 'Ayah recitations' do
      table do
        thead do
          td 'ID'
          td 'Name'
          td 'Style'
          td 'Qirat'
        end

        tbody do
          resource.verse_recitations.includes(:recitation_style, :qirat_type).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.recitation_style&.name
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
          td 'Style'
          td 'Qirat'
        end

        tbody do
          resource.audio_recitations.includes(:recitation_style, :qirat_type).each do |r|
            tr do
              td link_to(r.id, [:cms, r])
              td r.name
              td r.recitation_style&.name
              td r.qirat_type&.name
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs 'Reciter Detail' do
      f.input :name
      f.input :cover_image
      f.input :profile_picture

      f.input :bio, input_html: {
        data: {
          controller: 'tinymce'
        }
      }
    end

    f.actions
  end
end
