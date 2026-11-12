# frozen_string_literal: true

module Content
  # One part of a docs body: `html` is prose the server sanitized (Content::DocPage); `code` and
  # `playground` (a runnable example) are plain text with the language and its label.
  class DocSegmentResource < ApplicationResource
    typelize kind: [:string, { enum: %w[html code playground] }], html: [:string, { nullable: true }],
             language: [:string, { nullable: true }], label: [:string, { nullable: true }],
             code: [:string, { nullable: true }]
    attributes :kind, :html, :language, :label, :code
  end
end
