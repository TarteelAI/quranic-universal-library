# frozen_string_literal: true

module Dev
  # The sample page that proves the Inertia stack. Its routes (config/routes.rb) exist in
  # development and test, and in production only with QUL_INERTIA_SAMPLE_PAGE=true.
  class InertiaSamplesController < InertiaController
    def show
      @heading = 'Inertia sample page'

      render_inertia 'dev/InertiaSample', meta: sample_meta_tags
    end

    def create
      redirect_to dev_inertia_sample_path, notice: 'The form was received.'
    end

    def ping
      render json: SharedPropsResource.new({ signed_in: user_signed_in? }).serializable_hash
    end

    private

    def sample_meta_tags
      title = 'Inertia sample - QUL'
      description = 'A development page for the Inertia, React and Vite setup.'
      url = "https://qul.tarteel.ai#{dev_inertia_sample_path}"

      [
        { title: title },
        { name: 'description', content: description },
        { tag_name: 'link', rel: 'canonical', href: url },
        { property: 'og:title', content: title },
        { property: 'og:description', content: description },
        { property: 'og:url', content: url },
        {
          tag_name: 'script',
          type: 'application/ld+json',
          inner_content: { '@context': 'https://schema.org', '@type': 'WebPage', name: title, url: url }
        }
      ]
    end
  end
end
