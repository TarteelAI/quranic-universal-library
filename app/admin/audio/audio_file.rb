# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_files
#
#  id            :integer          not null, primary key
#  duration      :integer
#  format        :string
#  hizb_number   :integer
#  is_enabled    :boolean
#  juz_number    :integer
#  mime_type     :string
#  page_number   :integer
#  rub_el_hizb    :integer
#  segments      :text
#  url           :text
#  verse_key     :string
#  verse_number  :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  chapter_id    :integer
#  recitation_id :integer
#  verse_id      :integer
#
# Indexes
#
#  index_audio_files_on_chapter_id                   (chapter_id)
#  index_audio_files_on_chapter_id_and_verse_number  (chapter_id,verse_number)
#  index_audio_files_on_hizb_number                  (hizb_number)
#  index_audio_files_on_is_enabled                   (is_enabled)
#  index_audio_files_on_juz_number                   (juz_number)
#  index_audio_files_on_page_number                  (page_number)
#  index_audio_files_on_recitation_id                (recitation_id)
#  index_audio_files_on_rub_el_hizb                   (rub_el_hizb)
#  index_audio_files_on_verse_id                     (verse_id)
#  index_audio_files_on_verse_key                    (verse_key)
#
ActiveAdmin.register AudioFile do
  menu parent: 'Audio'
  actions :all, except: :destroy

  filter :recitation, as: :searchable_select,
                      ajax: { resource: Recitation }
  filter :verse, as: :searchable_select,
                 ajax: { resource: Verse }

  action_item :validate_segments, only: :show do
    link_to 'Validate segments', '#_', id: 'validate-segments',
            data: { controller: 'ajax-modal', url: validate_segments_admin_recitation_path(resource.recitation_id, chapter_id: resource.chapter_id) }
  end

  action_item :view_segments, only: :show do
    link_to 'View in segment tool', segment_builder_ayah_audio_file_path(resource.recitation_id, chapter_id: resource.chapter_id, verse: resource.verse_number), target: '_blank', rel: 'noopener'
  end

  index do
    id_column
    column :verse do |resource|
      link_to(resource.verse.verse_key, [:admin, resource.verse])
    end
    column :duration
    column :url
    column :format
    actions
  end

  show do
    attributes_table do
      row :id
      row :verse_key
      row :verse
      row :chapter
      row :url
      row :duration
      row :recitation
      row :segments do
        div do
          resource.segments.each do |segment|
            div segment.join(', ')
          end
        end
      end
      row :created_at
      row :updated_at
    end
  end

  sidebar 'Audio URL', only: :show do
    div(link_to 'View', resource.audio_url)
  end

  permit_params do
    %i[
      verse_id
      url
      duration
      segments
      recitation_id
    ]
  end

  def scoped_collection
    super.includes :verse
  end
end
