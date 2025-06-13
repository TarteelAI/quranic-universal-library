# frozen_string_literal: true

ActiveAdmin.register Dictionary::WordRoot do
  menu parent: 'Dictionary'

  searchable_select_options(
    scope: Dictionary::WordRoot,
    text_attribute: :arabic_trilateral,
    filter: lambda do |term, scope|
      scope.ransack(
        arabic_trilateral_cont: term,
        english_trilateral_cont: term,
        m: 'or'
      ).result
    end
  )

  filter :arabic_trilateral
  filter :english_trilateral
  filter :root_number
  filter :root,
         as: :searchable_select,
         class: 'soft-keyboard',
         ajax: { resource: Root }

  permit_params do
    %i[
      arabic_trilateral
      english_trilateral
      cover_url
      description
      frequency
      root_number
      root_id
    ]
  end

  form do |f|
    f.inputs 'Root word detail' do
      f.input :root,
              as: :searchable_select,
              ajax: { resource: Root }
      f.input :frequency
      f.input :arabic_trilateral
      f.input :english_trilateral
      f.input :root_number
      f.input :description
      f.input :cover_url
    end
    f.actions
  end

  show style: 'font-size: 30px' do
    attributes_table do
      row :id
      row :root_number
      row :arabic_trilateral
      row :english_trilateral
      row :frequency
      row :description
      row :cover_url

      row :root do
        root = resource.root

        link_to(root.value, "/cms/roots/#{root.id}") if root
      end

      row :created_at
      row :updated_at
    end

    panel 'Definations' do
      table style: 'table-layout:fixed' do
        thead do
          td 'Id'
          td 'Defination type'
          td 'Description'
        end

        tbody style: 'font-size: 30px' do
          resource.root_definitions.each do |defination|
            tr do
              td link_to(defination.id, [:cms, defination])
              td defination.definition_type
              td defination.description
            end
          end
        end
      end
    end

    panel 'Quranic Usage' do
      table do
        thead do
          td 'Id'
          td 'Word Arabic'
          td 'Word Translation'
          td 'Segment Arabic'
          td 'Segment Translation'
        end

        tbody do
          resource.root_examples.each do |example|
            tr style: 'font-size: 30px' do
              td link_to(example.id, [:cms, example])
              td example.word_arabic, class: 'qpc-hafs', style: 'white-space: nowrap;'
              td example.word_translation, style: 'white-space: nowrap;'
              td highlight(example.segment_arabic, example.word_arabic), class: 'qpc-hafs',
                 style: 'white-space: nowrap;'
              td example.segment_translation, style: 'white-space: wrap;'
            end
          end
        end
      end
    end
  end
end
