require 'digest'

# Per-asset versions for the files we publish in the Tarteel asset manifest.
#
# The exported version used to be `Time.now.to_i`, stamped on the resource on
# every export run, so re-exporting unchanged data told every client to download
# everything again. Worse, `segments` and `audio` read that same number, so
# fixing one segment invalidated the mp3s along with it.
#
# Each exported file now carries its own version, derived from the bytes we
# actually upload, and it only moves when those bytes move.
module ExportedAssetVersioning
  extend ActiveSupport::Concern

  # What the resource used to publish for every asset at once. Still read as the
  # starting point for an asset we have never hashed, so switching over doesn't
  # look like a change to clients.
  LEGACY_VERSION_KEY = 'exported-version'

  def exported_asset_version(asset)
    version = meta_value(exported_asset_key(asset, 'version')).to_i
    version.positive? ? version : meta_value(LEGACY_VERSION_KEY).to_i
  end

  def exported_asset_size(asset)
    meta_value(exported_asset_key(asset, 'size-bytes'))
  end

  # Assigns (does not save) the version for one exported file. Returns true when
  # the published version moved.
  def sync_exported_asset_version(asset, content)
    digest = Digest::SHA256.hexdigest(content)
    previous_digest = meta_value(exported_asset_key(asset, 'hash'))
    previous_version = exported_asset_version(asset)

    set_meta_value(exported_asset_key(asset, 'size-bytes'), content.bytesize)
    return false if digest == previous_digest

    # First export of this asset: we have nothing to compare against, so we keep
    # the version clients already hold instead of inventing a change.
    version = if previous_digest.blank?
                previous_version.positive? ? previous_version : Time.now.to_i
              else
                previous_version + 1
              end

    set_meta_value(exported_asset_key(asset, 'hash'), digest)
    set_meta_value(exported_asset_key(asset, 'version'), version)
    set_meta_value(exported_asset_key(asset, 'at'), Time.now.to_i)

    version != previous_version
  end

  protected

  def exported_asset_key(asset, suffix)
    "exported-#{asset}-#{suffix}"
  end
end
