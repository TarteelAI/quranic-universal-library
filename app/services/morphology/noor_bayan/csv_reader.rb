require 'csv'

module Morphology
  module NoorBayan
    class CsvReader
      def initialize(path)
        @path = path
      end

      def each_row
        CSV.foreach(@path, encoding: 'BOM|UTF-16LE:UTF-8', col_sep: "\t", headers: true) do |row|
          yield row.to_h
        end
      end
    end
  end
end
