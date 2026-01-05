module BootstrapDeviseHelper
  def bootstrap_devise_error_messages!
    return '' if resource.errors.empty?
    
    messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join
    sentence = I18n.t('errors.messages.not_saved',
                      count: resource.errors.count,
                      resource: resource.class.model_name.human.downcase)
    
    html = <<-HTML
    <div class="tw-bg-red-50 tw-border tw-border-red-200 tw-text-red-800 tw-px-4 tw-py-3 tw-rounded tw-mb-4 tw-relative">
      <button type="button" class="tw-absolute tw-top-2 tw-right-2 tw-text-red-400 hover:tw-text-red-600 tw-transition-colors tw-p-1" onclick="this.parentElement.remove()">
        <svg class="tw-w-5 tw-h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      </button>
      <h5 class="tw-font-semibold tw-mb-2">#{sentence}</h5>
      <ul class="tw-list-disc tw-list-inside tw-space-y-1">#{messages}</ul>
    </div>
    HTML
    
    html.html_safe
  end
end
