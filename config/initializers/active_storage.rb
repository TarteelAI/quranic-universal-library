ActiveStorage.service_urls_expire_in = 2.weeks
# QUL never uses browser direct uploads, disable that route
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action { head :not_found }
end