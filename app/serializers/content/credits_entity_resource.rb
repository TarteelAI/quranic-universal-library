# frozen_string_literal: true

module Content
  # A person or project named in an acknowledgement, with its link when it has one.
  class CreditsEntityResource < ApplicationResource
    typelize name: :string, url: [:string, { nullable: true }]
    attributes :name, :url
  end
end
