# frozen_string_literal: true

# Finds catalog resources by name in specs. Some names on the snapshot end in stray whitespace.
module CatalogResources
  def resource_named(name)
    DownloadableResource.where("btrim(name, E' \\t\\n') = ?", name).sole
  end

  # Sets override keys in a resource's meta data, as an editor does in the CMS:
  # `override_catalog(resource, 'script-family' => 'indopak')`.
  def override_catalog(resource, keys)
    resource.update_columns(meta_data: (resource.meta_data || {}).merge(keys))
    Catalog::Derived.reset
  end
end

RSpec.configure { |config| config.include CatalogResources }
