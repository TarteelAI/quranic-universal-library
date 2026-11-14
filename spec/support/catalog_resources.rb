# Finds catalog resources by name in specs. Some names on the snapshot end in stray whitespace.
module CatalogResources
  def resource_named(name)
    DownloadableResource.where("btrim(name, E' \\t\\n') = ?", name).sole
  end
end

RSpec.configure { |config| config.include CatalogResources }
