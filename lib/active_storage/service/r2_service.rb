# frozen_string_literal: true

require 'active_storage/service/s3_service'

module ActiveStorage
  # An S3 service whose public links start at a public host (`public_host:` in
  # config/storage.yml) instead of the storage endpoint. Cloudflare R2's S3 endpoint never
  # serves anonymous reads, so a public bucket is read through its own host. Without a
  # public host it is S3Service unchanged. Signed links still use the endpoint.
  class Service::R2Service < Service::S3Service
    def initialize(public_host: nil, **options)
      super(**options)
      @public_host = public_host.to_s.strip.delete_suffix('/').presence
    end

    private

    def public_url(key, **client_opts)
      return super unless @public_host

      # Escaped per segment, as Aws::S3::Object#public_url does.
      path = key.split('/').map { |segment| Seahorse::Util.uri_escape(segment) }.join('/')
      "#{@public_host}/#{path}"
    end
  end
end
