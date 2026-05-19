# == Schema Information
#
# Table name: books
#
#  id                     :bigint           not null, primary key
#  editor                 :string
#  editor_notes           :text
#  edition_number         :integer
#  edition_year_gregorian :integer
#  edition_year_hijri     :integer
#  isbn                   :string
#  meta_data              :jsonb
#  notes                  :text
#  publisher              :string
#  publisher_location     :string
#  source_url             :string
#  title                  :string
#  volumes_count          :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  resource_content_id    :integer          not null
#
# Indexes
#
#  index_books_on_resource_content_id  (resource_content_id) UNIQUE
#
class Book < QuranApiRecord
  include HasMetaData

  belongs_to :resource_content, optional: true
  belongs_to :author, optional: true
  has_many :translated_names, as: :resource
end
