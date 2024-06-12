# frozen_string_literal: true

# == Schema Information
#
# Table name: translations
#
#  id                  :integer          not null, primary key
#  hizb_number         :integer
#  juz_number          :integer
#  language_name       :string
#  page_number         :integer
#  priority            :integer
#  resource_name       :string
#  rub_el_hizb          :integer
#  text                :text
#  verse_key           :string
#  verse_number        :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  chapter_id          :integer
#  language_id         :integer
#  resource_content_id :integer
#  verse_id            :integer
#
# Indexes
#
#  index_translations_on_chapter_id                   (chapter_id)
#  index_translations_on_chapter_id_and_verse_number  (chapter_id,verse_number)
#  index_translations_on_hizb_number                  (hizb_number)
#  index_translations_on_juz_number                   (juz_number)
#  index_translations_on_language_id                  (language_id)
#  index_translations_on_page_number                  (page_number)
#  index_translations_on_priority                     (priority)
#  index_translations_on_resource_content_id          (resource_content_id)
#  index_translations_on_rub_el_hizb                   (rub_el_hizb)
#  index_translations_on_verse_id                     (verse_id)
#  index_translations_on_verse_key                    (verse_key)
#
ActiveAdmin.register Translation do
  menu parent: 'Content'
  actions :all, except: :destroy

  searchable_select_options(scope: Translation, text_attribute: :text)

  ActiveAdminViewHelpers.versionate(self)

  filter :text
  filter :language_id, as: :searchable_select,
                       ajax: { resource: Language }
  filter :resource_content, as: :searchable_select,
                            ajax: { resource: ResourceContent }
  filter :verse, as: :searchable_select,
                 ajax: { resource: Verse }

  index do
    column :id do |resource|
      link_to(resource.id, [:admin, resource])
    end
    column :language, &:language_name
    column :verse_id do |resource|
      link_to resource.verse_key, admin_verse_path(resource.verse_id)
    end
    column :text, sortable: :text do |resource|
      resource.text.first(100)
    end

    actions
  end

  show do
    attributes_table do
      row :id
      row :verse do |resource|
        link_to resource.verse.verse_key, admin_verse_path(resource.verse)
      end
      row :resource_content do
        r = resource.get_resource_content
        link_to(r.name, [:admin, r])
      end
      row :language
      row :priority
      row :resource_name
      row :page_number
      row :rub_el_hizb

      row :text do |resource|
        div class: resource.language_name.to_s.downcase, 'data-controller': 'translation' do
          resource.text.html_safe
        end
      end

      row :created_at
      row :updated_at
    end

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
    ActiveAdminViewHelpers.compare_panel(self, resource) if params[:compare]

    active_admin_comments
  end

  def scoped_collection
    super.includes :language # prevents N+1 queries to your database
  end

  permit_params do
    %i[language_id verse_id text language_name resource_content_id]
  end

  form do |f|
    f.inputs 'Translation Detail' do
      f.input :text, as: :text

      f.input :resource_content,
              as: :searchable_select,
              ajax: { resource: ResourceContent }

      f.input :resource_name

      f.input :language,
              as: :searchable_select,
              ajax: { resource: Language }

      f.input :language_name
      f.input :verse_id
    end

    f.actions
  end
end
