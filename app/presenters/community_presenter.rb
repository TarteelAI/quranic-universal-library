class CommunityPresenter < ApplicationPresenter
  DOCS_INDEX_DESCRIPTION = "Everything you need to download QUL resources, integrate them in your app, and contribute back to the project — datasets, data models, tutorials and API reference.".freeze

  def meta_title
    case action_name
    when 'tools'
      'QUL Tools'
    when 'faq'
      'FAQ'
    when 'credits'
      'Credits'
    when 'docs_index'
      'QUL Documentation — Guides, Datasets & API Reference'
    when 'docs'
      docs_meta_title
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
    when 'docs_index'
      DOCS_INDEX_DESCRIPTION
    when 'docs'
      docs_meta_description
    end
  end

  def meta_keywords
    "Quran data, Quran json data, Quran tools directory, digital Quran resources, Quran API tools, Tajweed editor, audio timestamp editor, translation proofreading, corpus analysis, Quranic developer toolkit"
  end

  private

  def docs_meta_title
    title = docs_page&.title.presence || docs_tag&.name.presence
    segments = [title, docs_category&.title].compact.uniq
    segments << 'QUL Documentation'
    segments.join(' — ')
  end

  def docs_meta_description
    docs_page&.description.presence ||
      docs_tag&.description.presence ||
      docs_category&.description.presence ||
      DOCS_INDEX_DESCRIPTION
  end

  def docs_page
    context.instance_variable_get(:@docs_page)
  end

  def docs_category
    context.instance_variable_get(:@docs_category)
  end

  def docs_tag
    context.instance_variable_get(:@docs_tag)
  end
end
