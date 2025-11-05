module ToolDocsHelper
  def available_tool_keys
    [
      'mushaf_layout',
      'arabic_transliteration',
      'ayah_recitation',
      'ayah_tafsir',
      'ayah_translation',
      'char',
      'corpus',
      'mutashabihat',
      'quran_script',
      'surah_info',
      'surah_recitation',
      'surah_recitation_segment_builder',
      'tajweed',
      'word_translation',
      'compare_ayah'
    ]
  end

  def doc_image_tag(path)
    url = "https://static-cdn.tarteel.ai/qul/help-screenshots/#{path}}"
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
        title: 'Step 1: Find the word translation for a specific language',
        text: "Use the available filters to find the desired translation. You can filter by <code>Language</code> <code>Surah</code> and <code>Ayah</code> to narrow down the results. Click <code>Show</code> to display the selected Ayah, where a list of words and their corresponding translations will appear.",
        screenshot: 'word_translations.png'
      },
      {
        type: 'step',
        title: 'Step 2: Read the translation',
        text: "Review the translation of each word carefully. If an update is needed, click the <code>Edit</code> button to fix the translation.",
        screenshot: 'ayah-words-translation.png'
      },
      {
        type: 'step',
        title: 'Step 3: Update the translation',
        text: "The page will display the Ayah along with a list of all its words. To help focus, only one word will be shown at a time. Each word comes with an input field where you can correct its translation. Once you're satisfied with the update, click <code>Save translations</code> to save the changes.",
        screenshot: 'update-word-translation.png'
      },
      {
        type: 'info',
        text: "Some phrases convey better meanings when translated as a whole. <br/>For example, <span class='qpc-hafs'>مِنۢ بَيۡنِ أَيۡدِيهِمۡ</span> means <strong>before them</strong>. A literal, word-by-word translation would be <strong>from</strong>, <strong>between</strong>, <strong>their hands</strong>, which may not convey the intended meaning clearly. In such cases, we can provide group translations for better understanding.",
      },
      {
        type: 'step',
        title: 'Step 3.1: Update the group translation',
        sections: [
          {
            text: "If you find a group of words that should be translated together, you can group them. To do this, click the <code>Create Group translation</code> button(Or <code>Edit Group translation</code> if you need to change an existing group) to open the group translation modal.",
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
        text: "This tool is designed fix the tajweed annotations for each word in the Ayah."
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
      "Character tool",
      {
        text: "This tools is used to detect unicode code point and char name of all letters of given Arabic string."
      },
      {
        type: 'step',
        title: 'Step 1: Enter the text',
        text: 'Simply enter the text in the input field and click on the <code>Submit</code> button. The tool will display the unicode code point and char name of each letter in the input text.',
        screenshot: 'char-info.png'
      },
      {
        type: 'step',
        title: "View character set for a specific script",
        text: "You can view the character set for a specific script by selecting the script from the dropdown. The tool will display the unicode code point, occurrence count, and char name of each letter in the selected script. For example the letter ب is occurred 11491 times in the King Fahad Hafs script.",
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
        text: "Click <code>Play</code> to start the audio. When a word is being recited, click its <code>Track</code> button to set the start time. The next time you click <code>Track</code> (for the same or next word), it will set the end time for the current word and automatically set the start time for the next word. Continue this process until all words in the Ayah have timings. You can also drag the time handles in the waveform to fine-tune timings.",
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
        type: "demo",
        title: "Demo",
        text: "Demo video will be available here soon"
      }
    ]
  end
end