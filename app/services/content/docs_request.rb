# frozen_string_literal: true

module Content
  # Route constraint for the new docs page at /docs/:key (inside the `content` page group). The
  # old pages' help dialogs (ajax-modal) fetch /docs/:key with `fetch` (Accept */*) and read
  # #title and #body out of the old page, and other old code asks for it as XHR to get the
  # layout-free fragment. Those requests, and keys that only an ERB partial under app/views/docs
  # serves (help dialog text), keep the old answer. The new page answers page loads (Accept
  # names text/html) and Inertia visits.
  module DocsRequest
    PARTIALS = Rails.root.join('app', 'views', 'docs')
    KEY = /\A[a-z0-9_-]+\z/

    def self.matches?(request)
      page_request?(request) && !partial_only?(request.path_parameters[:key].to_s)
    end

    def self.page_request?(request)
      return true if request.headers['X-Inertia'].present?

      !request.xhr? && request.headers['Accept'].to_s.include?('text/html')
    end

    def self.partial_only?(key)
      key.match?(KEY) && PARTIALS.join("_#{key}.html.erb").file? && !DocsPageService::DOCS_DIR.join("#{key}.md").file?
    end
  end
end
