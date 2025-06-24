# frozen_string_literal: true

ActiveAdmin.register_page 'Preview' do
  menu parent: 'Dictionary'

  content do
    if params[:id]
      word_root = Dictionary::WordRoot.find params[:id]
      render 'admin/dictionary_page_preview', word_root: word_root
    else
      h2 'Select root word to preview'
      ul do
        Dictionary::WordRoot.find_each do |word|
          li do
            link_to word.id, "/cms/preview?id=#{word.id}"
          end
        end
      end
    end
  end
end
