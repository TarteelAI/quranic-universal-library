# frozen_string_literal: true

module Previews
  # The preview of a mushaf layout (Previews::MushafLayout): one page.
  class MushafLayoutResource < ApplicationResource
    typelize kind: [:string, { enum: %w[layout] }]
    attribute(:kind) { 'layout' }

    one :page, resource: MushafPageResource
  end
end
