# frozen_string_literal: true

ActiveAdmin.register Morphology::Word do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  filter :word,
         as: :searchable_select,
         ajax: { resource: Word }
  filter :location

  searchable_select_options(
    scope: Morphology::Word,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        location_cont: term,
        m: 'or'
      ).result
    end
  )

  permit_params do
    %i[case case_reason grammar_pattern_id grammar_base_pattern_id description]
  end

  index do
    id_column
    column :word do |resource|
      link_to(resource.word_id, "/cms/words/#{resource.word_id}")
    end
    column :location
    actions
  end

  form do |f|
    f.inputs 'Morphology Word Detail' do
      f.input :case
      f.input :case_reason

      f.input :grammar_pattern
      f.input :grammar_base_pattern

      f.input :description, input_html: { data: { controller: 'tinymce' } }
    end

    f.actions
  end

  show do
    attributes_table do
      row :id
      row :word do
        link_to(resource.word.text_qpc_hafs, "/cms/words/#{resource.word_id}", class: 'qpc-hafs')
      end
      row :grammar_pattern
      row :grammar_base_pattern
      row :words_count_for_root
      row :words_count_for_stem
      row :words_count_for_lemma
      row :case
      row :case_reason
      row :location
      row :description do
        div safe_html(resource.description)
      end
    end

    active_admin_comments

    panel 'Morphological Segments' do
      table border: 1 do
        thead do
          th 'Id'
          th 'Position'
          th 'POS'
          th 'Tags'
          th 'Arabic'
          th 'Root'
          th 'Lemma'
        end

        tbody do
          resource.word_segments.each do |segment|
            tr do
              td link_to segment.id, [:cms, segment]
              td segment.position
              td "#{segment.part_of_speech_key} - #{segment.part_of_speech_name}"
              td segment.pos_tags
              td segment.text_uthmani, class: 'quran me_quran'
              td segment.root_name, class: 'quran me_quran'
              th segment.lemma_name, class: 'quran me_quran'
            end
          end
        end
      end
    end

    panel 'Derived Words' do
      table border: 1 do
        thead do
          th 'ID'
          th 'Form'
          th 'Verse'
          td 'Transliteration'
        end

        tbody do
          resource.derived_words.each do |derived|
            tr do
              td derived.id
              td "#{derived.word_verb_from_id}-#{derived.form_name}", class: 'quran me_quran'
              td link_to(derived.verse_id, "/cms/verses/#{derived.verse_id}", target: '_blank', rel: 'noopener')
              td derived.en_transliteration
            end
          end
        end
      end
    end

    panel 'Verb Forms' do
      table border: 1 do
        thead do
          th 'Name'
          th 'Value'
        end

        tbody do
          resource.verb_forms.each do |form|
            tr do
              td form.name
              td form.value, class: 'quran me_quran'
            end
          end
        end
      end
    end
  end

  def scoped_collection
    super.includes :word
  end

  controller do
    def find_resource
      collection = scoped_collection
                     .includes(
                       :verse,
                       :word,
                       :verb_forms,
                       :derived_words,
                       :word_segments
                     )

      if params[:id].to_s.include?(':')
        collection.find_by(location: params[:id]) || raise(ActiveRecord::RecordNotFound.new("Couldn't find Word with 'location'=#{params[:id]}"))
      else
        collection.find(params[:id])
      end
    end
  end
end
