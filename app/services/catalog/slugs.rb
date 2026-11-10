# frozen_string_literal: true

module Catalog
  # Slugs are public URLs and API ids, so they are readable and, once set, never change.
  module Slugs
    module_function

    # The first free slug among: the display name, the display name plus the type, then that
    # with a counter. A slug is never all digits. The block answers whether a slug is taken.
    def generate(resource, &taken)
      base = resource.display_name.to_s.parameterize.presence || resource.resource_type.to_s
      typed = [base, resource.resource_type].compact.uniq.join('-')
      candidates = [base, typed].reject { |slug| slug.match?(/\A\d+\z/) }.uniq

      candidates.find { |slug| !taken.call(slug) } ||
        (2..).lazy.map { |n| "#{typed}-#{n}" }.find { |slug| !taken.call(slug) }
    end
  end
end
