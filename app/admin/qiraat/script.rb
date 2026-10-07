# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                       :bigint           not null, primary key
#  column_name              :string
#  enabled                  :boolean          default(TRUE), not null
#  font_css_class           :string
#  font_family              :string
#  font_file_url            :string
#  kind                     :string           default("unicode"), not null
#  licence                  :string
#  meta_data                :jsonb            not null
#  name                     :string           not null
#  release_year             :integer
#  slug                     :string           not null
#  source_package           :string
#  source_sha256            :string
#  storage                  :string           default("rows"), not null
#  text_sha256              :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  ayah_resource_content_id :integer
#  riwayah_id               :integer
#  word_resource_content_id :integer
#
ActiveAdmin.register Script do
  menu parent: 'Qiraat', priority: 4
  actions :all, except: :destroy

  filter :slug
  filter :name
  filter :riwayah, as: :select, collection: -> { Riwayah.order(:id).map { |r| [r.to_s, r.id] } }
  filter :kind, as: :select, collection: Script::KINDS
  filter :storage, as: :select, collection: Script::STORAGES
  filter :enabled

  permit_params :name, :riwayah_id, :kind, :storage, :column_name, :font_family, :font_css_class, :font_file_url,
                :source_package, :source_sha256, :release_year, :licence, :word_resource_content_id, :ayah_resource_content_id, :enabled

  searchable_select_options(scope: Script, text_attribute: :slug)

  # One word in every unicode face the app declares, to see at a glance which
  # font files are missing or stale (P5.4). Word 1:4:1 differs between the
  # riwayat (مالك / ملك) and 2:4:1 ends in a Warsh/Qaloun alif-wasl form.
  action_item :font_samples, only: :index do
    link_to 'Font samples', font_samples_cms_scripts_path
  end

  collection_action :font_samples, method: :get do
    @sample_words = %w[1:4:1 2:4:1 1:1:1].filter_map { |loc| Word.unscoped.find_by(location: loc) }
    @scripts = Script.where(kind: 'unicode').where.not(font_css_class: [nil, '']).order(:id)
    render 'cms/scripts/font_samples', layout: 'active_admin'
  end

  index do
    id_column
    column :slug
    column :name
    column(:riwayah) { |s| s.riwayah && link_to(s.riwayah.to_s, cms_riwayah_path(s.riwayah)) }
    column :kind
    column :storage
    column :column_name
    column :font_css_class
    column('Rows') { |s| s.rows? ? WordText.for_script(s).count : '' }
    column :enabled
    column('Mushafs') { |s| s.mushafs.count }
    actions
  end

  show do
    attributes_table do
      row :id
      row :slug
      row :name
      row(:riwayah) { |s| s.riwayah && link_to(s.riwayah.to_s, cms_riwayah_path(s.riwayah)) }
      row :kind
      row :storage
      row :column_name
      row :font_family
      row :font_css_class
      row :font_file_url
      row :source_package
      row :source_sha256
      row :text_sha256
      row :release_year
      row :licence
      row(:word_resource_content) { |s| s.word_resource_content && link_to(s.word_resource_content.name, [:cms, s.word_resource_content]) }
      row(:ayah_resource_content) { |s| s.ayah_resource_content && link_to(s.ayah_resource_content.name, [:cms, s.ayah_resource_content]) }
      row(:enabled) { |s| s.enabled ? status_tag('enabled', class: 'ok') : status_tag('disabled') }
      row('Word rows') { |s| s.rows? ? WordText.for_script(s).count : 'column-backed' }
      row(:meta_data) { |s| pre JSON.pretty_generate(s.meta_data) }
      row :created_at
      row :updated_at
    end

    panel 'Sample: al-Fatihah 1:1 in this script' do
      verse = Verse.find_by(verse_key: '1:1')
      if verse && !resource.image?
        words = verse.all_words.where(char_type_name: 'word').to_a
        div class: "quran-text #{resource.css_class_for(words.first)}", style: 'font-size: 2em; direction: rtl' do
          words.map { |w| w.text_for(resource) }.compact.join(' ')
        end
      else
        span 'n/a'
      end
    end

    panel 'Mushafs cached from this script' do
      table_for resource.mushafs.order(:id) do
        column(:id) { |m| link_to m.id, [:cms, m] }
        column(:name)
        column(:default_font_name)
        column(:enabled)
      end
    end
  end

  form do |f|
    f.semantic_errors
    f.inputs 'Script' do
      f.input :slug, input_html: { disabled: true }
      f.input :name
      f.input :riwayah, as: :select, collection: Riwayah.order(:id).map { |r| [r.to_s, r.id] }
      f.input :kind, as: :select, collection: Script::KINDS
      f.input :storage, as: :select, collection: Script::STORAGES, hint: 'column: a words/verses column; rows: word_texts; legacy: quran_script_by_* tables'
      f.input :column_name
      f.input :font_family
      f.input :font_css_class
      f.input :font_file_url
      f.input :source_package
      f.input :source_sha256
      f.input :release_year
      f.input :licence
      f.input :word_resource_content_id
      f.input :ayah_resource_content_id
      f.input :enabled
    end
    f.actions
  end
end
