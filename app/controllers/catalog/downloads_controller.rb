# frozen_string_literal: true

module Catalog
  # File downloads, on the slug URL /resources/:type/:slug/download/:file_id and on the old token
  # URL /resources/:type/:token/download, with the same rules on both:
  # - an unpublished file, a file of an unpublished resource or a file without a blob is a 404;
  # - a restricted resource (DownloadableResource#restrict_download?) is blocked except for admins;
  # - in download mode `sign_in` an anonymous request goes to sign-in, which returns to the
  #   resource page with `?download=<file id>` (to the download itself while the catalog page
  #   group is off); in `public` mode the file is sent to anyone.
  # The file is a redirect to its storage URL. A GET counts the download
  # (DownloadableFile#count_download); a HEAD does not.
  #
  # An anonymous request leaves nothing in the browser: its session is not written back (reading
  # it for Devise would otherwise reissue an existing session cookie) and no XSRF cookie is set.
  # Every response is noindex (robots.txt also disallows both URLs).
  class DownloadsController < ApplicationController
    include ActiveStorage::SetCurrent

    before_action do
      response.headers['X-Robots-Tag'] = 'noindex'
      request.session_options[:skip] = true unless user_signed_in?
    end

    def show
      resource = DownloadableResource.find_by!(resource_type: params[:type], slug: params[:slug])
      send_download resource.downloadable_files.find(params[:file_id])
    end

    def token
      send_download DownloadableFile.find_by!(token: params[:token])
    end

    private

    def send_download(file)
      resource = file.downloadable_resource
      raise ActiveRecord::RecordNotFound unless file.published? && resource.published? && file.file.attached?
      return render(plain: 'This resource is not available for download.', status: :forbidden) if blocked?(resource)

      if current_user.nil? && !DownloadMode.public?
        return redirect_to new_user_session_path(user_return_to: sign_in_return_path(resource, file))
      end

      file.count_download(current_user) unless request.head?
      redirect_to file.file.url, allow_other_host: true
    end

    def blocked?(resource)
      resource.restrict_download? && !(current_user&.is_admin? || current_user&.is_super_admin?)
    end

    # The new resource page starts the download from `?download=`. The old page does not, so with
    # the catalog group off sign-in returns to the download URL itself, as it always has.
    def sign_in_return_path(resource, file)
      return request.fullpath unless PageGroups.enabled?(:catalog)

      detail_resources_path(type: resource.resource_type, id: resource.to_param, download: file.id)
    end

    # GET only, and nothing here renders a form, so no CSRF token (and no XSRF cookie) is needed.
    def protect_against_forgery?
      false
    end
  end
end
