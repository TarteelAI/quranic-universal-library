module BootstrapDeviseHelper
  def bootstrap_devise_error_messages!
    return '' if resource.errors.empty?
    
    messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join
    sentence = I18n.t('errors.messages.not_saved',
                      count: resource.errors.count,
                      resource: resource.class.model_name.human.downcase)
    
    html = <<-HTML
    <div class="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded mb-4 relative">
      <button type="button" class="absolute top-2 right-2 text-red-400 hover:text-red-600 transition-colors p-1" onclick="this.parentElement.remove()">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </button>
      <h5 class="font-semibold mb-2">#{sentence}</h5>
      <ul class="list-disc list-inside space-y-1">#{messages}</ul>
    </div>
    HTML
    
    html.html_safe
  end
end
