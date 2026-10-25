require 'digest'

# The version we publish for an audio asset has to track the bytes we ship, not
# the database row. `updated_at` moves whenever anything touches the record - a
# meta refresh, a segment re-run, an admin fixing a file name - and publishing
# that as the version makes every client re-download a file that never changed.
#
# So we keep a fingerprint of the audio itself and only move `content_version`
# when the fingerprint moves. Admins can still override the version by hand, for
# the cases the fingerprint can't see (same size, same duration, new recording).
module AudioContentVersioning
  extend ActiveSupport::Concern

  # Probed values that change when the audio bytes change.
  FINGERPRINT_KEYS = %i[size_bytes duration_ms bitrate sample_rate].freeze

  FINGERPRINT_SOURCE = 'fingerprint'
  MANUAL_SOURCE = 'manual'

  def self.fingerprint(meta)
    values = FINGERPRINT_KEYS.map { |key| meta[key] }
    return nil if values.all? { |value| value.to_s.strip.empty? }

    Digest::SHA256.hexdigest(values.map(&:to_s).join('|'))
  end

  def published_version
    content_version.to_i.positive? ? content_version.to_i : (updated_at || Time.current).to_i
  end

  def content_version_overridden?
    content_version_source == MANUAL_SOURCE
  end

  def sync_content_version(meta)
    new_hash = AudioContentVersioning.fingerprint(meta)
    return false if new_hash.blank?

    new_etag = meta[:etag].presence
    previous_version = published_version
    # First time we look at a file we have nothing to compare against, so we
    # keep the version clients are already holding instead of inventing a change.
    first_look = content_hash.blank?

    # The CDN's etag is the exact content hash, so it decides whenever we have
    # one from both checks. A missing etag - a HEAD that timed out, a host that
    # doesn't send one - never counts as a change on its own.
    changed = if new_etag.present? && content_etag.present?
                new_etag != content_etag
              else
                new_hash != content_hash
              end

    self.content_hash = new_hash
    self.content_etag = new_etag if new_etag.present?

    return false unless first_look || changed

    self.content_version = first_look ? previous_version : content_version.to_i + 1
    self.content_updated_at = Time.current
    self.content_version_source = FINGERPRINT_SOURCE

    content_version.to_i != previous_version
  end

  def bump_content_version!
    override_content_version!(published_version + 1)
  end

  def override_content_version!(version)
    version = version.to_i
    return false unless version.positive?

    self.content_version = version
    self.content_updated_at = Time.current
    self.content_version_source = MANUAL_SOURCE

    save(validate: false)
  end
end
