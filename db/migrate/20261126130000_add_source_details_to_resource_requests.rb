# What a request can say about the resource it asks for, so editors can add it without asking
# again: the author, book name, publisher and year of a written work, the licence, and a link to
# where it can be fetched. Uploaded source files are Active Storage attachments
# (ResourceRequest#source_files), so they need no column. Which fields a request type asks for,
# and which it requires, is a model rule (ResourceRequest::DETAILS).
# Reversible: a rollback drops the columns; source file attachments stay behind and are purged
# by hand.
class AddSourceDetailsToResourceRequests < ActiveRecord::Migration[8.0]
  def change
    change_table :resource_requests, bulk: true do |t|
      t.string :author
      t.string :book_name
      t.string :publisher
      t.integer :publishing_year
      t.text :license_details
      t.string :source_url
    end
  end
end
