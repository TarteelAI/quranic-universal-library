# frozen_string_literal: true

module Content
  # One acknowledgement of ApplicationHelper#contributors: one entity, or several (`multiple`)
  # thanked together, and what they are thanked for.
  class CreditsAcknowledgementResource < ApplicationResource
    typelize description: :string
    attributes :description

    many :entities, resource: CreditsEntityResource, source: proc { self[:multiple] || [slice(:name, :url)] }
  end
end
