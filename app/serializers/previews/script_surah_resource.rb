# frozen_string_literal: true

module Previews
  # A surah a script preview can show.
  class ScriptSurahResource < ApplicationResource
    typelize number: :number, name: :string, verses_count: :number
    attributes :number, :name, :verses_count
  end
end
