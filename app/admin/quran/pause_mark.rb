# frozen_string_literal: true

ActiveAdmin.register PauseMark do
  menu parent: 'Quran'
  filter :word_id
  filter :mark
  filter :verse_key
  filter :position
  actions :index, :show

  permit_params do
    %i[verse_key word_id mark position]
  end

  controller do
    def create
      word = Word.find(params[:word_id])
      mark = PauseMark.create(
        position: word.position,
        word_id: word.id,
        mark: params[:mark],
        verse_key: word.verse_key
      )

      respond_to do |format|
        format.all { render json: mark.mark }
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :word_id
      f.input :mark
      f.input :position
      f.input :verse_key
    end

    f.actions
  end
end
