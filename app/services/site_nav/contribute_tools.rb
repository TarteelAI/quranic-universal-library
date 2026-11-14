# frozen_string_literal: true

class SiteNav
  # How the Contribute menu shows the contribution tools: the group each tool is listed under,
  # its icon and a one-line description. Keyed by the tool titles in ToolsHelper#developer_tools,
  # which stays the list of tools and their links; the copy lives here so the old tools page,
  # which reads the same helper, does not change. A tool missing here is listed under
  # FALLBACK_GROUP with no icon or description.
  module ContributeTools
    # Heading => { tool title => [icon, description] }. Icons are names from SiteNav::ICONS.
    GROUPS = {
      'Translations & tafsir' => {
        'Ayah translations' => ['languages', 'Fix typos in many languages.'],
        'Ayah transliterations' => ['case-sensitive', 'Each ayah in Latin script.'],
        'Tafsirs' => ['book-open-text', 'Tafsir text and ayah ranges.'],
        'Surah info' => ['info', 'Surah introductions.'],
      },
      'Mushaf & scripts' => {
        'Mushaf layouts' => ['layout-panel-top', 'Words on each line of each page.'],
        'Tajweed rules' => ['palette', 'Rules marked on each letter.'],
        'Quran scripts and fonts' => ['type', 'Each script in its fonts.'],
      },
      'Audio & segments' => {
        'Surah audio segments' => ['audio-waveform', 'Word timestamps, surah by surah.'],
        'Ayah audio segments' => ['timer', 'Word timestamps, ayah by ayah.'],
        'Ayah audio cutter' => ['scissors', 'Ayah files from a surah recitation.'],
        'Segment pipeline' => ['workflow', 'Word timestamps for any recitation.'],
        'Add reciter audio' => ['mic', 'Recordings of a new reciter.'],
      },
      'Words & grammar' => {
        'Word by word translations' => ['whole-word', 'The meaning of each word.'],
        'Word by word transliterations' => ['case-sensitive', 'How each word reads in Latin script.'],
        'Word syllables in Arabic and Urdu' => ['split', 'Syllables in Arabic and Urdu script.'],
        'Word roots, stems and lemmas' => ['sprout', 'Word roots and their meanings.'],
        'Word grammar and morphology' => ['tags', 'Part of speech and features.'],
        'Ayah dependency graphs' => ['network', 'Syntax of each ayah as a graph.'],
      },
      'Ayahs & topics' => {
        'Mutashabihat' => ['repeat', 'Phrases that repeat across ayahs.'],
        'Similar ayahs' => ['copy', 'Ayahs that share most words.'],
        'Ayah topics' => ['list-tree', 'Topics and their ayahs.'],
        'Ayah themes' => ['layers', 'Theme and keywords of ayah groups.'],
      },
      'Compare & check' => {
        'Compare Quran scripts' => ['git-compare', 'Madani and Indopak, word by word.'],
        'Compare fonts' => ['file-diff', 'What changed between two builds.'],
        'Compare audio' => ['audio-lines', 'Length, waveform and pauses.'],
        'Compare ayahs' => ['columns', 'Text and translations side by side.'],
        'Unicode and font checker' => ['hash', 'Code points and font previews.'],
      },
    }.freeze

    # One line under each heading on the tools overview (/tools).
    SUMMARIES = {
      'Translations & tafsir' => 'Read and fix translations, tafsirs and surah introductions.',
      'Mushaf & scripts' => 'Page layouts, Quran scripts and tajweed.',
      'Audio & segments' => 'Word timestamps and recitation audio.',
      'Words & grammar' => 'Word data, morphology and syntax.',
      'Ayahs & topics' => 'Repeated phrases, similar ayahs, topics and themes.',
      'Compare & check' => 'Side-by-side checks for scripts, fonts, audio and ayahs.',
    }.freeze

    FALLBACK_GROUP = 'More tools'

    # The tools the home page shows, with the catalog category that tints each one's icon.
    FEATURED = {
      'Ayah translations' => 'translation',
      'Ayah audio segments' => 'audio',
      'Word grammar and morphology' => 'linguistics',
    }.freeze

    # A group of the tools overview; `tools` are SiteNav::Link with the tool's own description.
    OverviewGroup = Data.define(:heading, :summary, :tools)

    # The tools as [heading, [[tool, icon, description], ...]] in menu order, each tool once,
    # leaving out empty groups.
    def self.grouped(tools)
      by_title = tools.index_by(&:title)
      groups = GROUPS.map do |heading, entries|
        [heading, entries.filter_map { |title, (icon, text)| [by_title[title], icon, text] if by_title[title] }]
      end
      known = GROUPS.values.flat_map(&:keys)
      groups << [FALLBACK_GROUP, tools.reject { |tool| known.include?(tool.title) }.map { |tool| [tool, nil, nil] }]
      groups.reject { |_, links| links.empty? }
    end

    def self.overview(tools)
      grouped(tools).map do |heading, entries|
        links = entries.map do |tool, icon, _|
          Link.new(label: tool.title, href: tool.url, icon:, description: tool.description)
        end
        OverviewGroup.new(heading:, summary: SUMMARIES[heading], tools: links)
      end
    end

    # FEATURED as links with their icon and menu description, leaving out a tool not in `tools`.
    def self.featured(tools)
      entries = GROUPS.values.reduce(:merge)
      by_title = tools.index_by(&:title)
      FEATURED.filter_map do |title, category|
        tool = by_title[title] or next
        icon, description = entries.fetch(title)
        Link.new(label: title, href: tool.url, icon:, description:, category:)
      end
    end
  end
end
