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
  actions :all, except: :destroy

  filter :name
  filter :ontology
  filter :thematic

  ActiveAdminViewHelpers.render_translated_name_sidebar(self)
  ActiveAdminViewHelpers.render_navigation_search_sidebar(self)

  searchable_select_options(scope: Topic,
                            text_attribute: :name,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                name_cont: term,
                                m: 'or'
                              ).result
                            end)

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
      row :childen_count
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

      if false
        row :words do
          div do
            resource.words.each do |w|
              div class: 'me_quran quran-text' do
                link_to(w.location, [:admin, w]).html_safe + "  -  #{w.text_uthmani}"
              end
            end
          end
        end

        row :verses do
          div do
            resource.verses.each do |v|
              div class: 'me_quran quran-text' do
                link_to(v.verse_key, [:admin, v]).html_safe + "  -  #{v.text_uthmani}"
              end
            end
          end
        end
      end
    end
  end
end
