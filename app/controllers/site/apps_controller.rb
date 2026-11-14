# frozen_string_literal: true

module Site
  # /apps, the directory of apps built with QUL, while the `apps` page group is on (PageGroups).
  # There is no old page: with the group off the path is a 404. The filters are in the query
  # string (`platform`, `type`); a value no app can have is dropped.
  class AppsController < InertiaController
    def index
      @apps = AppDirectory.apps
      @filters = AppDirectory.filters(platform: params[:platform], type: params[:type])

      render_inertia 'site/AppsPage', meta: page_meta(
        title: 'Apps built with QUL',
        description: 'Quran readers, study apps, libraries and tools whose makers credit the Quranic Universal ' \
                     'Library for their data.',
        json_ld: {
          '@type': 'CollectionPage',
          isPartOf: { '@type': 'WebSite', name: PageMeta::SITE_NAME, url: SeoHelper::HOST }
        }
      )
    end
  end
end
