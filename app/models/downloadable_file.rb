# == Schema Information
#
# Table name: downloadable_files
#
#  id                       :bigint           not null, primary key
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

  def track_download(user)
    download = user_downloads.where(user_id: user.id).first_or_initialize
    download.increment_download!

    update_columns(download_count: user_downloads.sum(:download_count))
  end

  protected
  def generate_token
    update_column(:token, SecureRandom.hex)
  end
end
