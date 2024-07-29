# == Schema Information
#
# Table name: user_downloads
#
#  id                   :bigint           not null, primary key
#  download_count       :integer          default(0)
#  last_download_at     :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  downloadable_file_id :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_user_downloads_on_downloadable_file_id  (downloadable_file_id)
#  index_user_downloads_on_user_id               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (downloadable_file_id => downloadable_files.id)
#  fk_rails_...  (user_id => users.id)
#
class UserDownload < ApplicationRecord
  belongs_to :user
  belongs_to :downloadable_file

  def increment_download!
    self.download_count = download_count.to_i + 1
    self.last_download_at = DateTime.now
    save(validate: false)
  end
end
