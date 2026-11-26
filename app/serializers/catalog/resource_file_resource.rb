# frozen_string_literal: true

module Catalog
  # A downloadable file of a resource (Catalog::ResourcePage::Download). Every file is an archive, so
  # its byte size is the download size; md5 is the stored checksum in hex. `filename` is the stored
  # file's name, which a zip of several files (lib/zip-download.ts) names its entry after.
  class ResourceFileResource < ApplicationResource
    typelize id: :number, name: :string, filename: :string, format: [:string, { enum: Taxonomy.formats.map(&:key) }],
             format_label: :string, byte_size: :number, md5: :string # rubocop:disable Naming/VariableNumber -- the prop name
    attributes :id, :name, :filename, :format, :format_label, :byte_size, :md5 # rubocop:disable Naming/VariableNumber
  end
end
