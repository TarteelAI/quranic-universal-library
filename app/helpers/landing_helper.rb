module LandingHelper
  class Tool < OpenStruct
  end

  def developer_tools
    [
      Tool.new(
        title: 'Surah audio segments',
        description: 'Tool for creating word by word timestamp data of surah audio files.',
        url: '/surah_audio_files',
        id: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Surah Timestamp Editor is designed to help you prepare precise timestamp data for surah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      Tool.new(
        title: 'Prepare Mushaf layout',
        description: 'Proofread and fix different layouts of Mushaf( 15 lines, 16 lines, v2, v1 etc)',
        url: '/audio_segments',
        id: 'mushaf-layout',
        icon: 'layout.svg',
        cta_bg: 'rgba(71, 71, 61, 0.9)',
        info_tip: "This feature allows you to view the digital Quran script as it appears in printed Mushafs. You can also customize and prepare layouts based on any printed Mushaf format."
      ),
      Tool.new(
        title: 'Mutashabihat ul Quran',
        description: 'Contribute preparing matching ayah and phrases data in Quran.',
        url: '/morphology_phrases',
        id: 'mutashabihat',
        icon: 'mutashabihat.svg',
        cta_bg: 'rgba(56, 152, 173, 0.9)',
        info_tip: "This tool allows you to identify and compare verses and phrases that share similarities in meaning, context, or wording."
      ),
      Tool.new(
        title: 'Ayah audio segments',
        description: 'Tool for creating word by word segments of ayah by ayah audio files.',
        url: '/ayah_audio_files',
        id: 'segments',
        icon: 'timestamp.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "Ayah Timestamp Editor is designed to help you prepare precise timestamp data for ayah audio files. This data empower Quranic apps to highlight the currently playing words in real-time."
      ),
      Tool.new(
        title: 'Ayah translation in different languages',
        description: 'Tool for proofreading and suggesting fixes for ayah translations.',
        url: '/ayah_audio_files',
        id: 'translation',
        icon: 'translation.svg',
        cta_bg: 'rgba(90, 77, 65, 0.9)',
        info_tip: "This tool helps you review and suggest fixes for Quran translations, including typos and issues that may occur during OCR (Optical Character Recognition) or due to human error."
      ),
      Tool.new(
        title: 'Quranic script and fonts',
        description: 'Proofread tashkeel issues of Quran script for different fonts.',
        url: '/word_text_proofreadings',
        id: 'quranic-text',
        icon: 'open_book.svg',
        cta_bg: 'rgba(56, 165, 126, 0.9)',
        info_tip: "This tool enables you to proofread Quran script rendering in various fonts, examining it both ayah by ayah and word by word. Ensure that the script is accurately rendered and consistent across different fonts for a seamless reading experience.",
        )
    ]
  end
end