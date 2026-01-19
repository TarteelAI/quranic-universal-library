ActiveAdmin.register Morphology::GrammarTermTranslation do
  menu parent: 'Morphology'
  actions :all, except: :destroy

  permit_params do
    %i[grammar_term_id locale title description]
  end

  filter :locale, as: :select, collection: %w[en ar ur]
  filter :title
  filter :grammar_term_id

  index do
    id_column
    column :grammar_term do |tr|
      link_to tr.grammar_term.to_s, [:cms, tr.grammar_term]
    end
    column :locale
    column :title
    column :updated_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :grammar_term do |tr|
        link_to tr.grammar_term.to_s, [:cms, tr.grammar_term]
      end
      row :locale
      row :title
      row :description do |tr|
        div safe_html(tr.description)
      end
      row :created_at
      row :updated_at
    end

    active_admin_comments
  end

  form do |f|
    f.inputs 'Grammar Term Translation' do
      f.input :grammar_term
      f.input :locale, as: :select, collection: %w[en ar ur], include_blank: false
      f.input :title
      f.input :description, input_html: { data: { controller: 'tinymce' } }
    end
    f.actions
  end
end

