# frozen_string_literal: true

module Account
  # A change the user made to the data. `path` is the changed row in the CMS, when it has a page.
  class ContributionResource < ApplicationResource
    typelize id: :number, icon: :string, type: :string, label: :string, reference: [:string, { nullable: true }],
             path: [:string, { nullable: true }], date: :string
    attributes :id, :icon, :type, :label, :reference, :path, :date
  end
end
