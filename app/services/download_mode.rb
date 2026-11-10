# frozen_string_literal: true

# The download mode setting, QUL_DOWNLOAD_MODE, for Catalog::DownloadsController:
# `sign_in` (the default) sends an anonymous download to sign-in first, `public` sends the file
# without an account. Read on every request like PageGroups (a restart picks up a change);
# config/initializers/download_mode.rb fails the boot on an unknown value.
module DownloadMode
  MODES = %w[sign_in public].freeze

  class UnknownMode < StandardError; end

  def self.current
    mode = ENV['QUL_DOWNLOAD_MODE'].presence || 'sign_in'
    return mode if MODES.include?(mode)

    raise UnknownMode, "QUL_DOWNLOAD_MODE is #{mode.inspect}; use one of #{MODES.join(', ')}"
  end

  def self.public?
    current == 'public'
  end
end
