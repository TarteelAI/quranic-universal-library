# frozen_string_literal: true

module Start
  # A platform of the guided setup (GuidedSetup::Platform).
  class PlatformResource < ApplicationResource
    typelize key: :string, label: :string, hint: :string
    attributes :key, :label, :hint
  end
end
