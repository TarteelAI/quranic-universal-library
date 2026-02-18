class UploadToCdn
  def upload(file_path, object_key, content_type: 'application/json')
    bucket.object(object_key)
          .upload_file(
            file_path,
            content_type: content_type
          )

    url = "#{content_cnd_host}/#{object_key}"
    clear_cache(url)

    url
  end

  protected
  def clear_cache(url)
    CloudflareCacheClearer.new.clear_cache(urls: [url])
  rescue => e
    Sentry.capture_exception(e, extra: { url: url })
  end

  def bucket
    @bucket ||= s3_client.bucket(ENV['QUL_STORAGE_BUCKET'])
  end

  def s3_client
    @s3_client ||= Aws::S3::Resource.new(
      access_key_id: ENV['QUL_STORAGE_ACCESS_KEY'],
      secret_access_key: ENV['QUL_STORAGE_ACCESS_KEY_SECRET'],
      region: ENV['QUL_STORAGE_REGION'],
      endpoint: ENV['QUL_STORAGE_ENDPOINT'],
      force_path_style: true
    )
  end

  def content_cnd_host
    ENV['CDN_HOST']
  end
end