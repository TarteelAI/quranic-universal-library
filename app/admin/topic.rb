# frozen_string_literal: true

# == Schema Information
#
# Table name: topics
#
#  id         :integer          not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :integer
#
# Indexes
#
#  index_topics_on_parent_id  (parent_id)
#
ActiveAdmin.register Topic do
  menu parent: 'Content'
  actions :all, except: [:destroy, :new, :create]

  searchable_select_options(
    scope: Topic,
    text_attribute: :name,
    filter: lambda do |term, scope|
      scope.ransack(
        name_cont: term,
        id_eq: term,
        m: 'or'
      ).result
    end
  )

  filter :name
  filter :ontology, as: :boolean
  filter :thematic, as: :boolean
  includes :parent

  index do
    selectable_column
    column :id
    column :name
    column :ontology
    column :thematic
    column :parent, sortable: :parent_id
    column :children_count
    actions
  end

  show do
    attributes_table do
      row :id
      row :name
      row :arabic_name

      row :description do
        resource.description.to_s.html_safe
      end

      row :ontology
      row :thematic

      row :parent
      row :ontology_parent
      row :thematic_parent

      row :children
      row :ontology_children
      row :thematic_children

      row :related_topics do
        div do
          resource.related_topics.includes(:related_topic).each do |rt|
            span link_to(rt.related_topic.name, [:admin, rt.related_topic])
          end
        end
      end

      row :children_count
      row :depth

      row :verses do
        div do
          resource.verse_topics.includes(verse: :words).each do |verse_topic|
            div class: 'qpc-hafs quran-text' do
              link_to([:admin, verse_topic.verse]) do
                span verse_topic.verse.verse_key, title: "(tematic: #{verse_topic.thematic?}, ontology: #{verse_topic.ontology?})"
                verse_topic.verse.words.each do |w|
                  span w.text_qpc_hafs, class: "#{'text-success' if verse_topic.topic_words.include?(w.position)}"
                end
              end
            end
          end
        end
      end
    end
  end

  form do |f|
    f.inputs 'Topic detail' do
      f.input :name
      f.input :arabic_name
      f.input :description
      f.input :ontology
      f.input :thematic
      f.input :parent, as: :searchable_select, ajax: { resource: Topic }
      f.input :ontology_parent, as: :searchable_select, ajax: { resource: Topic }
      f.input :thematic_parent, as: :searchable_select, ajax: { resource: Topic }
    end

    f.actions
  end

  permit_params :name, :arabic_name, :description, :ontology, :thematic, :parent_id, :ontology_parent_id, :thematic_parent_id
end
