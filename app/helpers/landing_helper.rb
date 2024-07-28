module LandingHelper
  def featured_resource_cards
    recitations = ResourceContent.approved.recitations
    with_segments = recitations.with_segments.count
    total_recitations = recitations.count

    total_layout = Mushaf.count
    approved_layout = Mushaf.approved.count

    [
      ToolCard.new(
        title: 'Recitations and segments data',
        description: "Download high-quality audio files of Quranic recitations along with detailed timestamp data for ayah-by-ayah and surah-by-surah. Use the timestamp data to highlight words as the recitation plays.",
        icon: 'timestamp.svg',
        url: '/resources/recitations',
        count: total_recitations,
        id: 'card-recitations',
        stats: "<div><div>#{total_recitations - with_segments} Unsegmented Audio</div><div>#{with_segments} Segmented Audio</div></div>"
      ),
      ToolCard.new(
        title: "Mushaf layouts",
        description: "Download Mushaf layout data to render Quran pages exactly like the printed Mushaf. The exact layout aids in memorizing the Quran, offering users a familiar experience similar to their favorite printed Mushaf.",
        icon: 'layout.svg',
        url: '/resources/mushaf-layouts',
        count: total_layout,
        id: 'card-mushaf-layouts',
        # TODO: once all layout are approved, stats will looks weird. Fix the messaging
        stats: "<div><div>#{approved_layout} Layouts —  Approved</div><div>#{total_layout - approved_layout} Layouts —  WIP</div></div>"
      )
    ]
  end

  def developer_tools
    [
      ToolCard.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Surah Timestamp Editor is designed to help you prepare precise timestamp data for surah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'mushaf-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)',
        info_tip: "This feature allows you to view the digital Quran script as it appears in printed Mushafs. You can also customize and prepare layouts based on any printed Mushaf format."
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        info_tip: "This tool allows you to identify and compare verses and phrases that share similarities in meaning, context, or wording."
      ),
      ToolCard.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Ayah Timestamp Editor is designed to help you prepare precise timestamp data for ayah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      ToolCard.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting fixes for ayah translations.',
        url: '/ayah_audio_files',
        type: 'translation',
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran translations, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Proofread tashkeel issues of Quran script for different fonts.',
        url: '/word_text_proofreadings',
        type: 'quranic-text',
        icon: 'open_book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool enables you to proofread Quran script rendering in various fonts, examining it both ayah by ayah and word by word. Ensure that the script is accurately rendered and consistent across different fonts for a seamless reading experience.",
      )
    ]
  end

  def developer_resources
    [
      ToolCard.new(
        title: 'Download Quran Translation',
        description: 'Download ayah by ayah and word by word translation in different languages.',
        url: '/ayah_audio_files',
        type: 'translation',
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
      ),
      ToolCard.new(
        title: 'Audio files and segments data',
        description: 'Download surah by surah, ayah by ayah and word by word audio files and segments data.',
        url: '/surah_audio_files',
        type: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
      ),
      ToolCard.new(
        title: 'Quranic script and fonts',
        description: 'Download Quran text and fonts, Madani, IndoPak etc.',
        url: '/word_text_proofreadings',
        type: 'quranic-text',
        icon: 'open_book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
      ),
      ToolCard.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/mushaf_layouts',
        type: 'page-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)'
      ),
      ToolCard.new(
        title: 'Mutashabihat ul Quran Data',
        description: 'Download Mutashabihat ul Quran data, featuring the similar or analogous phrases found throughout the Quran.',
        url: '/morphology_phrases',
        type: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
      ),
      ToolCard.new(
        title: 'Tafsirs',
        description: 'Download tafsir data in multiple languages, complete with ayah grouping information.',
        url: '/ayah_audio_files',
        type: 'tafsirs',
        icon: 'book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)'
      )
    ]
  end
end