# frozen_string_literal: true

module Start
  # The Quran script a script family of the guided setup shows as its sample (a
  # DownloadableResource): what the page needs to fetch its card preview.
  class ScriptSampleResource < ApplicationResource
    typelize id: :number, type: :string, to_param: :string
    attributes :id, :to_param
    attribute(:type, &:resource_type)

    typelize preview_kind: [:string, { nullable: true, enum: Previews::Card::KINDS.values.uniq }]
    attribute(:preview_kind) { |resource| Previews::Card.kind(resource.resource_type) }
  end
end
