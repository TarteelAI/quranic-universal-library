class CommunityPresenter < ApplicationPresenter
  def meta_title
    case action_name
    when 'tools'
      'QUL Tools'
    when 'faq'
      'FAQ'
    when 'credits'
      'Credits'
    else
      'Quranic Universal Library'
    end
  end

  def meta_description
    case action_name
    when 'tools'
      'Free developer tools to build, proofread and manage Quran data — Tajweed, audio segments, translations, tafsir, corpus and scripts — and export it all as clean JSON.'
    when 'faq'
      'Find answers to common questions about the Quranic Universal Library'
    when 'credits'
      'Discover the people and sources behind the Quranic Universal Library. The Credits page acknowledges contributors, translators, scholars, and partners who made QUL’s Quranic resources and tools possible.'
    end
  end

  def meta_keywords
    "Quran data, Quran json data, Quran tools directory, digital Quran resources, Quran API tools, Tajweed editor, audio timestamp editor, translation proofreading, corpus analysis, Quranic developer toolkit"
  end
end
