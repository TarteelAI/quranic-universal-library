# frozen_string_literal: true

module Start
  # A goal of the guided setup (GuidedSetup::Goal), with the features it starts with.
  class GoalResource < ApplicationResource
    typelize key: :string, label: :string, blurb: :string, features: [:string, { multi: true }]
    attributes :key, :label, :blurb, :features
  end
end
