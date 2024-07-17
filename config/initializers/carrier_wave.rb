require 'fog/aws'
require 'carrierwave/storage/fog'

CarrierWave.configure do |config|
  if %[development test].include?(Rails.env)
    config.storage = :file
  else
    config.storage = :fog
    config.fog_provider = 'fog/aws'                        # required
  
    config.fog_credentials = {
      provider:              'AWS',                        # required
      aws_access_key_id:     ENV.fetch('AWS_ACCESS_KEY'){'missing'},        # required unless using use_iam_profile
      aws_secret_access_key: ENV.fetch('AWS_ACCESS_KEY_SECRET'){'missing'}, # required unless using use_iam_profile
      use_iam_profile:       false,                         # optional, defaults to false
      region:                'us-east-2'            # us-east (ohio)
    }

    config.fog_directory  = ENV.fetch('DB_BACK_BUCKET'){'db-backups'}            # required
    config.fog_public     = false                                                 # optional, defaults to true
    config.fog_attributes = { cache_control: "public, max-age=#{2.days.to_i}" } # optional, defaults to {}
  end
end

