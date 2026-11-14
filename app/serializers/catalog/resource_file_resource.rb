# frozen_string_literal: true

module Catalog
  # A downloadable file of a resource (Catalog::ResourcePage::Download). Every file is an archive, so
  # its byte size is the download size; md5 is the stored checksum in hex.
  class ResourceFileResource < ApplicationResource
    typelize id: :number, name: :string, format: [:string, { enum: Taxonomy.formats.map(&:key) }],
             format_label: :string, byte_size: :number, md5: :string
    attributes :id, :name, :format, :format_label, :byte_size, :md5
  end
end
