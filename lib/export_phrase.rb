# export data format
# phrases.json
# {
#   'phrase id': {
#      'source': {key: 'ayah key', from: 'phrase starting word position', to: 'phrase ending word position'}
#   },
#  ayahs: {
#    'verse key': {from: 'phrase starting word position', to: 'phrase ending word position'}
# }
# }

class ExportPhrase
  attr_reader :exported_phrase_ids
  def execute(min_phrase_length: 3)
    @exported_phrase_ids = []
    folder_path = 'public/phrases/'
    zip_folder_path = 'public/phrases.zip'

    FileUtils.rm_f folder_path
    FileUtils.rm(zip_folder_path) if File.exist?(zip_folder_path)

    FileUtils.mkdir_p folder_path
    export_phrases(min_phrase_length)
    export_phrase_verses
    require 'zip'

    Zip::File.open(zip_folder_path, Zip::File::CREATE) do |zipfile|
      Dir[File.join(folder_path, '**', '**')].each do |file|
        relative_path = file.sub(folder_path, '')

        zipfile.add(relative_path, file) unless File.directory?(file)
      end
    end

    send_email(zip_folder_path) if Rails.env.production?

    zip_folder_path
  end

  def disable_duplicate_phrases
    duplicate_records = Morphology::PhraseVerse.approved
                                               .select(:verse_id, :word_position_from, :word_position_to, 'STRING_AGG(phrase_id::text, \',\') AS phrase_ids', 'STRING_AGG(id::text, \',\') AS ids')
                                               .group(:verse_id, :word_position_from, :word_position_to)
                                               .having('COUNT(*) > 1')

    duplicate_records.each do |record|
      phrase_ids = record.phrase_ids.split(',')
      id = phrase_ids.shift

      Morphology::Phrase.where(id: phrase_ids).update_all(approved: false, review_status: "duplicate of #{id}")
    end
  end

  def verify_phrase_data
    phrases = Oj.load File.read('public/phrases/phrases.json')
    phrase_verses = Oj.load File.read('public/phrases/ayah-phrases.json')
    highlight_mapping = {}
    issues_count = 0

    phrase_verses.each do |k, ids|
      ids.each do |id|
        phrase = phrases[id.to_s]
        verse_range = phrase['ayah'][k]
        highlight_range_key = "#{k}-#{verse_range.join('-')}"

        if highlight_mapping[highlight_range_key]
          puts "#{k} #{verse_range} is already highlighted by phrase #{highlight_mapping[highlight_range_key][:phrase]}"
          issues_count +=1
        end

        highlight_mapping[highlight_range_key] ||= {
          phrase: id
        }

        if phrase.blank?
          puts "Phrase #{id} is not found in phrases.json"
          issues_count +=1
        elsif phrase['ayah'].blank?
          puts "Phrase #{id} does not have ayah"
          issues_count +=1
        elsif phrase['source'].blank?
          puts "Phrase #{id} does not have source ayah"
          issues_count +=1
        end
      end
    end

    puts "Done. Found #{issues_count} issues"
  end

  protected

  def export_phrases(min_phrase_length = 3)
    mapping = {}
    approved =  approved_phrases(min_phrase_length)

    approved.find_each do |phrase|
      next if mapping[phrase.id] || should_export_phrase?(phrase, approved) == false
      @exported_phrase_ids.push(phrase.id)

      mapping[phrase.id] = {
        surahs: phrase.chapters_count,
        ayahs: phrase.verses_count,
        count: phrase.occurrence,
        source: {
          key: phrase.source_verse.verse_key,
          from: phrase.word_position_from,
          to: phrase.word_position_to
        },
        ayah: {}
      }

      ranges = {}
      phrase.phrase_verses.approved.map do |p_verse|
        ranges[p_verse.verse.verse_key] ||= []
        ranges[p_verse.verse.verse_key].push([p_verse.word_position_from, p_verse.word_position_to])
      end

      mapping[phrase.id][:ayah] = ranges
    end

    json_file_path = Rails.root.join('public', 'phrases', 'phrases.json')

    File.open(json_file_path, 'wb') do |f|
      f.puts mapping.to_json
    end
  end

  def should_export_phrase?(phrase, all_phrases)
    return false if phrase.verses_count < 2 || phrase.occurrence < 2

    parent = all_phrases.where("id != ?", phrase.id).where("text_qpc_hafs_simple like ?", "%#{phrase.text_qpc_hafs_simple}%").first

    if parent
      return false if parent.verses_count == phrase.verses_count && parent.occurrence == phrase.occurrence
      return false if parent.verses_count > phrase.verses_count && parent.text_qpc_hafs_simple.include?(phrase.text_qpc_hafs_simple)
    end

    true
  end

  def _remove_subarrays(phrases)
    result = []

    phrases.each_with_index do |item, i|
      parent = phrases.detect do |p|

      end
    end

    result
  end

  def export_phrase_verses
    mapping = {}

    Morphology::PhraseVerse.approved.where(phrase_id: @exported_phrase_ids).includes(:verse).find_each do |p_verse|
      mapping[p_verse.verse.verse_key] ||= []

      if !mapping[p_verse.verse.verse_key].include?(p_verse.phrase_id)
        mapping[p_verse.verse.verse_key].push(p_verse.phrase_id)
      end
    end

    json_file_path = Rails.root.join('public', 'phrases', 'ayah-phrases.json')

    File.open(json_file_path, 'wb') do |f|
      f.puts mapping.to_json
    end
  end

  def approved_phrases(min_phrase_length)
    Morphology::Phrase.approved
                      .includes(:source_verse, phrase_verses: :verse)
                      .where('words_count >= ?', min_phrase_length)
                      .where('occurrence > 1')
                      .where('verses_count > 1')
                      .where(review_status: 'new')
  end

  def remove_subarrays(arrays)
    result = []

    arrays.each_with_index do |array, i|
      is_subset = arrays.each_with_index.any? do |other_array, j|
        range = (other_array[0]..other_array[1])

        i != j && range.include?(array[0]) && range.include?(array[1])
      end

      result << array unless is_subset
    end

    result
  end

  def send_email(zip_folder_path)
    DeveloperMailer.notify(
      to: User.find(1).email,
      subject: "Mutashabihat exported data",
      message: "Please see the attached zip",
      file_path: zip_folder_path
    ).deliver_now
  end
end
