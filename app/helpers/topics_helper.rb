# frozen_string_literal: true

module TopicsHelper
  def topic_type_badges(topic)
    badges = []
    
    if topic.ontology?
      badges << content_tag(:span, 'Ontology', 
        class: 'bg-blue-100 text-blue-800 text-xs font-medium px-2 py-1 rounded')
    end
    
    if topic.thematic?
      badges << content_tag(:span, 'Thematic', 
        class: 'bg-green-100 text-green-800 text-xs font-medium px-2 py-1 rounded')
    end
    
    if !topic.ontology? && !topic.thematic?
      badges << content_tag(:span, 'General', 
        class: 'bg-purple-100 text-purple-800 text-xs font-medium px-2 py-1 rounded')
    end
    
    safe_join(badges, ' ')
  end

  def topic_background_color(topic)
    if topic.ontology?
      'bg-blue-50 border-blue-200'
    elsif topic.thematic?
      'bg-green-50 border-green-200'
    else
      'bg-purple-50 border-purple-200'
    end
  end

  def highlight_topic_name_in_text(text, topic_name)
    return text if text.blank? || topic_name.blank?
    
    text.gsub(
      /(#{Regexp.escape(topic_name)})/i,
      '<mark class="bg-yellow-200 text-green-600 px-1 rounded">\1</mark>'
    )
  end

  def render_topic_word(word, is_highlighted)
    css_class = if is_highlighted
      'bg-yellow-200 text-green-600 font-bold px-1 py-0.5 rounded'
    else
      ''
    end

    content_tag(:span, word.text_qpc_hafs, class: css_class)
  end

  def sortable_column_header(title, column, resource, current_sort, current_direction, search_query, extra_classes: '')
    new_direction = (current_sort == column && current_direction == 'asc') ? 'desc' : 'asc'
    is_active = current_sort == column
    
    url = detail_resources_path('ayah-topics', resource.id, 
                                 sort_by: column, 
                                 sort_direction: new_direction,
                                 search: search_query)
    
    arrow_class = is_active ? 'text-blue-600' : 'text-gray-400'
    
    link_to url, class: "inline-flex items-center gap-1 hover:text-blue-600 #{extra_classes}", style: 'text-decoration: none;' do
      concat title
      concat ' '
      concat content_tag(:span, '⇅', class: arrow_class)
    end
  end
end

