# == Schema Information
#
# Table name: contributors
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string
#  published   :boolean          default(TRUE)
#  url         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Contributor < ApplicationRecord
  scope :published, -> { where(published: true) }

  has_one_attached :logo, service: Rails.env.development? ? :local : :qul_exports

  def attach_logo(io:, filename:)
    key = "contributors/#{SecureRandom.base36(5)}/#{filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      key: key,
      service_name: Rails.env.development? ? :local : :qul_exports
    )

    self.logo.attach(blob)
  end
end
