class CommunityPresenter < ApplicationPresenter
  def meta_title
    "QUL Tools"
  end

  def meta_description
    case action_name
    when 'tools'
      'Explore a variety of developer tools designed to manage Quranic content.'
    when 'faq'
      'Find answers to common questions about the Quranic Universal Library'
    when 'credits'
      'Discover the people and sources behind the Quranic Universal Library. The Credits page acknowledges contributors, translators, scholars, and partners who made QUL’s Quranic resources and tools possible.'
    end
  end

  def meta_keywords
    "Quran tools directory, digital Quran resources, Quran API tools, Tajweed editor, audio timestamp editor, translation proofreading, corpus analysis, Quranic developer toolkit"
  end
end
