# == Schema Information
#
# Table name: downloadable_files
#
#  id                       :bigint           not null, primary key
#  download_count           :integer          default(0)
#  file_type                :string
#  name                     :string
#  position                 :integer          default(1)
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
  has_one_attached :file, service: :public_resource_exports

  after_create :generate_token

  protected
  def generate_token
    update_column(:token, SecureRandom.hex)
  end
end
