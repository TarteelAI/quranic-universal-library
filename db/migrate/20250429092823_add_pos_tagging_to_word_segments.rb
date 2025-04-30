class AddPosTaggingToWordSegments < ActiveRecord::Migration[7.0]
  def change
    c = Morphology::WordSegment.connection
    cols = [
      :segment_type,
      :person_type,
      :voice_type,
      :gender_type,
      :number_type,
      :aspect_type,
      :mood_type,
      :derivation_type,
      :state_type,
      :case_type,
      :pronoun_type,
      :special_type,
      :text_qpc_hafs
    ]
    cols.each do |col|
      c.add_column :morphology_word_segments, col, :string
      c.add_index :morphology_word_segments, col
    end
  end
end
