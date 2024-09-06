module HasVerseMapping
  extend ActiveSupport::Concern

  included do
    belongs_to :first_verse, class_name: 'Verse'
    belongs_to :last_verse, class_name: 'Verse'

    scope :chapter_id_cont, lambda {|chapter_id|
      verses = Verse.order('verse_index ASC').where(chapter_id: chapter_id).select(:id)

      first_verse_id = verses.first.id
      last_verse_id = verses.last.id

      where('first_verse_id <= ? AND last_verse_id >= ?', last_verse_id, first_verse_id)
    }

    def self.ransackable_scopes(*)
      %i[chapter_id_cont]
    end
  end
end