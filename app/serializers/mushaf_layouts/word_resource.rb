# frozen_string_literal: true

module MushafLayouts
  # One word or mark on a mushaf page line. For glyph layouts the text is the page font's glyph.
  class WordResource < ApplicationResource
    typelize id: :number, text: :string, char_type_name: :string, verse_id: :number
    attributes :id, :text, :char_type_name, :verse_id
  end
end
