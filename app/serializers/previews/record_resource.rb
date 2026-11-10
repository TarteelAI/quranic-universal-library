# frozen_string_literal: true

module Previews
  # One record of a records preview: Arabic text, plain text, sanitized HTML (`truncated` when
  # cut) and short tags, any of which may be absent.
  class RecordResource < ApplicationResource
    typelize key: :string, label: :string, arabic: [:string, { nullable: true }], text: [:string, { nullable: true }],
             html: [:string, { nullable: true }], truncated: :boolean, tags: [:string, { multi: true }]
    attributes :key, :label, :arabic, :text, :html, :truncated, :tags
  end
end
