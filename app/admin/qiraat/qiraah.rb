# frozen_string_literal: true

# == Schema Information
#
# Table name: qiraat
#
#  id                 :bigint           not null, primary key
#  description        :text
#  name_ar            :string           not null
#  name_en            :string           not null
#  position           :integer
#  slug               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  counting_system_id :integer
#
ActiveAdmin.register Qiraah do
  menu parent: 'Qiraat', priority: 1
  actions :index, :show, :edit, :update

  filter :slug
  filter :name_en
  filter :counting_system, as: :select, collection: -> { CountingSystem.order(:slug).map { |c| [c.name_en, c.id] } }

  permit_params :description

  index do
    column :position
    column(:slug) { |q| link_to q.slug, cms_qiraah_path(q) }
    column :name_en
    column :name_ar
    column('Counting (attributed)') { |q| q.counting_system&.name_en }
    column('Riwayat') { |q| q.riwayat.map { |r| link_to(r.slug, cms_riwayah_path(r)) }.join(', ').html_safe }
    actions
  end

  show do
    attributes_table do
      row :id
      row :position
      row :slug
      row :name_en
      row :name_ar
      row('Counting system (attributed to the qari)') { |q| q.counting_system && link_to(q.counting_system.name_en, cms_counting_system_path(q.counting_system)) }
      row :description
      row :created_at
      row :updated_at
    end

    panel 'Riwayat' do
      table_for resource.riwayat.order(:id) do
        column(:id)
        column(:slug) { |r| link_to r.slug, cms_riwayah_path(r) }
        column(:name_en)
        column(:name_ar)
        column(:enabled)
        column('Unverified') { |r| r.unverified? ? 'yes' : '' }
        column('Mushafs') { |r| r.mushafs.count }
        column('Recitations') { |r| r.verse_recitations.count + r.audio_recitations.count }
      end
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs 'Description (slug, names and counting system come from the dataset)' do
      f.input :description
    end
    f.actions
  end
end
