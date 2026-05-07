namespace :quran_scripts do
  desc "Compare two Quran scripts and export diffs as HTML"
  task :compare do
    require "diffy"
    first_script_path = "data/scripts/sign/words/all.txt"
    second_script_path = "data/scripts/misbah/words/all.txt"
    output_path = "tmp/words_script_diff.html"
    diff_name = "Words comparison"

    def sanitize_text(text)
      text
        .sub(/^\d+:\d+(?:\t| {2,})/, '')
        .gsub(/ {2,}/, ' ')
        .strip
    end

    first_script_lines = File.readlines(first_script_path, encoding: "UTF-8").map { |l| sanitize_text l.strip }
    second_script_lines = File.readlines(second_script_path, encoding: "UTF-8").map { |l| sanitize_text l.strip }

    max_lines = [first_script_lines.size, second_script_lines.size].max
    diff_rows = []
    diff_count = 0

    max_lines.times do |i|
      first_word = first_script_lines[i]
      second_word = second_script_lines[i]

      if first_word == second_word
        puts "Line #{i + 1}:  #{first_word} No difference"
        next
      end

      diff_count += 1
      diff_html = Diffy::Diff.new(
        first_word,
        second_word,
        include_plus_and_minus_in_html: false
      ).to_s(:html).html_safe

      diff_rows << <<~ROW
        <tr>
          <td class="line-num">#{i + 1}</td>
          <td class="word-cell">#{first_word}</td>
          <td class="word-cell">#{second_word}</td>
          <td class="diff-cell">#{diff_html}</td>
          <td class="word-cell">#{first_word.chars - second_word.chars}</td>
          <td class="word-cell">#{second_word.chars - first_word.chars}</td>
        </tr>
      ROW
    end

    line_count_note = if first_script_lines.size != second_script_lines.size
                        "<p class='warning'>Line count mismatch — First script: #{first_script_lines.size}, Second script: #{second_script_lines.size}</p>"
                      else
                        ""
                      end

    html = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>#{diff_name}</title>
        <style>
          body {
            font-family: sans-serif;
            direction: rtl;
            background: #f9f9f9;
            padding: 2rem;
          }
          h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
          .meta { color: #555; font-size: 0.9rem; margin-bottom: 1rem; }
          .warning { color: #c00; font-weight: bold; }
          table {
            border-collapse: collapse;
            width: 100%;
            background: #fff;
            box-shadow: 0 1px 3px rgba(0,0,0,.1);
            border-radius: 6px;
            overflow: hidden;
          }
          th {
            background: #2c2c2c;
            color: #fff;
            padding: 0.6rem 1rem;
            text-align: right;
            font-size: 0.85rem;
          }
          td { padding: 0.4rem 1rem; vertical-align: top; }
          td.line-num {
            color: #999;
            font-size: 0.8rem;
            white-space: nowrap;
            width: 4rem;
            text-align: center;
            border-right: 1px solid #eee;
          }
          td.word-cell {
            font-size: 1.3rem;
            font-family: 'Scheherazade New', serif;
            white-space: nowrap;
            border-right: 1px solid #eee;
          }
          td.diff-cell { font-size: 1.1rem; font-family: 'Scheherazade New', serif; }
          tr:nth-child(even) { background: #fafafa; }

          /* Diffy styles */
          .diff { margin: 0; }
          .diff ins { background: #d4f7d4; text-decoration: none; display: inline; }
          .diff del { background: #ffd4d4; text-decoration: line-through; display: inline; }
          .diff li { list-style: none; padding: 2px 4px; }
          .diff li.ins { background: #eaffea; }
          .diff li.del { background: #ffecec; }
        </style>
      </head>
      <body>
        <h1>Script Diff</h1>
        <p class="meta">
          Total differing lines: <strong>#{diff_count}</strong> /
          First script lines: #{first_script_lines.size} &nbsp;|&nbsp; Second script lines: #{second_script_lines.size}
        </p>
        #{line_count_note}
        <table>
          <thead>
            <tr>
              <th style="width:4rem">Line</th>
              <th>First</th>
              <th>Second</th>
              <th>Diff</th>
              <th>Extra 1</th>
              <th>Extra 2</th>
            </tr>
          </thead>
          <tbody>
            #{diff_rows.join("\n")}
          </tbody>
        </table>
      </body>
      </html>
    HTML

    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, html, encoding: "UTF-8")

    puts "Exported #{diff_count} diffs to #{output_path}"
  end

  task import_words: :environment do
    def sanitize_text(text)
      text.sub(/^\d+:\d+\t/, '').strip
    end
    data_path = "data/scripts/sign/words/all.txt"
    words_data = File.readlines(data_path, encoding: "UTF-8").map do |w|
      sanitize_text(w)
    end

    Word.unscoped.order(:word_index).find_in_batches(batch_size: 1000) do |batch|
      batch.each do |word|
        word.update_column(:text_sign_language, words_data[word.word_index - 1])
        print "."
      end
    end
  end

  task import_ayah: :environment do
    def sanitize_text(text)
      text.sub(/^\d+:\d+\t/, '').strip
    end
    data_path = "data/scripts/sign/ayah/all.txt"
    ayah_data = File.readlines(data_path, encoding: "UTF-8").map do |w|
      sanitize_text(w)
    end

    Verse.unscoped.order(:verse_index).find_in_batches(batch_size: 1000) do |batch|
      batch.each do |ayah|
        ayah.update_column(:text_sign_language, ayah_data[ayah.verse_index - 1])
        print "."
      end
    end
  end
end
