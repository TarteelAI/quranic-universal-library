module Segments
  class SegmentsDb < ApplicationRecord
    has_one_attached :db_file

    def load_db(file_path)
    end
  end
end