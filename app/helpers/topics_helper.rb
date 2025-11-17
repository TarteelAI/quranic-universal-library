# frozen_string_literal: true

module TopicsHelper
  def topic_type_badges(topic)
    badges = []
    
    if topic.ontology?
      badges << content_tag(:span, 'Ontology', 
        class: 'tw-bg-blue-100 tw-text-blue-800 tw-text-xs tw-font-medium tw-px-2 tw-py-1 tw-rounded')
    end
    
    if topic.thematic?
      badges << content_tag(:span, 'Thematic', 
        class: 'tw-bg-green-100 tw-text-green-800 tw-text-xs tw-font-medium tw-px-2 tw-py-1 tw-rounded')
    end
    
    if !topic.ontology? && !topic.thematic?
      badges << content_tag(:span, 'General', 
        class: 'tw-bg-purple-100 tw-text-purple-800 tw-text-xs tw-font-medium tw-px-2 tw-py-1 tw-rounded')
    end
    
    safe_join(badges, ' ')
  end

  def topic_background_color(topic)
    if topic.ontology?
      'tw-bg-blue-50 tw-border-blue-200'
    elsif topic.thematic?
      'tw-bg-green-50 tw-border-green-200'
    else
      'tw-bg-purple-50 tw-border-purple-200'
    end
  end

  def highlight_topic_name_in_text(text, topic_name)
    return text if text.blank? || topic_name.blank?
    
    text.gsub(
      /(#{Regexp.escape(topic_name)})/i,
      '<mark class="tw-bg-yellow-200 tw-text-green-600 tw-px-1 tw-rounded">\1</mark>'
    )
  end

  def render_topic_word(word, is_highlighted)
    css_class = if is_highlighted
      'tw-bg-yellow-200 tw-text-green-600 tw-font-bold tw-px-1 tw-py-0.5 tw-rounded'
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
    
    arrow_class = is_active ? 'tw-text-blue-600' : 'tw-text-gray-400'
    
    link_to url, class: "tw-inline-flex tw-items-center tw-gap-1 hover:tw-text-blue-600 #{extra_classes}", style: 'text-decoration: none;' do
      concat title
      concat ' '
      concat content_tag(:span, '⇅', class: arrow_class)
    end
  end
end

