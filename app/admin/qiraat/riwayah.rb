# frozen_string_literal: true

# == Schema Information
#
# Table name: riwayat
#
#  id                   :bigint           not null, primary key
#  description          :text
#  enabled              :boolean          default(FALSE), not null
#  meta_data            :jsonb            not null
#  name                 :string
#  name_ar              :string
#  name_en              :string
#  recitations_count    :integer          default(0)
#  slug                 :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  default_numbering_id :integer
#  qiraah_id            :integer
#
# Formerly registered as QiratType under the Audio menu (route /cms/qirat_types).
ActiveAdmin.register Riwayah do
  menu parent: 'Qiraat', priority: 2
  actions :all, except: :destroy

  filter :slug
  filter :name
  filter :name_en
  filter :qiraah, as: :select, collection: -> { Qiraah.all.map { |q| [q.name_en, q.id] } }
  filter :enabled

  permit_params :name, :name_ar, :name_en, :description, :enabled

  searchable_select_options(
    scope: Riwayah,
    text_attribute: :name
  )

  index do
    id_column
    column :slug
    column :name
    column :name_en
    column :name_ar
    column(:qiraah) { |r| r.qiraah && link_to(r.qiraah.name_en, cms_qiraah_path(r.qiraah)) }
    column :enabled
    column('Unverified') { |r| r.unverified? ? status_tag('unverified', class: 'warning') : '' }
    column('Mushafs') { |r| r.mushafs.count }
    column :recitations_count
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :name
      row :name_en
      row :name_ar
      row(:qiraah) { |r| r.qiraah && link_to(r.qiraah.name_en, cms_qiraah_path(r.qiraah)) }
      row('Counting system (attributed to the qari)') { |r| r.qiraah&.counting_system&.name_en }
      row(:enabled) { |r| r.enabled ? status_tag('enabled', class: 'ok') : status_tag('disabled') }
      row('Unverified') { |r| r.unverified? ? r.meta_data['unverified_note'] : 'no' }
      row :default_numbering_id
      row :description
      row :recitations_count
      row :created_at
      row :updated_at
    end

    panel 'Mushafs' do
      table_for resource.mushafs.order(:id) do
        column(:id) { |m| link_to m.id, [:cms, m] }
        column(:name)
        column(:default_font_name)
        column(:pages_count)
        column(:enabled)
      end
    end

    panel 'Ayah recitations' do
      table_for resource.verse_recitations.includes(:recitation_style).order(:id) do
        column(:id) { |r| link_to r.id, [:cms, r] }
        column(:name)
        column('Style') { |r| r.recitation_style&.name }
      end
    end

    panel 'Surah recitations' do
      table_for resource.audio_recitations.includes(:recitation_style).order(:id) do
        column(:id) { |r| link_to r.id, [:cms, r] }
        column(:name)
        column('Style') { |r| r.recitation_style&.name }
      end
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs 'Riwayah' do
      f.input :slug, input_html: { disabled: true }, hint: 'From qiraat-ayah-map; not editable'
      f.input :name, hint: 'Legacy display name shown on recitations and mushafs'
      f.input :name_en
      f.input :name_ar
      f.input :description
      f.input :enabled, hint: 'The public switch: scripts, mushafs and overrides of this riwayah are served only when enabled'
    end
    f.actions
  end
end
