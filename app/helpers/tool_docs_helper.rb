module ToolDocsHelper
  def available_tool_keys
    [
      'mushaf_layout',
      'arabic_transliteration',
      'ayah_recitation',
      'ayah_tafsir',
      'ayah_translation',
      'ayah_transliteration',
      'char',
      'corpus',
      'mutashabihat',
      'quran_script',
      'quran_scripts_comparison',
      'surah_info',
      'surah_recitation',
      'surah_recitation_segment_builder',
      'tajweed',
      'word_translation',
      'word_transliteration',
      'compare_ayah',
      'ayah_dependency_graph',
      'ayah_boundaries',
      'compare_audio'
    ] + internal_tools_keys
  end

  def internal_tools_keys
    if qul_scripts_available?
      [
        'audio_repair_index',
        'audio_repair_editor',
        'audio_repair_polarity',
        'audio_repair_ingest'
      ]
    else
      []
    end
  end

  def mutashabihat_help
    [
      "Mutashabihat ul Quran Tool",
      {
        text: "Mutashabihat are phrases of 3 or more words that appear in more than one ayah (or a whole 2-word ayah, like <span class='qpc-hafs'>الرَّحْمَٰنِ الرَّحِيمِ</span>). Sometimes word for word, often with a small difference that is easy to mix up while memorizing. This tool finds them and lets you review and save them."
      },
      {
        type: 'info',
        text: "The tool suggests phrases, but nothing is saved or exported until a reviewer approves it. Only approved ayahs of reviewed phrases go into the downloadable data."
      },
      {
        type: 'heading',
        text: 'How phrases and ayahs fit together'
      },
      {
        type: 'info',
        text: mutashabihat_diagrams
      },
      {
        type: 'heading',
        text: 'Two ways to work'
      },
      {
        type: 'info',
        text: <<~HTML
          <ul class="list-disc ps-5 space-y-1">
            <li><strong>Phrase view</strong> (the default list) shows saved phrases, one row per phrase. Use it to find a phrase by text and open it in the builder.</li>
            <li><strong>Proofreading view</strong> (<code>Proofread view</code> button) shows ayahs, one row per ayah, with how many phrases each has and whether they still need review. Use it to go through the Quran ayah by ayah.</li>
          </ul>
        HTML
      },
      {
        type: 'heading',
        text: 'Create a new phrase'
      },
      {
        type: 'step',
        title: 'Step 1: Start from an ayah or from text',
        text: "Click <code>New Phrase</code>. Pick an ayah, or type a few words of the phrase in Arabic (diacritics are optional), and click <code>Find similar phrases</code>. You can also start from an ayah page in the proofreading view: click <code>Review</code> on an auto-detected phrase."
      },
      {
        type: 'step',
        title: 'Step 2: Pick the source phrase',
        text: "The builder shows the source ayah at the top. Click the first and then the last word of the phrase, and the tool searches again for ayahs sharing those words. Scrolling down, the source shrinks to a bar with only the selected words."
      },
      {
        type: 'step',
        title: 'Step 3: Select the words in each ayah',
        text: "Every ayah sharing the phrase is listed with the matching words already selected, and differing words underlined by kind (see below). Click the first and last word to change a range. If the phrase repeats in one ayah, select another range the same way. Click a word inside a range to leave it out. When the saved words differ from what the tool found, <code>Use suggested</code> switches to the found words."
      },
      {
        type: 'step',
        title: 'Step 4: Approve',
        text: "Click <code>Approve</code> on each ayah that really shares the phrase. Approving saves the phrase (the first time) and the ayah with the words you selected. Use the filter buttons (<code>All</code>, <code>Saved</code>, <code>Exact</code>, <code>Similar</code>) to focus on the ayahs you haven't handled. To add an ayah that wasn't found, pick it under <i>Add an ayah manually</i>."
      },
      {
        type: 'heading',
        text: 'Approve, disapprove or remove an ayah'
      },
      {
        type: 'info',
        text: <<~HTML
          <ul class="list-disc ps-5 space-y-1">
            <li><strong>Approve</strong> (<i class="fas fa-check"></i>): the ayah shares the phrase. It is marked reviewed and goes into exports.</li>
            <li><strong>Not approved</strong> (<i class="fas fa-times"></i>): keep the ayah on the phrase, but leave it out of exports. Use it when you're unsure, or the match is too loose.</li>
            <li><strong>Remove</strong> (<i class="fas fa-trash-alt"></i>): the ayah doesn't belong to the phrase. It disappears from the lists and won't be suggested again, also when data is imported again.</li>
          </ul>
          <p class="mt-2">In the builder these buttons are on each ayah card. On an ayah page in the proofreading view, click the ayah count of a phrase (<i>"5 ayahs share this phrase"</i>) to list its ayahs with the same buttons.</p>
        HTML
      },
      {
        type: 'heading',
        text: 'Proofreading mode'
      },
      {
        type: 'step',
        title: 'Step 1: Find ayahs to review',
        text: "In the proofreading view, filter by surah, ayah or <code>Phrase status</code> (<i>Needs review</i> is the to-do list). Sort by any column: phrases, linked ayahs (other ayahs sharing a phrase), words covered, or status. Click <code>Show</code> to open an ayah."
      },
      {
        type: 'step',
        title: 'Step 2: Read the ayah page',
        text: "The ayah text is coloured by its saved phrases: each phrase has a number and a colour, and a word in more than one phrase gets one underline per phrase (up to 3; <b>+N</b> under a word means it is in N more). The legend under the ayah lists the phrases by number and word range. Hover a phrase card to highlight its words, or a word to highlight its phrases. Each card shows where the phrase is in this ayah, the source ayah it was built from, and its status."
      },
      {
        type: 'step',
        title: 'Step 3: Review the ayahs of each phrase',
        text: "Click the ayah count on a phrase card to list every ayah sharing it, then approve, disapprove or remove each one. <code>Open in builder</code> opens the phrase to change words or add ayahs."
      },
      {
        type: 'step',
        title: 'Step 4: Check for missing phrases',
        text: "Below the saved phrases, <i>Auto-detected shared phrases</i> lists what the tool found in the ayah that isn't saved yet. Phrases already saved with all their ayahs are hidden. A saved phrase missing some ayahs is shown with only the missing ones. Click <code>Review</code> to build a new phrase, or <code>Open phrase</code> to add the missing ayahs. Use <code>Previous ayah</code> and <code>Next ayah</code> to move on."
      },
      {
        type: 'heading',
        text: 'Statuses'
      },
      {
        type: 'info',
        text: <<~HTML
          <ul class="list-disc ps-5 space-y-1">
            <li><strong>Reviewed</strong>: saved or checked by a reviewer.</li>
            <li><strong>Auto-detected</strong>: found automatically, or imported, and nobody has checked it yet.</li>
            <li><strong>Imported</strong>: imported from another Mutashabihat dataset. Review it like any auto-detected phrase.</li>
            <li><strong>Needs review</strong> (ayah list): the ayah has auto-detected phrases, or ayahs nobody has checked yet.</li>
          </ul>
        HTML
      },
      {
        type: 'heading',
        text: 'Kinds of difference'
      },
      {
        type: 'info',
        text: <<~HTML
          <ul class="list-disc ps-5 space-y-1">
            <li><strong>Exact</strong>, word for word: <span class="qpc-hafs">رِجْزًا مِّنَ السَّمَاءِ</span> in 2:59 and 29:34.</li>
            <li><strong>Prefix/suffix</strong>, the same word with و or ف, or a pronoun ending: <span class="qpc-hafs">فَكُلُوا</span> in 2:58, <span class="qpc-hafs">وَكُلُوا</span> in 7:161.</li>
            <li><strong>Word form</strong>, the same word conjugated differently: <span class="qpc-hafs">عَمَّا تَعْمَلُونَ</span> in 2:74, <span class="qpc-hafs">عَمَّا يَعْمَلُونَ</span> in 2:144.</li>
            <li><strong>Sounds similar</strong>, words of the same shape: <span class="qpc-hafs">فَأَنزَلْنَا</span> in 2:59, <span class="qpc-hafs">فَأَرْسَلْنَا</span> in 7:162.</li>
            <li><strong>Word changed</strong>: <span class="qpc-hafs">يُذَبِّحُونَ</span> in 2:49, <span class="qpc-hafs">يُقَتِّلُونَ</span> in 7:141.</li>
            <li><strong>Order changed</strong>: <span class="qpc-hafs">لَعِبٌ وَلَهْوٌ</span> in 6:32, <span class="qpc-hafs">لَهْوٌ وَلَعِبٌ</span> in 29:64.</li>
            <li><strong>Word added or missing</strong>: <span class="qpc-hafs">إِنَّا كَذَٰلِكَ نَجْزِي الْمُحْسِنِينَ</span> in 37:80, without <span class="qpc-hafs">إِنَّا</span> in 37:110.</li>
          </ul>
        HTML
      }
    ]
  end

  # Pictures for the Mutashabihat help: how a source ayah, a phrase and the
  # ayahs sharing it relate, and what the ayah page shows
  def mutashabihat_diagrams
    words = lambda do |x, y, count, highlight, color|
      (0...count).map do |i|
        fill = highlight.include?(i) ? color : '#e5e7eb'
        "<rect x='#{x + i * 18}' y='#{y}' width='14' height='8' rx='2' fill='#{fill}'/>"
      end.join
    end

    ayah = lambda do |x, y, label, count, highlight, color, note: nil, note_color: '#15803d'|
      <<~SVG
        <rect x='#{x}' y='#{y}' width='190' height='44' rx='6' fill='#fff' stroke='#cbd5e1'/>
        <text x='#{x + 10}' y='#{y + 17}' font-size='12' font-weight='600' fill='#0f172a'>#{label}</text>
        #{note ? "<text x='#{x + 180}' y='#{y + 17}' font-size='11' text-anchor='end' fill='#{note_color}'>#{note}</text>" : ''}
        #{words.call(x + 10, y + 26, count, highlight, color)}
      SVG
    end

    arrow = ->(x1, y1, x2, y2) { "<line x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}' stroke='#64748b' stroke-width='1.5' marker-end='url(#mt-arrow)'/>" }
    marker = "<defs><marker id='mt-arrow' viewBox='0 0 10 10' refX='9' refY='5' markerWidth='7' markerHeight='7' orient='auto-start-reverse'><path d='M0,0 L10,5 L0,10 z' fill='#64748b'/></marker></defs>"
    blue = '#0498CC'
    orange = '#D47A27'

    one_phrase = <<~SVG
      <svg viewBox='0 0 660 210' width='100%' role='img' aria-label='A phrase is built from words of a source ayah and found in other ayahs' style='font-family: inherit'>
        #{marker}
        #{ayah.call(10, 83, 'Source ayah 2:59', 9, [5, 6, 7], blue)}
        <text x='105' y='145' font-size='11' text-anchor='middle' fill='#475569'>you pick the words</text>
        #{arrow.call(202, 105, 252, 105)}
        <rect x='256' y='78' width='160' height='54' rx='27' fill='#ecfeff' stroke='#{blue}' stroke-width='1.5'/>
        <text x='336' y='100' font-size='12' font-weight='600' text-anchor='middle' fill='#0f172a'>Phrase #16552</text>
        <text x='336' y='120' font-size='14' text-anchor='middle' fill='#{blue}'>رِجْزًا مِّنَ السَّمَاءِ</text>
        #{arrow.call(418, 98, 456, 36)}
        #{arrow.call(418, 105, 456, 105)}
        #{arrow.call(418, 112, 456, 174)}
        #{ayah.call(460, 12, '2:59 (the source)', 9, [5, 6, 7], blue, note: '✓ approved')}
        #{ayah.call(460, 83, '7:162', 10, [6, 7, 8], blue, note: '✓ approved')}
        #{ayah.call(460, 154, '29:34', 9, [4, 5, 6], blue, note: 'not approved', note_color: '#b91c1c')}
        <text x='550' y='206' font-size='11' text-anchor='middle' fill='#475569'>the ayahs of the phrase</text>
      </svg>
    SVG

    one_ayah = <<~SVG
      <svg viewBox='0 0 660 250' width='100%' role='img' aria-label='An ayah can contain several phrases, each with its own ayahs' style='font-family: inherit'>
        #{marker}
        <rect x='180' y='8' width='300' height='50' rx='6' fill='#fff' stroke='#0f172a' stroke-width='1.5'/>
        <text x='192' y='27' font-size='12' font-weight='600' fill='#0f172a'>Ayah page: 6:73</text>
        <text x='468' y='27' font-size='11' text-anchor='end' fill='#475569'>2 shared phrases</text>
        #{words.call(192, 38, 15, [0, 1, 2, 3, 4], blue)}
        #{words.call(192 + 12 * 18, 38, 3, [0, 1, 2], orange)}
        #{arrow.call(260, 60, 175, 98)}
        #{arrow.call(420, 60, 495, 98)}
        <rect x='20' y='100' width='290' height='56' rx='8' fill='#ecfeff' stroke='#{blue}'/>
        <circle cx='40' cy='120' r='10' fill='#{blue}'/><text x='40' y='124' font-size='11' font-weight='700' text-anchor='middle' fill='#fff'>1</text>
        <text x='58' y='124' font-size='12' font-weight='600' fill='#0f172a'>Words 1–5, source 11:7</text>
        <text x='165' y='146' font-size='13' text-anchor='middle' fill='#{blue}'>وَهُوَ الَّذِي خَلَقَ السَّمَاوَاتِ وَالْأَرْضَ</text>
        <rect x='350' y='100' width='290' height='56' rx='8' fill='#fff7ed' stroke='#{orange}'/>
        <circle cx='370' cy='120' r='10' fill='#{orange}'/><text x='370' y='124' font-size='11' font-weight='700' text-anchor='middle' fill='#fff'>2</text>
        <text x='388' y='124' font-size='12' font-weight='600' fill='#0f172a'>Words 19–21, source 13:9</text>
        <text x='495' y='146' font-size='13' text-anchor='middle' fill='#{orange}'>عَالِمُ الْغَيْبِ وَالشَّهَادَةِ</text>
        <text x='165' y='178' font-size='11' text-anchor='middle' fill='#475569'>click "3 ayahs" to list them</text>
        #{%w[6:73 11:7 57:4].each_with_index.map { |k, i| "<rect x='#{60 + i * 72}' y='188' width='62' height='22' rx='11' fill='#fff' stroke='#{blue}'/><text x='#{91 + i * 72}' y='203' font-size='11' text-anchor='middle' fill='#0f172a'>#{k}</text>" }.join}
        <text x='495' y='178' font-size='11' text-anchor='middle' fill='#475569'>click "10 ayahs" to list them</text>
        #{%w[6:73 13:9 23:92 +7].each_with_index.map { |k, i| "<rect x='#{366 + i * 66}' y='188' width='58' height='22' rx='11' fill='#fff' stroke='#{orange}'/><text x='#{395 + i * 66}' y='203' font-size='11' text-anchor='middle' fill='#0f172a'>#{k}</text>" }.join}
        <text x='330' y='240' font-size='11' text-anchor='middle' fill='#475569'>Linked ayahs of 6:73 = every ayah in these lists except 6:73 itself (11 here)</text>
      </svg>
    SVG

    <<~HTML
      <div class="bg-white rounded border border-gray-200 p-3 space-y-4 text-sm">
        <div>
          <p class="font-semibold">One phrase</p>
          <p class="text-gray-600">A phrase is built from words picked in one ayah, its <strong>source ayah</strong>. It is then found in other ayahs, each with its own range of words. The source is one of the phrase's ayahs too. Each ayah is approved on its own.</p>
          #{one_phrase}
        </div>
        <div>
          <p class="font-semibold">One ayah</p>
          <p class="text-gray-600">An ayah can contain several phrases, and each phrase has its own source and its own ayahs. The ayah page shows the phrases of one ayah. Click a phrase's ayah count to see its ayahs, and approve or remove them there.</p>
          #{one_ayah}
        </div>
        <ul class="list-disc ps-5 text-gray-700">
          <li><strong>Source ayah</strong>: where the phrase was built from. Changing the source words changes the phrase.</li>
          <li><strong>Ayahs of a phrase</strong>: every place the phrase occurs, the source included.</li>
          <li><strong>Linked ayahs</strong> (ayah list): all other ayahs that share at least one phrase with the ayah.</li>
        </ul>
      </div>
    HTML
  end

  def doc_image_tag(path)
    # NOTE: update version number when images are updated
    url = "#{ENV['CDN_HOST']}/qul/help-screenshots/#{path}?v=2"
    "<img data-src='#{url}' class='img-fluid' data-controller='lazy-load' />".html_safe
  end

  def compare_ayah_help
    [
      "Compare Ayah tool",
      {
        text: "This tool is designed to view and compare multiple Ayahs. Follow these steps to use the tool effectively:"
      },
      {
        type: 'step',
        title: 'Step 1: Select ayahs to compare',
        text: 'Enter comma-separated Ayah keys (e.g., <code>1:1, 27:30</code> will show the 1st Ayah of Surah Al-Fatiha and the 30th Ayah of Surah An-Naml) in the "Select Ayah" field.',
      },
      {
        type: 'step',
        title: 'Step 2: Select translation(optional)',
        text: "If you want to compare translations too, select the desired translation from the dropdown.",
      },
      {
        type: 'step',
        title: 'Step 3: View the Ayahs',
        text: "Click the <code>Show Ayahs</code> button to view the selected Ayahs. The tool will display the Ayahs in the same order that you've selected. Tool will also highight the common words between the Ayahs.",
      }
    ]
  end

  def word_translation_help
    [
      "Word by Word Translations",
      {
        text: "This tool is designed to proofread and correct word-by-word translations. Please follow these steps to make adjustments to any translation"
      },
      {
        type: 'step',
        title: 'Step 1: Select a translation resource',
        text: "A language can have more than one word-by-word translation, so start by picking the resource you want to work on from the <code>Select resource</code> page. Each resource is maintained separately.",
        screenshot: 'word_translations.png'
      },
      {
        type: 'step',
        title: 'Step 2: Find an ayah',
        text: "Once a resource is selected, use the <code>Surah</code> and <code>Ayah</code> filters to narrow down the results. Click <code>Show</code> to display the selected Ayah, where a list of words and their corresponding translations will appear.",
        screenshot: 'word_translations.png'
      },
      {
        type: 'step',
        title: 'Step 3: Read the translation',
        text: "Review the translation of each word carefully. Words without a translation are highlighted so you can spot gaps at a glance. If an update is needed, click the <code>Edit</code> button to fix the translation.",
        screenshot: 'ayah-words-translation.png'
      },
      {
        type: 'step',
        title: 'Step 4: Update the translation',
        text: "The page will display the Ayah along with a list of all its words. Each word is shown as its own card with an input field, its current translation, and the English translation for reference. Once you're satisfied with the update, click <code>Save translations</code> to save the changes.",
        screenshot: 'update-word-translation.png'
      },
      {
        type: 'info',
        text: "Some phrases convey better meanings when translated as a whole. <br/>For example, <span class='qpc-hafs'>مِنۢ بَيۡنِ أَيۡدِيهِمۡ</span> means <strong>before them</strong>. A literal, word-by-word translation would be <strong>from</strong>, <strong>between</strong>, <strong>their hands</strong>, which may not convey the intended meaning clearly. In such cases, we can provide group translations for better understanding.",
      },
      {
        type: 'step',
        title: 'Step 4.1: Update the group translation',
        sections: [
          {
            text: "If you find a group of words that should be translated together, you can group them. To do this, click the <code>Create group</code> button (or <code>Edit group</code> if you need to change an existing group) to open the group translation modal.",
            screenshot: 'create-group.png'
          },
          {
            text: "Select the word range and primary word of the range that'll have the translation. Click on <code>Save group translation</code> to save the changes.",
            screenshot: 'save-group-translation.png'
          }
        ]
      },
      {
        type: 'step',
        title: 'Review change log and rollback',
        text: "You can view the change log from the admin panel. To roll back any changes, please contact the admin",
        screenshot: 'word-translation-change-log.png'
      }
    ]
  end

  def ayah_translation_help
    [
      "Ayah Translation",
      {
        text: "This tool is used to proofread and fix ayah translations. Please follow these steps to suggest fix for any translation:"
      },

      {
        type: 'step',
        title: 'Step 1: Find the translation of an ayah',
        text: "User filters to find the translation you're looking for, use <code>Surah</code> and <code>Ayah</code> dropdown to find translation for specific ayah. Click <code>Show</code> to open translation page.",
        screenshot: 'select-translation.png'
      },
      {
        type: 'step',
        title: 'Step 2: Read translation',
        text: 'This page will show the ayah translation and footnotes(if any). Read the translation, if you find any issues, click the <code>Edit</code> button to fix the translation.',
        screenshot: 'ayah-translation-detail.png'
      },
      {
        type: 'step',
        title: 'Step 3: Update the translation',
        text: 'Update the translation and footnote text(if any). Click on the <code>Purpose changes</code> button to submit your changes for approval. Once approved, your changes will be reflected in the live translation.',
        screenshot: 'update-ayah-translation.png'
      }
    ]
  end

  def ayah_transliteration_help
    [
      "Ayah Transliteration",
      {
        text: "This tool is used to proofread and fix ayah transliterations. Please follow these steps to suggest a fix for any transliteration:"
      },
      {
        type: 'step',
        title: 'Step 1: Find the transliteration of an ayah',
        text: "Select the transliteration, then use the <code>Surah</code> and <code>Ayah</code> dropdowns to find a specific ayah. Click <code>Show</code> to open the transliteration page."
      },
      {
        type: 'step',
        title: 'Step 2: Read the transliteration',
        text: 'This page shows the ayah and its transliteration. If you find any issues, click the <code>Edit</code> button to fix the transliteration.'
      },
      {
        type: 'step',
        title: 'Step 3: Update the transliteration',
        text: 'Update the transliteration and click <code>Propose changes</code> to submit your changes for approval. Keep the existing formatting tags (for example <code>&lt;u&gt;</code>, <code>&lt;b&gt;</code>, <code>&lt;i&gt;</code>) as they mark tajweed and letter details. Once approved, your changes will be reflected in the live transliteration.'
      }
    ]
  end

  def word_transliteration_help
    [
      "Word by Word Transliteration",
      {
        text: "This tool is used to proofread and fix the transliteration of each word. Please follow these steps to suggest a fix:"
      },
      {
        type: 'step',
        title: 'Step 1: Find an ayah',
        text: "Select the transliteration, then use the <code>Surah</code> and <code>Ayah</code> filters to find an ayah. Tick <code>Only ayahs with missing words</code> to list ayahs that still have words without transliteration. Click <code>Show</code> to open the ayah."
      },
      {
        type: 'step',
        title: 'Step 2: Read the transliteration',
        text: 'This page lists every word of the ayah with its transliteration. Missing ones are highlighted. If you find any issues, click the <code>Edit</code> button.'
      },
      {
        type: 'step',
        title: 'Step 3: Update the transliteration',
        text: 'Fix the words that need it and click <code>Propose changes</code>. Only the words you changed are submitted for approval. Once approved, your changes will be reflected in the live transliteration.'
      }
    ]
  end

  def ayah_tafsir_help
    [
      "Ayah Tafsir tool help",
      {
        text: "This tool is used to proofread and fix ayah tafsirs. Please follow these steps to suggest fix for any tafsir:"
      },

      {
        type: 'step',
        title: 'Step 1: Find the tafsir',
        text: "User filters to find the tafisr you're looking for, use <code>Surah</code> and <code>Ayah</code> dropdown to find tafisr for specific ayah. Click <code>Show</code> to open tafsir page.",
        screenshot: 'find-tafsir.png'
      },
      {
        type: 'step',
        title: 'Step 2: Read the tafsir',
        text: 'This page will show the ayah tafsir. If you find any issues, click the <code>Edit</code> button to suggest the fix.',
        screenshot: 'read-tafsir.png'
      },
      {
        type: 'info',
        text: "Tafsir often applies to a group of Ayahs. This tool allows you to edit Tafsir content and adjust the Ayah range it applies to."
      },
      {
        type: 'step',
        title: 'Step 3: Fix the tafsir and ayah range',
        text: "Edit Tafsir content and formatting using a rich text editor. Click <code>View</code> and then <code>Source code</code> to edit the Tafsir in HTML format. Use the 'Verse From' and 'Verse To' dropdowns to adjust the Ayah range. Click <code>Propose changes</code> to submit your edits.",
        screenshot: 'update-tafsir.png'
      },
      {
        type: 'info',
        text: "Your changes will be reviewed and, once approved, the Tafsir will be updated."
      }
    ]
  end

  def mushaf_layout_help
    [
      "Mushaf Layout Tool",

      {
        text: 'The Mushaf Layout tool is used to create digital layouts of physical Mushaf pages. This tool allows you to accurately configure page structure, word placement, and line alignment to precisely represent any printed Mushaf.',
      },

      {
        text: "The number of pages or lines per page can only be adjusted by an admin. Please contact the admin or open an issue on GitHub if you encounter any problems with the page count or line per page for any Mushaf layout.",
        type: 'info'
      },

      {
        type: 'heading',
        text: "Page Processing Workflow"
      },

      {
        text: "Each page in the Mushaf goes through a 4-step workflow: <strong>Step 1: Set Ayah Range</strong> → <strong>Step 2: Assign Line Numbers</strong> → <strong>Step 3: Fix Line Alignment</strong> → <strong>Step 4: Preview</strong>. All steps must be completed before the page can be properly displayed.",
        screenshot: 'mushaf-workflow-overview.png'
      },

      {
        type: 'info',
        text: "<strong>Tip:</strong> Most of the actions mentioned in the following steps are also available in the <code>Actions</code> dropdown menu on the page. You can use either the direct buttons or the dropdown menu to access these features.",
        screenshot: 'mushaf-actions-dropdown.png'
      },

      {
        type: 'heading',
        text: "Getting Started"
      },

      {
        type: 'step',
        title: 'Select a Mushaf Layout',
        sections: [
          {
            text: 'From the Mushaf layout index page, browse available Mushaf layouts and click the <code>Show</code> button on the one you want to work on.',
            screenshot: 'mushaf-layout-list.png'
          },
          {
            text: 'This opens the pages overview showing all pages with their current status. Each page shows its number, ayah range, and completion status. Use the search bar to find specific pages by page number or ayah reference (e.g., "20" or "2:5").',
            screenshot: 'mushaf-pages-overview.png'
          }
        ]
      },
      {
        type: 'heading',
        text: "Step 1: Set Ayah Range"
      },

      {
        type: 'step',
        title: 'Setting the First and Last Ayah',
        sections: [
          {
            text: 'This is the first required step for each page. Click the <code>Set Ayah Range</code> button or select <code>Set Ayah Range</code> from the Actions dropdown.',
          },
          {
            text: 'A modal will open showing the PDF of the Mushaf page on the left side. Enter the ayah key for the first ayah and last ayah on this page using the format <code>Surah:Ayah</code> (e.g., <code>2:255</code> for Ayat al-Kursi).',
            screenshot: 'mushaf-ayah-range-modal.png'
          },
          {
            text: 'Click <code>Save</code> to save the ayah range.',
          }
        ]
      },

      {
        type: 'heading',
        text: "Step 2: Assign Line Numbers (Word Mapping)"
      },

      {
        type: 'step',
        title: 'Opening the Word Mapping Interface',
        text: 'Once Step 1 is complete, click <code>Update Word lines</code> or select <code>Update Word lines</code> from the Actions dropdown to open the word mapping interface. The PDF of the Mushaf page will be displayed on the left, and all words from the ayah range will be listed on the right.',
        screenshot: 'mushaf-word-mapping-interface.png'
      },

      {
        type: 'step',
        title: 'Understanding Word Line Numbers Mapping',
        sections: [
          {
            text: 'Each word has a line number input field below it. The line number indicates which line of the page the word appears on. For example, if a page has 15 lines, valid line numbers are 1-15.',
          },
          {
            text: '<strong>Important:</strong> Setting a line number to <code>0</code> means that word does <strong>not appear</strong> on this page. This is useful when words from the ayah range continue on the next page.',
          }
        ]
      },

      {
        type: 'info',
        text: "The word mapping interface includes an actions bar with several helpful tools: <code>Propagate changes</code> checkbox, <code>+1</code> and <code>-1</code> buttons for bulk adjustments, and <code>Undo</code>/<code>Redo</code> buttons. Each of these features is explained in detail in the following sections."
      },

      {
        type: 'step',
        title: 'Using Auto-Propagation',
        sections: [
          {
            text: 'The <code>Propagate changes</code> checkbox (checked by default) automatically updates all following words when you change one word\'s line number. This saves significant time during word mapping.',
          },
          {
            text: '<strong>How it works:</strong> When you set a word to line 3, all words after it will also be set to line 3. When you set the first word of line 4 to line 4, all following words become line 4, and so on.',
          },
          {
            text: '<strong>Special behavior:</strong> When you set a word to <code>0</code> (not on page), it <strong>always</strong> propagates to following words, regardless of the checkbox state. This ensures words continuing on the next page are properly marked.',
          },
          {
            text: 'If you need to adjust individual words without affecting others, simply uncheck the <code>Propagate changes</code> checkbox.',
          }
        ]
      },

      {
        type: 'step',
        title: 'Bulk adjustments with +1/-1 Buttons',
        sections: [
          {
            text: 'The <code>+1</code> button increments all non-zero line numbers by 1. This is useful if you need to insert a new line at the beginning. All words on line 1 become line 2, line 2 becomes line 3, etc.',
          },
          {
            text: 'The <code>-1</code> button decrements all non-zero line numbers by 1. Useful for removing a line or adjusting the entire page down.',
          },
          {
            text: '<strong>Note:</strong> Both buttons skip words with line number <code>0</code> since those words are not on the page.',
          }
        ]
      },

      {
        type: 'step',
        title: 'Using Undo/Redo',
        sections: [
          {
            text: 'The word mapping interface includes <code>Undo</code> and <code>Redo</code> buttons that allow you to revert or reapply changes. This is extremely helpful for recovering from mistakes.',
          },
          {
            text: '<strong>Keyboard shortcuts:</strong> <ul><li><code>Ctrl+Z</code> (or <code>Cmd+Z</code> on Mac) - Undo last change</li><li><code>Ctrl+Y</code> (or <code>Cmd+Shift+Z</code> on Mac) - Redo last undone change</li></ul>',
          },
          {
            text: 'The system maintains a history of up to 50 states. The Undo button is disabled when there\'s nothing to undo, and the Redo button is disabled when there\'s nothing to redo.',
          }
        ]
      },

      {
        type: 'step',
        title: 'Typical Word Mapping Workflow',
        sections: [
          {
            text: '<ol><li>Compare the PDF on the left with the word list on the right</li><li>Set the first word of line 1 to <code>1</code> - all following words automatically become <code>1</code></li><li>Find the first word of line 2 in the PDF, set it to <code>2</code> - all following words become <code>2</code></li><li>Continue this for each line on the page</li><li>If the last few words continue on the next page, set the first continuing word to <code>0</code> - all remaining words automatically become <code>0</code></li><li>Click <code>Save</code> to save your changes</li></ol>',
          },
          {
            text: 'Using this method, you typically only need to adjust the first word of each line, making the process very efficient.',
          }
        ]
      },

      {
        type: 'heading',
        text: "Step 3: Fix Line Alignment"
      },

      {
        type: 'step',
        title: 'Setting Alignment for Each Line',
        sections: [
          {
            text: 'After completing word mapping, click <code>Fix line alignment</code> from the Actions dropdown. This opens the line alignment interface with the PDF on the left and alignment controls on the right.',
            screenshot: 'mushaf-line-alignment-interface.png'
          },
          {
            text: 'Each line has four alignment options:<ul><li><code>C</code> - Center aligned</li><li><code>J</code> - Justified (default for all lines)</li><li><code>B</code> - Bismillah (Check this if line has Bismillah)</li><li><code>N</code> - Surah Name (check this if line has surah name)</li></ul>',
          },
          {
            text: 'Compare each line in the PDF with the rendered preview. Click the appropriate button to set the alignment. Changes are automatically saved and the preview updates instantly.',
          },
          {
            text: 'Most lines use Justified (J) alignment by default, so you typically only need to mark special lines like Bismillah or Surah names.',
          }
        ]
      },

      {
        type: 'heading',
        text: "Step 4: Preview and Verify"
      },

      {
        type: 'step',
        title: 'Reviewing the Final Page',
        sections: [
          {
            text: 'Once all three steps are complete, click <code>Preview Page</code> from the Actions dropdown to view the final rendered page.',
          },
          {
            text: 'Compare the rendered page carefully with the original PDF. Check for:<ul><li>Correct line breaks - words should break at the same positions as the PDF</li><li>Proper alignment - center-aligned, Bismillah, and surah name lines should match the PDF</li><li>No missing or extra words - all words from the ayah range should appear if on this page</li></ul>',
          },
          {
            text: 'If you find any issues, use the Actions dropdown to go back to the relevant step and make corrections.',
          }
        ]
      },

      {
        type: 'step',
        title: 'Using Proofreading View',
        text: 'For detailed proofreading, select <code>Proofreading view (With PDF)</code> from Actions. This shows the PDF and rendered page side-by-side for easy comparison. This view is especially useful for catching subtle differences.',
      },

      {
        type: 'heading',
        text: "Additional Features"
      },

      {
        type: 'step',
        title: 'Comparing with Other Mushafs',
        text: 'You can compare your Mushaf layout with other Mushaf layouts using the <code>Compare with</code> option from Actions. Select another Mushaf from the dropdown to see them side-by-side. This is helpful when working on similar Mushaf styles.',
      },

      {
        type: 'step',
        title: 'Jumping to Specific Pages',
        text: 'Use the <code>Jump to page</code> option from Actions to quickly navigate to any page number or ayah reference. This is faster than using Next/Previous buttons for large jumps.',
      },

      {
        type: 'heading',
        text: "Tips and Best Practices"
      },

      {
        type: 'info',
        text: "<ul><li>Always work through pages in order (Step 1 → Step 2 → Step 3 → Step 4) for best results</li><li>Use the <code>Propagate changes</code> checkbox to speed up word mapping significantly</li><li>Remember that <code>0</code> means 'not on this page' - use it for words that continue on the next page</li><li>Use <code>Ctrl+Z</code> frequently during word mapping to quickly fix mistakes</li><li>The <code>+1</code> and <code>-1</code> buttons are helpful when you need to adjust all lines at once</li><li>Most lines use Justified alignment - focus on marking special lines (Bismillah, Surah names)</li><li>Always verify your work in the Preview step before moving to the next page</li><li>Use the search feature to quickly find specific pages or ayahs</li><li>If you encounter issues with page count or lines per page, contact an admin</li></ul>"
      },

      {
        type: 'heading',
        text: "Common Issues and Solutions"
      },

      {
        type: 'step',
        title: 'Words Breaking at Wrong Positions',
        text: 'This usually means the line numbers are incorrect in Step 2. Go back to word mapping and verify that each word is assigned to the correct line by comparing with the PDF.',
      },

      {
        type: 'step',
        title: 'Missing Words in Preview',
        text: 'Check that all words are assigned a non-zero line number. Words with line number <code>0</code> are excluded from the page. Only use <code>0</code> for words that truly don\'t appear on this page.',
      },

      {
        type: 'step',
        title: 'Alignment Looks Wrong',
        text: 'Verify the alignment settings in Step 3. Make sure Bismillah lines are marked with <code>B</code> and Surah names with <code>N</code>. Most other lines should use <code>J</code> (Justified).',
      },

      {
        type: 'step',
        title: 'Page Not Showing Preview',
        text: 'Make sure all three steps are completed. The preview requires: (1) Ayah range set, (2) All words mapped to line numbers, (3) Line alignments configured. The missing data screen will show which steps are incomplete.',
      },

      {
        type: 'demo',
        title: "Video Tutorial",
        text: "Watch a complete walkthrough of the Mushaf Layout workflow from start to finish.",
        screenshot: 'mushaf-layout-video-tutorial.png'
      }
    ]
  end

  def tajweed_help
    [
      "Tajweed annotations tool",
      {
        text: "This tool is designed to fix the tajweed annotations for each word in the Ayah."
      },
      {
        type: 'info',
        text: "We provide two variations of the Tajweed-annotated script: one based on the Recite Quran project and the other on the Dar Al Maarifah <a href='https://easyquran.com/en/' target='_blank'>Tajweed Mushaf</a>. This tool enables you to switch between the two Tajweed schemes, compare them, and correct any missing or incorrect Tajweed rules."
      },
      {
        type: 'step',
        title: 'Step 1: Find the word and select tajweed script type',
        text: "Use the filters to find the words, you can filter by <code>Surah</code> and <code>Ayah</code> or use text search to find the words. You can also filter the words that have a specific tajweed rule using <code>Filter by tajweed rule</code> dropdown. Table below will show the words of filtered ayahs with tajweed annotations. Click on <code>Show</code> button to open the word.",
        screenshot: 'tajweed-filter.png'
      },
      {
        type: 'step',
        title: 'Step 2: Review and fix the tajweed annotations',
        sections: [
          {
            text: "The first section on Tajweed word page will show the available tajweed script, both text and images. You can use this to compare tajweed scripts while fixing the missing rules",
            screenshot: "tajweed-word-detail.png"
          },
          {
            text: "The next section show the preview of the word and list of letters with associated tajweed rule. You can change the tajweed rule for each letter using the dropdown. Click <code>Save</code> to save the changes. This will automatically update the word preview.",
            screenshot: "tajweed-letters.png"
          },
          {
            text: "Click on <code>Tajweed Page</code> button to view the Tajweed mushaf page for the selected word. You can use this to compare the tajweed rules with the actual Mushaf page.",
            screenshot: 'tajweed-pages.png'
          },
          {
            text: "Click the <code>Tajweed Palette</code> button to open the Tajweed Rule Palette. This will display a list of all Tajweed rules, including the rule name, associated letters, and the assigned color for each rule. Use this if you're unsure about the tajweed rule for a specific letter.",
            screenshot: "tajweed-palette.png"
          },
          {
            text: "Click the <code>View Detail</code> button to see a detailed explanation of the Tajweed rule. This includes sample words for the selected rule and links to additional resources for further reading.",
            screenshot: "rule-docs.png"
          }
        ],
        screenshot: 'tajweed-word.png'
      },
      {
        type: 'step',
        title: 'Preview full ayah',
        text: "The last section on the page will show the full ayah with tajweed colors. You can click on any word to quickly jump between all words of current ayah.",
        screenshot: 'tajweed-ayah.png'
      }
    ]
  end

  def quran_script_help
    [
      'Quran script and fonts tool',
      {
        text: "This tool allows you to check the compatibility of different Quranic scripts (e.g., Madani, IndoPak, etc.) with various fonts. Here's how to use the tool effectively:"
      },
      {
        type: 'step',
        title: 'Step 1: Find the ayah you want to check',
        text: "Use the filters to find the ayah you're looking for. Click on <code>Show</code> button to open the ayah.",
        screenshot: 'quran-script-filters.png'
      },
      {
        type: 'step',
        title: 'Step 2: Proofread and compare all scripts',
        text: "The ayah page will show all available script of selected ayah, scroll down to see word by word script. <a href='https://github.com/TarteelAI/quranic-universal-library/issues/new/choose'>Open an issue</a> on GitHub if you find any issues with the script or font.",
        screenshot: 'ayah-scripts.png'
      },
      {
        type: 'step',
        title: "Navigate to other ayahs",
        text: "Use <code>Next</code> or <code>Previous</code> button to navigate to other ayahs.",
      }
    ]
  end

  def surah_info_help
    [
      "Surah info tool",
      {
        text: "This tool is used to proofread and fix Surah information in different languages. Please follow these steps to suggest a fix:"
      },
      {
        type: 'step',
        title: 'Step 1: Find the Surah information',
        text: "Use the filters to find the Surah information you're looking for. Click on <code>Show</code> button to open the Surah information page.",
        screenshot: 'find-surah-info.png'
      },
      {
        type: 'step',
        title: 'Step 2: Read the Surah information',
        text: "This page will show the Surah information of selected Surah. If you find any issues, click the <code>Edit</code> button to suggest the fix. Use <code>Previous</code> and <code>Next</code> buttons to navigate between Surahs.",
        screenshot: 'read-surah-info.png'
      },
      {
        type: 'info',
        text: "Each Surah has both a short and a long surah info. The short version is often used in the Surah list or for SEO (e.g., meta description tags), while the long version provides detailed Surah information and can contain HTML for formatting."
      },
      {
        type: 'step',
        title: 'Step 3: Fix the Surah information',
        text: "Edit the Surah information and formatting using a rich text editor. Click <code>View</code> and then <code>Source code</code> to edit the Surah information in HTML format. Click <code>Save surah info</code> to submit your changes.",
        screenshot: 'update-surah-info.png'
      }
    ]
  end

  def char_help
    [
      "Text and Font Compatibility Checker",
      {
        text: "This tool helps you analyze Unicode values of Quranic text characters and preview how the text renders across all available fonts to ensure compatibility and identify rendering issues."
      },
      {
        type: 'step',
        title: 'Enter the text',
        text: 'Enter any text in the input field. You can use this tool for two purposes: analyzing Unicode values or previewing the results for all Quranic fonts for given text.',
      },
      {
        type: 'step',
        title: 'Analyze Unicode (Character Analysis)',
        text: 'To analyze the Unicode values, optionally select a script from the dropdown (e.g., QPC Hafs, Uthmani, Indopak) and click the <code>Analyze Unicode</code> button. The tool will display a detailed table showing:<ul><li>Unicode name for each character</li><li>The character itself (clickable to copy)</li><li>Occurrence count in the text</li><li>Decimal Unicode value</li><li>HTML entity representation</li><li>Decomposition information (if applicable)</li><li>Hexadecimal Unicode value with link to detailed Unicode info</li></ul>',
        screenshot: 'char-info.png'
      },
      {
        type: 'step',
        title: 'Preview in All Fonts',
        text: 'To check font compatibility, click the <code>Preview in All Fonts</code> button. This will display your text rendered in all available Quranic fonts (Indopak Nastaleeq, QPC Hafs, Me Quran, Digital Khatt, etc.). Each font preview includes:<ul><li>Font name displayed in a badge</li><li>Your text rendered in that specific font</li><li>A copy button to quickly copy the rendered text</li></ul>This helps you identify which fonts properly support your text and detect any rendering issues.',
      },
      {
        type: 'step',
        title: 'View character set for a specific script',
        text: "You can view the complete character set for a specific Quranic script by selecting it from the dropdown and analyzing it. The tool will show the Unicode code point, occurrence count, and character name for each letter in the selected script. For example, the letter ب occurs 11,491 times in the King Fahad Hafs script. This is useful for understanding which characters are used in different Quranic scripts.",
      },
      {
        type: 'step',
        title: 'Use cases',
        text: '<ul><li><strong>Font debugging:</strong> Identify which fonts properly render specific Quranic text or special characters</li><li><strong>Unicode analysis:</strong> Understand the exact Unicode composition of Quranic text, including diacritical marks</li><li><strong>Script comparison:</strong> Compare character sets across different Quranic scripts</li><li><strong>Quality assurance:</strong> Verify that text displays correctly across all available fonts before publishing</li></ul>',
      }
    ]
  end

  def arabic_transliteration_help
    [
      "Quran word syllable tool",
      {
        text: "This tool is used to proofread and correct word-by-word Arabic transliterations. Please follow these steps to make adjustments to any transliteration:"
      },
      {
        type: 'step',
        title: 'Ayah by ayah',
        text: "Use the filters to find the ayah you're looks for. Click on <code>Show</code> button to open the ayah.",
        screenshot: 'arabic-transliteration.png'
      },
      {
        type: 'step',
        title: 'Review ayah words and transliteration of each word',
        text: "The ayah page will show all words of selected ayah along with their transliteration. Scroll down to see the source image that we're using as reference to digitize the transliteration. You can zoom, or scroll the the page to view the ayah within the image. If you find any issues, click the <code>Contribute</code> button to fix the transliteration.",
        screenshot: 'arabic-transliteration-show.png'
      },
      {
        type: 'step',
        title: "Fix the transliteration",
        text: "This page will show the Ayah along with a list of all its words. To help focus, only one word will be shown at a time. Each word comes with an input field where you can correct its transliteration. Once you're satisfied with the update, click <code>Save transliteration</code> to save the changes.",
        screenshot: "fix-arabic-transliteration.png"
      }
    ]
  end

  def surah_recitation_segment_builder_help
    [
      "Surah Recitation Segments",

      {
        text: "The Surah Recitation Segments tool is used to create or edit timestamp data for each word in a Surah's audio file. This data allows us to highlight the currently playing word during audio playback, enabling accurate follow-along experiences."
      },

      {
        text: "Only contributors with edit permissions can create or modify recitation segments. Please contact the admin or open an issue on GitHub if you encounter permission issues or suspect incorrect timing data.",
        type: "info"
      },

      {
        type: "heading",
        text: "Please follow these steps to create or fix Surah recitation segments:"
      },

      {
        type: "step",
        title: "Step 1: Select the Surah and reciter",
        sections: [
          {
            text: "From the Surah Recitation Segments index page, select the reciter you want to work on, then choose the Surah. Click the <code>Filter</code> button to see list of Surahs for the selected reciter. Click the <code>Fix segment</code> button to open the segment editor.",
            screenshot: "surah-segments-select-surah.png"
          }
        ]
      },

      {
        type: "step",
        title: "Step 2: Choose the audio source",
        sections: [
          {
            text: "Once the segment editor is open, select the audio source. You can either enter an audio file URL or choose a local audio file from your computer. The URL field will be pre-filled with the existing audio file, but you can change it if needed.",
            screenshot: "surah-segment-builder.png"
          },
          {
            type: "info",
            text: "You might select a local audio file if the current CDN audio has issues and you have a fixed version locally that is not yet uploaded to the CDN."
          },
          {
            text: "After selecting the audio source, click the <code>Load Audio Data</code> button to load the audio into the editor."
          }
        ]
      },

      {
        type: "step",
        title: "Step 3: Add Ayah timing (if missing)",
        sections: [
          {
            text: "If Ayah timing is missing, check the <code>Update Ayah timing</code> checkbox in the editor. This will allow you to set start and end times for each Ayah.",
            screenshot: "surah-segment-builder-ayah-timing.png"
          },
          {
            text: "Click the <code>Start</code> button when the Ayah begins to set its start time. Click the <code>End</code> button when the Ayah ends — this will set the current Ayah's end time and the start time for the next Ayah automatically."
          },
          {
            type: "info",
            text: "If <code>Auto Save</code> is checked, the system will automatically save the Ayah timing after each end time is set."
          },
          {
            text: "Once all Ayah timings are set, you can proceed to update word timings."
          }
        ]
      },

      {
        type: "step",
        title: "Step 4: Track and set word timestamps",
        text: "Click <code>Play</code> to start the audio. When a word is being recited, click its <code>Track</code> button to set the start time. The next time you click <code>Track</code> (for the same or next word), it will set the end time for the current word and automatically set the start time for the next word. Continue this process until all words in the Ayah have timings. Use the <code>−/+</code> buttons next to a time to nudge it in 50ms steps for fine corrections.",
        screenshot: "surah-segments-track-timing.png"
      },

      {
        type: "info",
        text: "Because the <code>Track</code> button sets both the end time of the current word and the start time of the next word, you don’t need to set times manually for every single field unless corrections are needed."
      },

      {
        type: "step",
        title: "Step 5: Review and fix mistakes",
        sections: [
          {
            text: "After tracking all words in the Ayah, play it back to ensure the highlighted words match the audio exactly.",
          },
          {
            text: "If any word timing is off, you can manually adjust it by editing the time fields or moving the waveform markers."
          }
        ]
      },

      {
        type: "step",
        title: "Step 6: Save your work",
        text: "Click the <code>Save Segments</code> button to store your changes. The system will save all word timings for the current Ayah. Remember to save after each Ayah before moving to the next one."
      },

      {
        type: "step",
        title: "Step 7: Repeat for remaining Ayahs",
        text: "Continue tracking and saving word timings for each Ayah until the entire Surah is completed."
      },

      {
        type: "heading",
        text: "Helpful features for reviewing and fixing timings"
      },

      {
        type: "step",
        title: "Split and Fill",
        sections: [
          {
            text: "If you tracked several words together as one block, click <code>Split</code> on the first word to divide its timing across the following words that have no timing yet. The time is split proportionally to each word's length.",
            screenshot: "surah-segments-split-fill.png"
          },
          {
            text: "If a single word in the middle has no timing, click <code>Fill</code> to give it a timing taken from the gap between its previous and next word."
          }
        ]
      },

      {
        type: "step",
        title: "Timeline",
        sections: [
          {
            text: "Turn on the <code>Timeline</code> checkbox to see every Ayah and word laid out on a time axis below the controls. The playhead follows playback and the view scrolls to keep it in view; use <code>Jump to current time</code> to recenter it, and the <code>+ / −</code> buttons to zoom in and out.",
            screenshot: "surah-segments-timeline.png"
          },
          {
            text: "Click anywhere on the timeline to seek the audio to that point. Hover over a word to see its location and timing (<code>surah:ayah:word — start–end ms</code>)."
          },
          {
            type: "info",
            text: "The timeline highlights problems automatically: a red Ayah band overlaps the next Ayah, a red word has invalid timing, and an orange word starts before the previous word ends."
          }
        ]
      },

      {
        type: "step",
        title: "Waveform and closing gaps",
        sections: [
          {
            text: "Enable the <code>Waveform</code> checkbox (available once audio is loaded) to draw the audio's waveform under the words. It decodes the entire audio file, so it can be slow for long Surahs, but it lets you see whether the empty space between two words is real silence or actually contains speech."
          },
          {
            text: "Empty space between words appears as a striped amber gap. Click a gap to close just that one, or click <code>Close gaps</code> to close every gap in the current Ayah. When the waveform is on, the boundary snaps to where speech actually resumes (trimming the leading silence); when it is off, the previous word's end is extended to meet the next word.",
            screenshot: "surah-segments-waveform-gaps.png"
          }
        ]
      },

      {
        type: "step",
        title: "Find and understand issues",
        sections: [
          {
            text: "Click <code>Find issues</code> to scan the whole Surah for problems. Issues are listed with the most important first — click any of them to jump straight to that Ayah. The label next to the save status also shows whether the current Ayah has a major or minor issue.",
            screenshot: "surah-segments-find-issues.png"
          },
          {
            type: "info",
            text: "Major issues (red) are a missing or invalid Ayah start/end, an Ayah that overlaps the next one, or the first/last word missing or invalid. Minor issues (amber) are a middle word missing timing, or two words overlapping. Row colors in the table: red = major issue, amber = minor issue, blue = unsaved change, green = the word playing now."
          }
        ]
      },

      {
        type: "step",
        title: "Tips for faster, more accurate tracking",
        sections: [
          {
            text: "Slow the audio down (press <code>s</code> or use the Speed dropdown) before clicking <code>Track</code>. At a slower speed it is much easier to click exactly on each word boundary. Press <code>n</code> to return to normal speed."
          },
          {
            text: "Turn on <code>Autoscroll</code> to keep the word table scrolled to the word currently playing, and use <code>Undo / Redo</code> (<code>Ctrl/Cmd + Z</code>) to step back and forth through your changes."
          }
        ]
      },

      {
        type: "demo",
        title: "Demo",
        text: "Demo video will be available here soon"
      }
    ]
  end

  def quran_scripts_comparison_help
    [
      "Quran Scripts Comparison Tool",
      {
        text: "This tool is designed to compare different Quranic scripts and identify inconsistencies. It helps you find words where characters appear in some scripts but are missing in others"
      },
      {
        type: 'info',
        text: "The tool supports two script types: <strong>Madani</strong> and <strong>Indopak</strong>. Each script type includes multiple script variants that are compared against each other."
      },
      {
        type: 'step',
        title: 'Step 1: Select Script Type',
        text: "When you first open the tool, you'll see two options: <strong>Madani Script</strong> and <strong>Indopak Script</strong>. Click on the script type you want to compare.",
      },
      {
        type: 'step',
        title: 'Step 2: Select a Character',
        text: "After selecting a script type, you'll see character sets for each script variant. Click on any character to view all words containing that character.",
      },
      {
        type: 'step',
        title: 'Step 3: Review Word Comparison',
        text: "After clicking a character, you'll see a table showing all words that contain that character in at least one of the scripts. The table displays:",
        sections: [
          {
            text: "<strong>Word ID</strong>: The location identifier (e.g., 1:1:1) with a copy-to-clipboard feature"
          },
          {
            text: "<strong>Script Columns</strong>: Each script variant is shown in its own column with proper font rendering"
          },
          {
            text: "<strong>Highlighting</strong>: Words are highlighted to indicate issues:"
          },
          {
            text: "• <span style='background-color: #fee2e2; padding: 2px 4px;'>Red background</span> on entire row: The character is missing in one or more scripts",
            css_class: 'ml-4'
          },
          {
            text: "• <span style='background-color: #fef3c7; padding: 2px 4px;'>Yellow background</span> on individual cell: That specific script doesn't contain the character",
            css_class: 'ml-4'
          }
        ]
      },
      {
        type: 'step',
        title: 'Step 4: Use Additional Features',
        text: "The word comparison view includes several helpful features:",
        sections: [
          {
            text: "<strong>Toggle matched words</strong>: Click the button to hide/show words where all scripts match (no issues)"
          },
          {
            text: "<strong>Font size slider</strong>: Adjust the font size for better readability"
          },
          {
            text: "<strong>Copy to clipboard</strong>: Click on any word location or text to copy it to your clipboard"
          },
          {
            text: "<strong>Issues summary</strong>: At the bottom, you'll see a summary of all words with issues, with clickable location tags"
          }
        ]
      },
      {
        type: 'info',
        text: "<strong>Tip:</strong> This tool is particularly useful for finding inconsistencies between script variants. Words highlighted in red or yellow indicate potential issues that may need review or correction."
      }
    ]
  end

  def ayah_dependency_graph_help
    [
      "Ayah Dependency Graphs",
      {
        text: "This tool visualizes the dependency structure of an ayah as a graph and allows you to edit nodes and edges."
      },
      {
        type: 'step',
        title: 'Step 1: Find an ayah',
        text: "Use the filters (Surah/Ayah) and status filter on the index page. The table shows ayah text, graph count, and a derived review status."
      },
      {
        type: 'step',
        title: 'Step 2: Open the graph',
        text: "Click <code>View</code> to open the graph. Use <code>Previous</code>/<code>Next</code> to navigate between graphs."
      },
      {
        type: 'heading',
        text: "Understanding the editor"
      },
      {
        type: 'info',
        text: "<strong>Auto-save:</strong> Most fields save automatically when you change them. The preview refreshes after updates."
      },
      {
        type: 'step',
        title: 'Graph Nodes',
        sections: [
          {
            text: "Graph nodes represent the individual words or elided tokens in the verse. They form the basis of the dependency graph."
          },
          {
            type: 'info',
            text: "<div class='text-center'><img src='#{image_path('morphology/nodes_diagram.png')}' class='img-fluid rounded border' style='max-width: 420px;' alt='Nodes Diagram'></div>"
          },
          {
            type: 'info',
            text: "<strong>Node Type</strong><br/>Choose what this node represents:<ul><li><code>Word</code>: a token linked to a Quran word/segment</li><li><code>Reference</code>: a reference token (also linked to a word)</li><li><code>Elided</code>: an implied token (no word resource)</li></ul>"
          },
          {
            type: 'info',
            text: "<strong>Resource/Details</strong><br/><ul><li><code>Word</code>: select the Word and (optionally) a Segment</li><li><code>Reference</code>: select the Word</li><li><code>Elided</code>: set <code>Value</code> and <code>POS</code></li></ul>"
          },
          {
            type: 'info',
            text: "<strong>Actions</strong><br/><ul><li><code>+</code>: adds a new node after the current node</li><li><code>🗑</code>: removes the node (disabled for word nodes)</li></ul>"
          }
        ]
      },
      {
        type: 'step',
        title: 'Phrase Nodes',
        sections: [
          {
            text: "Phrase nodes represent grammatical constituents that group multiple words or other phrases together (e.g., Noun Phrase, Verb Phrase). They help define the hierarchical structure of the sentence."
          },
          {
            type: 'info',
            text: "<div class='text-center'><img src='#{image_path('morphology/phrase_node_diagram.png')}' class='img-fluid rounded border' style='max-width: 420px;' alt='Phrase Node Diagram'></div>"
          },
          {
            type: 'info',
            text: "<strong>POS</strong><br/>This is the phrase tag (e.g. NP/VP/PP)."
          },
          {
            type: 'info',
            text: "<strong>Source → Target</strong><br/>Select the start and end node range (<code>nX → nY</code>) that the phrase spans."
          }
        ]
      },
      {
        type: 'step',
        title: 'Graph Edges',
        sections: [
          {
            text: "Graph edges are the curved lines that connect nodes. They represent the grammatical relationships between words or phrases, with a starting point (source) and an ending point (target)."
          },
          {
            type: 'info',
            text: "<div class='text-center'><img src='#{image_path('morphology/edges_diagram.png')}' class='img-fluid rounded border' style='max-width: 420px;' alt='Edges Diagram'></div>"
          },
          {
            type: 'info',
            text: "<strong>Source Node / Target Node</strong><br/>Pick the head/dependent endpoints for the relationship."
          },
          {
            type: 'info',
            text: "<strong>Relation</strong><br/>Select the dependency tag (edge label) used in the rendered graph."
          }
        ]
      },
      {
        type: 'step',
        title: 'Preview',
        text: "Use the preview panel to confirm the graph renders as expected. Click refresh if you need to re-render."
      },
      {
        type: 'step',
        title: 'Step 3: Compare with Quran Corpus (optional)',
        text: "Click <code>Compare</code> to view the Quran Corpus reference image side-by-side with the rendered graph."
      },
      {
        type: 'step',
        title: 'Step 4: Edit graph (modal)',
        text: "Click <code>Edit</code> to open the editor. Changes are saved field-by-field as you update node/edge fields."
      },
      {
        type: 'step',
        title: 'Step 5: Split graph (optional)',
        text: "Use <code>Split graph</code> to move nodes between graphs for the same ayah. Any edges that connect nodes across different graphs will be removed."
      },
      {
        type: 'info',
        text: "<strong>Review status on index:</strong> <code>Approved</code> means all graphs for the ayah are approved. Otherwise it shows <code>In progress</code>."
      }
    ]
  end

  def ayah_recitation_help
    [
      "Ayah recitations tool",
      {
        text: "This tool is used to build and proofread word-by-word timestamp (segment) data for ayah-by-ayah recitations. Each segment maps a word in the ayah to its start and end time in the audio file so the word can be highlighted while the recitation plays."
      },
      {
        type: 'info',
        text: "Segments are the backbone of word highlighting. Accurate segments ensure each word lights up at the exact moment it is recited."
      },
      {
        type: 'step',
        title: 'Step 1: Find the recitation and ayah',
        text: "Use the filters to pick a <code>Surah</code> and, optionally, an <code>Ayah</code> number. The table lists the audio files of the selected recitation along with their verse. Click <code>Show</code> to open an ayah."
      },
      {
        type: 'step',
        title: 'Step 2: Review the audio and existing segments',
        text: "The ayah page shows the recitation details and audio for the selected Surah. Use the <code>Previous Surah</code> and <code>Next Surah</code> buttons to move between Surahs, and click <code>View Segments</code> to open the segment builder."
      },
      {
        type: 'step',
        title: 'Step 3: Build or fix the segments',
        text: "In the segment builder, play the audio and adjust the start/end time of each word so the highlighting matches the recitation. Click <code>Short keys</code> to see the keyboard shortcuts that speed up segmenting. Your changes are saved against the selected recitation."
      },
      {
        type: 'info',
        text: "You need editing access to save segments. If you don't have access, open the tool and click <code>Request Access</code>."
      }
    ]
  end

  def corpus_help
    [
      "Quran corpus tool",
      {
        text: "This tool is used to proofread and fix the Quran corpus data, the concordance label, part of speech (POS), grammar and morphology tagging for every word of the Quran."
      },
      {
        type: 'step',
        title: 'Step 1: Find the ayah',
        text: "Use the filters to narrow down by <code>Juz</code>, <code>Surah</code> or <code>Ayah</code> number. The table lists the ayahs; click <code>Show</code> to open an ayah for tagging."
      },
      {
        type: 'step',
        title: 'Step 2: Review the words of the ayah',
        text: "The ayah page lists every word with its current corpus data. Use the <code>Previous ayah</code> and <code>Next ayah</code> buttons to move between ayahs. Click a word to open its detail page."
      },
      {
        type: 'step',
        title: 'Step 3: Fix word level data',
        text: "On the word detail page you can review and correct the word's morphology and segments. Use <code>Previous Word</code> and <code>Next Word</code> to move between words of the ayah, and open a segment to edit its segment-level data."
      },
      {
        type: 'step',
        title: 'Step 4: Fix segment level data',
        text: "Many words split into multiple morphological segments (prefix, stem, suffix). Open a segment to correct its part of speech and grammar tagging, then save your changes."
      },
      {
        type: 'info',
        text: "You need editing access to save corpus changes. If you don't have access, open the tool and click <code>Request Access</code>."
      }
    ]
  end

  def compare_audio_help
    [
      "Compare audio tool",
      {
        text: "This tool is used to compare audio recitations side-by-side so you can spot differences in timing, segmentation and audio between reciters or between versions of the same recitation."
      },
      {
        type: 'info',
        text: "The documentation for this tool is being expanded. Reach out on GitHub if a specific step is unclear."
      }
    ]
  end

  def audio_repair_index_help
    [
      "Audio repair",
      {
        text: "Audio repair fixes mistakes in a published recitation without re-recording it: a mispronounced word, a wrong vowel, a stumble. Repairs are non-destructive — the original file is never modified, and every change is kept as an undoable operation until you export."
      },
      {
        type: 'step',
        title: 'Pick a reciter and surah',
        text: "Search the list for the reciter, then choose the surah that needs work. This opens (or reopens) a repair session for that pairing. A session keeps its list of repairs, so you can come back to it later."
      },
      {
        type: 'step',
        title: 'What you need before you start',
        text: "The surah must have word timings for the reciter. To fix a single sound rather than a whole word, it also needs <strong>letter timings</strong> — the editor will tell you if they are missing."
      },
      {
        type: 'info',
        text: "Exporting re-encodes the whole surah and runs in the background. The repaired file is written alongside the original; nothing you do here changes the published audio."
      }
    ]
  end

  def audio_repair_ingest_help
    [
      "Add audio",
      {
        text: "Import a new reciter’s recordings, one surah at a time. Source files may vary in format and bitrate or include extra audio, such as an opening basmala, surah name, or closing dua. This tool standardizes the recordings, with every cut reviewed before import."
      },
      {
        type: 'step',
        title: '1. Describe the recitation',
        text: "Select or create the reciter, then choose the recitation style and qira’at. The new recitation remains unapproved until you review it."
      },
      {
        type: 'step',
        title: '2. Configure the source',
        text: "Enter a source URL for one surah and select the surah range. The tool previews the first and last URLs before downloading. Use <strong>Edit source</strong> to correct the URL and retry."
      },
      {
        type: 'step',
        title: '3. Download recordings',
        text: "Surahs download in parallel batches, with individual progress and retries for failed downloads. Interrupted downloads are never treated as complete."
      },
      {
        type: 'step',
        title: '4. Review the opening cut',
        text: "Review the proposed cut that removes the opening basmala where needed. Listen, drag the marker, or adjust it in milliseconds. Al-Fatihah and At-Tawbah are skipped automatically.",
        sections: [
          {
            type: 'info',
            text: "Automatic cuts are suggestions, not decisions. Confirm every cut by ear, especially when there is no pause between the opening and the first ayah. Ensure the first word remains intact before approving."
          }
        ]
      },
      {
        type: 'step',
        title: '5. Trim closing supplications',
        text: "Optionally detect and remove a closing dua. Review the proposed cut carefully, as audio after a pause may contain valid closing ayahs."
      },
      {
        type: 'step',
        title: '6. Encode surahs',
        text: "Approve the cuts to encode each surah in the library’s supported formats, with consistent tags for surah, reciter, and track number. Choose the bitrate for the full run or individual surahs. Re-encoding always uses the untouched original."
      },
      {
        type: 'step',
        title: '7. Validate the output',
        text: "Each file is checked for expected duration and stereo-to-mono phase cancellation. Surah pages show measured duration, size, bitrate, channels, and sample rate. You can also run a full timeline report."
      },
      {
        type: 'info',
        text: "Originals and encoded files can consume several gigabytes. The run page shows storage usage and lets you delete files you no longer need. Keep originals if you may need to adjust cuts or re-encode at another bitrate; otherwise, you’ll need to download them again."
      },
      {
        type: 'step',
        title: '8. Complete the import',
        text: "Once all surahs are encoded and validated, review the results and approve the recitation for publication. Only approved recitations become available in the library."
      }
    ]
  end

  def audio_repair_polarity_help
    [
      "Polarity check",
      {
        text: "Some published surah files have the right channel inverted — every sample is the negative of the left. On headphones this is inaudible. On anything that sums the two channels to mono (a phone earpiece, a mono Bluetooth speaker, an app's mono output) the two cancel and the recitation drops to near silence. This page finds those stretches and validates a corrected file."
      },
      {
        type: 'step',
        title: 'Pick the original',
        text: "Drop the mp3 as published, choose it from disk, or paste its URL. Choosing a recitation and surah labels each finding with ayah numbers; with no file given, the published file for that surah is checked."
      },
      {
        type: 'step',
        title: 'Optionally add the fixed file',
        text: "If you already corrected the file, add it the same way. It is validated against the original: no inverted audio left, the mono mix as loud as stereo, and duration, sample rate and tags unchanged."
      },
      {
        type: 'step',
        title: 'Listen',
        text: "Switch the output to <strong>Mono (L+R)</strong> — that is the same sum a mono device makes — and play a flagged window. The level meter collapses and the recitation disappears. Switch the source to <strong>Fixed</strong> at the same spot to hear the repair. Click a timeline to seek both files together."
      },
      {
        type: 'step',
        title: 'Generate the fix',
        text: "<strong>Generate fixed file</strong> flips the right channel inside the flagged windows (the whole file when all of it is inverted), keeps the tags, bitrate and sample rate, then validates the result. Download it from the top right once it passes."
      },
      {
        type: 'info',
        text: "Phase correlation runs from +1 (identical channels) to -1 (inverted). Windows are reported where it stays below -0.5 for half a second or more of audible audio; fades and room tone are ignored. A clean file reads around +0.6 to +0.9 and loses under 1 dB in mono; an inverted one loses 30 dB or more."
      }
    ]
  end

  def audio_repair_editor_help
    [
      "Audio repair editor",
      {
        text: "Two kinds of repair, chosen with the tabs at the top. <strong>Replace word</strong> swaps a whole word or phrase for the same words recited correctly elsewhere. <strong>Fix pronunciation</strong> corrects one sound in place, without replacing any audio."
      },
      {
        type: 'info',
        text: "Pick the right one: if the reciter said the <em>wrong word</em>, replace the word. If the word is right but a <em>vowel or letter</em> came out wrong, fix the pronunciation — it changes far less of the audio and cannot shift any timings."
      },

      { type: 'heading', text: 'Replace word' },
      {
        type: 'step',
        title: 'Step 1: Select what to replace',
        text: "Click a word in the ayah; shift-click a second word to select a run. Greyed-out words have no timing and cannot be selected. The red waveform on the left is the audio you are about to replace, and you can nudge its start and end in milliseconds if the word boundary is slightly off."
      },
      {
        type: 'step',
        title: 'Step 2: Find a replacement',
        text: "<strong>Find same word</strong> searches every other place this reciter says the same word or phrase. Because the stored text is always the correct text, this finds correctly-recited occurrences even though the audio at your target is wrong. <strong>Manual</strong> looks up a specific reference such as <code>18:31:6</code> or <code>18:31:6-7</code>. Use <em>Play</em> to audition a candidate and <em>wave</em> to see its shape before committing."
      },
      {
        type: 'step',
        title: 'Step 3: Fit it to the original',
        text: "A clip taken from elsewhere in the surah is usually a little louder or quieter, a little higher or lower in pitch, and a little longer or shorter than the gap it has to fill. All three are audible, so press <strong>Measure</strong> to see the numbers side by side, then <strong>Match all</strong> to write the suggested corrections into the sliders.",
        sections: [
          {
            type: 'info',
            text: "<strong>Loudness</strong> is measured in LUFS, which tracks perceived level rather than peak. <strong>Pitch</strong> is the median f0 across the clip. <strong>Length</strong> drives the time-stretch. A dash in the <em>fix</em> column means the difference is too small to be worth correcting — applying a correction there would only add artefacts.<br><br>The corrections land in the sliders rather than being applied invisibly, so you can always see and adjust what is being done. The editor warns if a candidate needs a pitch shift beyond about 2 semitones or a stretch beyond ±25%: at that point choosing a different candidate almost always beats correcting this one."
          }
        ]
      },
      {
        type: 'step',
        title: 'Step 4: Preview and apply',
        text: "<strong>Render preview</strong> builds the splice with a little context either side so you can hear it in place; A/B against the original with the two play buttons. <strong>Apply</strong> adds it to the repair list. Nothing is written to audio until you export, and every repair can be undone."
      },

      { type: 'heading', text: 'Fix pronunciation' },
      {
        type: 'info',
        text: "This does not splice in anyone else's audio. It takes the <em>shape of the mouth</em> from a correct recitation of the same letter and applies it to the reciter's own voice. The result is still entirely his voice, at his pitch, in his acoustic — only the articulation changes. It is also exactly length-preserving, so no later word or letter timing moves."
      },
      {
        type: 'step',
        title: 'Step 1: Choose the sound',
        text: "Pick the word, then the exact letter or harakah. Each chip shows how long that sound lasts and is drawn as wide as its duration, so a 60 ms consonant and a 430 ms stressed letter are easy to tell apart. <strong>Shift-click a second chip to select a run of sounds</strong> — useful when a whole syllable is wrong rather than a single vowel.",
        sections: [
          {
            type: 'info',
            text: "Harakat are shown on a dotted stroke (ـَ ـِ ـُ) because a vowel mark on its own is almost invisible. Selecting several sounds maps the donor letter-by-letter, so each letter lands on its counterpart even when the two recitations hold them for different lengths."
          }
        ]
      },
      {
        type: 'step',
        title: 'Step 2: Choose where the correct sound comes from',
        text: "The list shows the same letter of the same word recited elsewhere by this reciter. <em>same next</em> marks donors where the following sound also matches — those usually give the smoothest result, because the correction has to glide into whatever comes next.",
        sections: [
          {
            type: 'info',
            text: "<strong>Measure all</strong> actually runs the repair for every donor and re-sorts the list by the measured outcome. It takes a few seconds per donor and results appear as they finish, so you can stop early. This matters: donors that look equally good on paper can differ a lot in practice, and the ordering before you measure is only a guess."
          }
        ]
      },
      {
        type: 'step',
        title: 'Step 3: Listen, check the gauge, apply',
        text: "The <strong>vowel colour</strong> gauge is the main readout. It plots where the sound sits between a rounded ḍamma-like vowel on the left and a front kasra-like vowel on the right, marking where it was before and where it landed after. A repair that worked moves the dot clearly across the middle band.",
        sections: [
          {
            type: 'info',
            text: "<strong>Join smoothness</strong> is the largest jump in the second formant near the edit; lower is smoother, and the figure in brackets is what it was before. A large number means the correction does not blend into the neighbouring sounds — try a donor with the same following sound, or lengthen <em>Glide out</em>.<br><br><strong>Audio changed</strong> shows how much of the recording was touched. It should be a little wider than the sound you selected and nothing more."
          }
        ]
      },
      {
        type: 'step',
        title: 'Advanced settings',
        text: "The defaults are tuned and suit most repairs; open this only when a result is not good enough. Each control changes one thing:",
        sections: [
          {
            type: 'info',
            text: "<strong>Ramp in</strong> — how long the correction takes to reach full strength before the sound.<br><strong>Glide out</strong> — how far it glides into the following consonant. Raise it if the join sounds abrupt.<br><strong>Strength</strong> — how far toward the donor's articulation to go. Below 1 the sound is only partly corrected; useful when a full correction overshoots.<br><strong>Tilt split</strong> — where the donor's vowel ends and its recording character begins. Raise it and the donor's microphone starts bleeding through; lower it and less of the vowel comes across.<br><strong>Filter order</strong> — resolution of the vocal-tract model. Higher tracks more detail but is less stable; lower it if the editor reports frames it could not model."
          }
        ]
      },

      { type: 'heading', text: 'Finishing up' },
      {
        type: 'step',
        title: 'Repairs, undo and export',
        text: "Every applied repair is listed at the bottom, tagged <em>word</em> or <em>sound</em>, with the measured before/after for pronunciation fixes. Undo and redo walk the list. <strong>Export MP3</strong> renders the whole surah with every repair applied and gives you a download link.",
        sections: [
          {
            type: 'info',
            text: "Pronunciation fixes are applied to the surah first and word replacements afterwards, so the two compose cleanly. Because a pronunciation fix never changes length, the word and letter timings you already have stay valid for the exported file."
          }
        ]
      }
    ]
  end
end
