# frozen_string_literal: true

# == Schema Information
#
# Table name: morphology_word_segments
#
#  id                        :bigint           not null, primary key
#  grammar_term_desc_arabic  :string
#  grammar_term_desc_english :string
#  grammar_term_key          :string
#  grammar_term_name         :string
#  hidden                    :boolean
#  lemma_name                :string
#  part_of_speech_key        :string
#  part_of_speech_name       :string
#  pos_tags                  :string
#  position                  :integer
#  root_name                 :string
#  text_uthmani              :string
#  verb_form                 :string
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  grammar_concept_id        :bigint
#  grammar_role_id           :bigint
#  grammar_sub_role_id       :bigint
#  grammar_term_id           :bigint
#  lemma_id                  :bigint
#  root_id                   :bigint
#  topic_id                  :bigint
#  word_id                   :bigint
#
# Indexes
#
#  index_morphology_word_segments_on_grammar_concept_id   (grammar_concept_id)
#  index_morphology_word_segments_on_grammar_role_id      (grammar_role_id)
#  index_morphology_word_segments_on_grammar_sub_role_id  (grammar_sub_role_id)
#  index_morphology_word_segments_on_grammar_term_id      (grammar_term_id)
#  index_morphology_word_segments_on_lemma_id             (lemma_id)
#  index_morphology_word_segments_on_part_of_speech_key   (part_of_speech_key)
#  index_morphology_word_segments_on_pos_tags             (pos_tags)
#  index_morphology_word_segments_on_position             (position)
#  index_morphology_word_segments_on_root_id              (root_id)
#  index_morphology_word_segments_on_topic_id             (topic_id)
#  index_morphology_word_segments_on_word_id              (word_id)
#
# Foreign Keys
#
#  fk_rails_...  (lemma_id => lemmas.id)
#  fk_rails_...  (root_id => roots.id)
#  fk_rails_...  (topic_id => topics.id)
#  fk_rails_...  (word_id => words.id)
#
ActiveAdmin.register Morphology::WordSegment do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  filter :word_id, as: :searchable_select,
                   ajax: { resource: Word }
  filter :part_of_speech_key
  filter :pos_tags
  filter :verb_form

  searchable_select_options(scope: Morphology::WordSegment,
                            text_attribute: :humanize,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                location_cont: term,
                                m: 'or'
                              ).result
                            end)

  permit_params do
    %i[text_uthmani position part_of_speech_key
       part_of_speech_name pos_tags
       grammar_term_desc_arabic
       grammar_term_desc_english
       verb_form
       lemma_name
       lemma_id
       root_name
       root_id
       topic_id
       grammar_concept_id
       grammar_role
       grammar_sub_role]
  end

  index do
    selectable_column
    id_column
    column :word_id do |resource|
      link_to resource.word.location, [:admin, resource.word]
    end
    column :position

    column :part_of_speech_key
    column :pos_tags

    column :text_uthmani
    column :root_name
    column :verb_form
  end

  form do |f|
    f.inputs 'Morphology Word Segment Detail' do
      f.input :text_uthmani
      f.input :position
      f.input :pos_tags
      f.input :part_of_speech_key
      f.input :part_of_speech_name

      f.input :grammar_term_desc_arabic
      f.input :grammar_term_desc_english
      f.input :verb_form

      f.input :lemma_name
      f.input :lemma_id,
              as: :searchable_select,
              ajax: { resource: Lemma }

      f.input :root_name
      f.input :root_id,
              as: :searchable_select,
              ajax: { resource: Root }
      f.input :topic_id,
              as: :searchable_select,
              ajax: { resource: Topic }
      f.input :grammar_concept, as: :searchable_select,
                                ajax: { resource: Root }
      f.input :grammar_role
      f.input :grammar_sub_role
      f.input :grammar_term, as: :searchable_select,
                             ajax: { resource: Morphology::GrammarTerm }
    end

    f.actions
  end

  def scoped_collection
    super.includes :word
  end
end
