# frozen_string_literal: true

module Account
  # The number of rows in each tab of the profile page. `requests` is null while the `requests`
  # page group is off: the tab does not exist then.
  class CountsResource < ApplicationResource
    typelize downloads: :number, contributions: :number, resources: :number,
             requests: [:number, { nullable: true }]
    attributes :downloads, :contributions, :resources, :requests
  end
end
