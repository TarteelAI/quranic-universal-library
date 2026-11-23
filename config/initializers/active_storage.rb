# frozen_string_literal: true

# Lifetime of signed links to private files. SigV4 allows at most 7 days. Set on the config:
# Active Storage copies it into ActiveStorage.service_urls_expire_in after initialization.
Rails.application.config.active_storage.service_urls_expire_in = 1.day

# The custom service (lib/active_storage/service/r2_service.rb) is required by name when
# config/storage.yml is read, not autoloaded.
Rails.autoloaders.main.ignore(Rails.root.join('lib', 'active_storage'))
