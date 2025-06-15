# frozen_string_literal: true

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
  filter :depth
  filter :ontology, as: :boolean
  filter :thematic, as: :boolean
  filter :chapter_id_cont,
         as: :searchable_select,
         ajax: { resource: Chapter }
  filter :verse_id,
         as: :searchable_select,
         ajax: { resource: Verse }
  filter :resource_content,
         as: :searchable_select,
         ajax: { resource: ResourceContent }

  includes :parent

  index do
    id_column
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
        safe_html resource.description
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
            span link_to(rt.related_topic.name, [:cms, rt.related_topic])
          end
        end
      end

      row :children_count
      row :depth

      row :verses do
        div do
          resource.verse_topics.includes(verse: :words).each do |verse_topic|
            div class: 'qpc-hafs quran-text' do
              link_to([:cms, verse_topic.verse]) do
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
