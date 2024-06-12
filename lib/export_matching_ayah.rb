=begin
export data format
{
  '1:1': [
      {key: '1:2', score: 45, words: [[1,2]]}
  ]
}
=end

class ExportMatchingAyah
  def execute(min_score: 50)
    mapping = {}

    Verse.find_each do |v|
      matching = v.get_matching_verses
      matching = matching.approved.or(matching.where('score >= ?', min_score))

      if matching.present?
        mapping[v.verse_key] = []

        matching.each do |m|
          next if v.id == m.matched_verse_id

          mapping[v.verse_key].push({
                                      key: m.matched_verse.verse_key,
                                      score: m.score.to_i,
                                      words: to_ranges(m.matched_word_positions)
                                    })
        end
      end
    end

    json_file_path = Rails.root.join("public", "matching_ayah.json")

    File.open(json_file_path, "wb") do |f|
      f.puts mapping.to_json
    end

    json_file_path
  end

  protected

  def to_ranges(array)
    result = []
    range = []
    last_num = nil
    array = array.uniq.map(&:to_i).sort

    array.each do |num|
      if last_num.nil? || last_num + 1 == num
        range.push(num)
      else
        result.push([range.first, range.last].uniq) if range.present?
        range = [num]
      end

      last_num = num
    end

    result.push([range.first, range.last].uniq) if range.present?

    result
  end
end