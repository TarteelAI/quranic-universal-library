# frozen_string_literal: true

# == Schema Information
#
# Table name: counting_systems
#
#  id             :bigint           not null, primary key
#  description_ar :text
#  description_en :text
#  is_reference   :boolean          default(FALSE), not null
#  name_ar        :string           not null
#  name_en        :string           not null
#  slug           :string           not null
#  total_ayahs    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
ActiveAdmin.register CountingSystem do
  menu parent: 'Qiraat', priority: 3
  actions :index, :show, :edit, :update

  filter :slug
  filter :name_en
  filter :is_reference

  permit_params :description_en, :description_ar

  index do
    id_column
    column :slug
    column :name_en
    column :name_ar
    column :total_ayahs
    column :is_reference
    column('Qiraat (attributed)') { |cs| cs.qiraat.map(&:name_en).join(', ') }
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :name_en
      row :name_ar
      row(:total_ayahs) { |cs| "#{cs.total_ayahs} (from the pinned dataset; the First Madinan total is disputed upstream)" }
      row :is_reference
      row :description_en
      row :description_ar
      row :created_at
      row :updated_at
    end

    panel 'Qiraat attributed to this counting system' do
      table_for resource.qiraat do
        column(:position)
        column(:slug) { |q| link_to q.slug, cms_qiraah_path(q) }
        column(:name_en)
        column(:name_ar)
      end
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs 'Descriptions (slug, names and totals come from the dataset)' do
      f.input :description_en
      f.input :description_ar
    end
    f.actions
  end
end
