# frozen_string_literal: true

# Props every Inertia page receives (InertiaController.inertia_share). The site navigation is a
# once prop: the browser keeps it after the first page and later visits do not resend it.
class SharedPropsResource < ApplicationResource
  one :auth, resource: AuthResource
  one :nav, resource: SiteNavResource, inertia: :once
end
