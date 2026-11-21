# == Schema Information
#
# Table name: downloadable_files
#
#  id                       :bigint           not null, primary key
#  anonymous_download_count :integer          default(0), not null
#  download_count           :integer          default(0)
#  file_type                :string
#  info                     :text
#  name                     :string
#  position                 :integer          default(1)
#  published                :boolean          default(TRUE)
#  token                    :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  downloadable_resource_id :bigint           not null
#
# Indexes
#
#  index_downloadable_files_on_downloadable_resource_id  (downloadable_resource_id)
#  index_downloadable_files_on_token                     (token)
#
# Foreign Keys
#
#  fk_rails_...  (downloadable_resource_id => downloadable_resources.id)
#
class DownloadableFile < ApplicationRecord
  belongs_to :downloadable_resource
  has_many :user_downloads, dependent: :destroy
  has_one_attached :file, service: Rails.env.development? ? :local : :qul_exports

  after_create :generate_token

  # Counts one download request (Catalog::DownloadsController). A signed-in download goes to the
  # user's row; an anonymous one adds 1 to anonymous_download_count in one UPDATE and stores
  # nothing about the visitor. Repeated requests count every time.
  def count_download(user)
    if user
      track_download(user)
    else
      self.class.update_counters(id, anonymous_download_count: 1)
    end
  end

  # The file row's lock makes concurrent downloads of this file wait for each other, so none is
  # lost and a user keeps one row per file.
  def track_download(user)
    with_lock do
      download = user_downloads.where(user_id: user.id).first_or_initialize
      download.downloadable_resource_id = downloadable_resource_id
      download.increment_download!

      update_columns(download_count: user_downloads.sum(:download_count))
    end
  end

  # Every counted download request of this file, signed in or anonymous. Catalog sorting reads
  # only this method.
  def total_download_count
    download_count.to_i + anonymous_download_count
  end

  protected
  def generate_token
    update_column(:token, SecureRandom.hex)
  end
end
