module AnalyticHelper
  def generate_event_data(name, category, label = nil, value = nil)
    {
      event: name,
      'event-category': category,
      'event-label': label,
      'event-value': value || 1
    }
  end
end