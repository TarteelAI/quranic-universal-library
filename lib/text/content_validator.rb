require 'ffi/hunspell'

class ContentValidator
  attr_reader :translation_id, :ayahs, :issues

  def initialize(translation_id)
    @translation_id = translation_id
    @issues = []
  end

  def generate_report
    fetch_translations.each do |ayah|
      process_text(ayah)
    end
    
    generate_html
  end

  private

  def fetch_translations(translation_id)
    Translation.where(resource_content_id: translation_id).order('verse_id ASC')
  end

  # Process each ayah text for issues
  def process_text(ayah)
    text = ayah.text
    ayah_issues = []

    # Check for formatting issues
    text.gsub!(/(\w)([.,!?])(\w)/) do
      ayah_issues << "Missing space after punctuation near: '#{$~[0]}'"
      "#{$1}#{$2} <span class='highlight'>[missing space]</span> #{$3}"
    end
    text.gsub!(/\s{2,}/) do
      ayah_issues << "Extra spaces found."
      " <span class='highlight'>[extra space]</span> "
    end
    text.gsub!(/(\s+)\./) do
      ayah_issues << "Space before full stop found."
      "<span class='highlight'>[space before full stop]</span>."
    end

    hunspell = Hunspell.new('/usr/share/hunspell/en_US.aff', '/usr/share/hunspell/en_US.dic')
    text.split.each do |word|
      clean_word = word.gsub(/[.,!?]/, '') # Remove punctuation for spell check
      next if hunspell.spell?(clean_word)

      ayah_issues << "Spelling mistake: '#{clean_word}'"
      text.gsub!(word, "<span class='highlight'>#{word}</span>")
    end

    # Record issues for the ayah if any
    unless ayah_issues.empty?
      issues << { ayah_id: ayah[:id], issues: ayah_issues, highlighted_text: text }
    end
  end

  # Generate HTML report
  def generate_html
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
          }
          th, td {
            border: 1px solid #ddd;
            padding: 8px;
          }
          th {
            background-color: #f2f2f2;
            cursor: pointer;
          }
          .highlight {
            background-color: yellow;
            font-weight: bold;
          }
        </style>
        <script>
          // Simple search and sort functionality
          function searchTable() {
            const input = document.getElementById('searchInput');
            const filter = input.value.toLowerCase();
            const rows = document.querySelectorAll('#ayahTable tbody tr');
            rows.forEach(row => {
              row.style.display = row.textContent.toLowerCase().includes(filter) ? '' : 'none';
            });
          }
          
          function sortTable(columnIndex) {
            const table = document.getElementById('ayahTable');
            const rows = Array.from(table.rows).slice(1);
            const sortedRows = rows.sort((a, b) => {
              const aText = a.cells[columnIndex].textContent.trim();
              const bText = b.cells[columnIndex].textContent.trim();
              return aText.localeCompare(bText, undefined, { numeric: true });
            });
            const tbody = table.tBodies[0];
            sortedRows.forEach(row => tbody.appendChild(row));
          }
        </script>
      </head>
      <body>
        <h1>Content Validation Report</h1>
        <input type="text" id="searchInput" onkeyup="searchTable()" placeholder="Search for ayahs...">
        <table id="ayahTable">
          <thead>
            <tr>
              <th onclick="sortTable(0)">Ayah ID</th>
              <th onclick="sortTable(1)">Issues</th>
              <th>Highlighted Text</th>
            </tr>
          </thead>
          <tbody>
            #{issues.map { |issue| generate_table_row(issue) }.join("\n")}
          </tbody>
        </table>
      </body>
      </html>
    HTML
  end

  # Generate HTML table row for each issue
  def generate_table_row(issue)
    <<~HTML
      <tr>
        <td>#{issue[:ayah_id]}</td>
        <td>#{issue[:issues].join('<br>')}</td>
        <td>#{issue[:highlighted_text]}</td>
      </tr>
    HTML
  end
end
