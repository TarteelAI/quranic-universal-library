# frozen_string_literal: true

module Catalog
  # Slugs are public URLs and API ids, so they are readable and, once set, never change.
  module Slugs
    module_function

    # The first free slug among: the name, the name plus the type, then that with a counter. A
    # slug is never all digits. The block answers whether a slug is taken.
    def generate(name, type)
      base = name.to_s.parameterize.presence || type.to_s
      typed = [base, type].compact.uniq.join('-')
      candidates = [base, typed].grep_v(/\A\d+\z/).uniq

      candidates.find { |slug| !yield(slug) } ||
        (2..).lazy.map { |n| "#{typed}-#{n}" }.find { |slug| !yield(slug) }
    end
  end
end
