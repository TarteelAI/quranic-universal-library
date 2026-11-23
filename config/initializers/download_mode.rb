# An unknown QUL_DOWNLOAD_MODE stops the boot instead of failing the first download.
Rails.application.config.after_initialize { DownloadMode.current }
