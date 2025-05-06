class AddGlyphCodesToChapters < ActiveRecord::Migration[7.0]
  def change
    c = Chapter.connection
    names = [:v1, :v4, :color_header, :v2]
    names.each do |name|
      c.add_column :chapters, "#{name}_chapter_glyph_code", :string, if_not_exists: true
    end
  end
end
