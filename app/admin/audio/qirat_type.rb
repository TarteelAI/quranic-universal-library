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
ActiveAdmin.register Riwayah, as: 'QiratType' do
  menu parent: 'Audio'
  actions :all, except: :destroy
  filter :name
  filter :slug
  filter :qiraah, as: :select, collection: -> { Qiraah.all.map { |q| [q.name_en, q.id] } }
  filter :enabled

  permit_params do
    %i[name description name_ar name_en enabled]
  end

  searchable_select_options(
    scope: Riwayah,
    text_attribute: :name
  )

  index do
    id_column
    column :slug
    column :name
    column :name_ar
    column(:qiraah) { |r| r.qiraah&.name_en }
    column :enabled
    column(:unverified) { |r| r.unverified? }
    column :recitations_count
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :name
      row :name_ar
      row :name_en
      row(:qiraah) { |r| r.qiraah&.name_en }
      row :enabled
      row(:unverified) { |r| r.meta_data['unverified_note'] if r.unverified? }
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
