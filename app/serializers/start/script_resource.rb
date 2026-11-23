# frozen_string_literal: true

module Start
  # A script family of the guided setup (GuidedSetup::Script), with a Quran script of the family
  # as its sample: the script the home page's script card shows for the family (Catalog::Samples,
  # whose labels are the families' keys), as its card preview, while the `catalog` group serves
  # previews.
  class ScriptResource < ApplicationResource
    typelize key: :string, label: :string, blurb: :string
    attributes :key, :label, :blurb

    typelize sample: { nullable: true }
    one :sample, resource: ScriptSampleResource, source: proc {
      next unless PageGroups.enabled?(:catalog)

      Catalog::Samples.new.scripts.find { |label, _script| label.casecmp?(key) }&.last
    }
  end
end
