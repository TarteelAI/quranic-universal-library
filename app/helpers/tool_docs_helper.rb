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
      'word_translation'
    ]
  end

  def doc_image_tag(path)
    url = "https://static-cdn.tarteel.ai/qul/help-screenshots/#{path}?dd=a"
    "<img data-src='#{url}' class='img-fluid' data-controller='lazy-load' />".html_safe
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
        title: 'Step 3: Read the translation',
        text: "Review the translation of each word carefully. If an update is needed, click the <code>Contribute</code> button to fix the translation.",
        screenshot: 'ayah-words-translation.png'
      },
      {
        type: 'step',
        title: 'Step 4: Update the translation',
        text:  "The page will display the Ayah along with a list of all its words. To help focus, only one word will be shown at a time. Each word comes with an input field where you can correct its translation. Once you're satisfied with the update, click <code>Submit</code> to save the changes.",
        screenshot: 'update-word-translation.png'
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
        text: 'Click on <code>'
      }
    ]
  end

  def mushaf_layout_help
    [
      "Mushaf Layout",

      {
        text: 'Mushaf layout tool is used to create layout of any physical Mushaf. We can adjust pages, number of lines per page, alignment of each line on page, and word placement on each line to accurately represent the Mushaf page.',
      },

      {
        text: "The number of pages or lines per page can only be adjusted by an admin. Please contact the admin or open an issue on GitHub if you encounter any problems with the page count or line per page for any Mushaf layout.",
        type: 'info'
      },

      {
        type: 'heading',
        text: "Please follow these steps to work on a new Mushaf layout or resolve any issues with an existing one:"
      },
      {
        type: 'step',
        title: 'Step 1: Select the mushaf layout you want to work on',
        sections: [
          {
            text: 'From the Mushaf layout index page, find the layout you want to work on and click the <code>Show</code> button.',
            screenshot: 'mushaf-layout-list.png'
          },

          {
            text: 'This will open the first page of selected Mushaf. You can navigate to other pages using the <code>Next</code> and <code>Previous</code> buttons. <code>Actions</code> dropdown will show bunch of actions you can perform on selected page. The first action is to update the ayah mapping for the pages.',
            screenshot: 'mushaf-layout-actions.png'
          }
        ]
      },
      {
        type: 'step',
        title: 'Step 2: Ayah Mapping for Each Page',
        text: 'Click on <code>Update page ayah mapping</code> from actions dropdown to open the page mapping page. Enter the Ayah key for the first and last Ayah of the page (e.g., 1:1 for Surah 1, Ayah 1), then click the <code>Save</code> button to save your changes. We need to configure ayah ranges for all the pages in the selected Mushaf.',
        screenshot: 'mushaf-layout-page-mapping.png'
      },

      {
        type: 'step',
        title: 'Step 3: Update words for each line',
        text: "Click on the <code>Update page words</code> option from the actions dropdown to open the page where you can set the line number of each word in the current page. Adjust the line number of each word using the <code>Line</code> number field below each word. Updating the position of the first word will automatically propagate the change to all following words. You don't need to adjust the line number for every word, just update the first word of each line. You can view the Mushaf page in the PDF on the left side of the screen. After fixing the position of all the words, click the <code>Save</code> button to save your changes.",
        screenshot: 'mushaf-layout-words.png'
      },

      {
        type: 'info',
        text: "If you need to update line number of a specific words, you can disable auto propagation by unchecking on the <code>Propagate changes</code> checkbox. This will allow you to update the line number of each word individually."
      },

      {
        type: 'step',
        title: 'Step 4: Fix line alignment of page',
        sections: [
          {
            text: "After fixing the words position, the next step is to fix the line alignment of the page. Click <code>Fix line alignment</code> from the actions dropdown to open the line alignment page.",
            screenshot: 'mushaf-layout-line-alignment.png'
          },

          {
            text: "You'll see four alignment options for each line. <ul><li><code>C</code> Select this if line should be center aligned</li><li><code>J</code> Select this if line should be justified(this is default option for all lines)</li><li><code>B</code> Select this if there is Bismillah on this line</li><li><code>N</code> Select this if there is surah name on this line</li></ul>. Line alignment info is automatically saved, and page preview will be refreshed."
          }
        ]
      },

      {
        type: 'step',
        title: 'Step 5: Proofread the page',
        text: "After fixing the line alignment, you can proofread the page by clicking the <code>Proofread view</code> option from the actions dropdown. This will open the proofreading page where you can view the page in the PDF viewer and compare it with the actual Mushaf page. If you find any issues, you can go back to the previous steps to fix them.",
      },

      {
        type: 'demo',
        title: "Demo",
        text: "TODO: Add a demo video here"
      }
    ]
  end
end