# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  about_me               :text
#  add_to_mailing_list    :boolean          default(FALSE)
#  approved               :boolean          default(FALSE)
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  first_name             :string
#  last_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  locked_at              :datetime
#  projects               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :integer          default("normal_user")
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  unlock_token           :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_users_on_unlock_token          (unlock_token) UNIQUE
#

class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :lockable,
         :rememberable,
         :trackable,
         :validatable,
         :recoverable
         :confirmable

  validates :first_name,
            :last_name,
            presence: true,
            length: { maximum: 50 },
            format: { with: /\A[\p{L}\p{M}'\- ]+\z/u, message: 'contains invalid characters' }

  has_many :user_projects
  has_many :user_downloads

  after_create :send_welcome_email

  enum role: {
    normal_user: 0,
    super_admin: 1,
    admin: 2,
    moderator: 3,
    contributor: 4,
  }, _prefix: 'is'

  def super_admin?
    1 == id || is_super_admin?
  end

  def name
    short_name = first_name.presence || last_name.presence || email
    short_name.to_s.humanize
  end

  def humanize_name
    "#{name}(#{email})"
  end

  def send_welcome_email
    UserMailer.thank_you(
      user: self
    ).deliver_later
  end

  def self.ransackable_attributes(auth_object = nil)
    ["id", "email", "first_name", "last_name", "confirmation_sent_at", "confirmed_at", "created_at", "failed_attempts", "locked_at", "remember_created_at", "reset_password_sent_at", "sign_in_count", "unconfirmed_email", "updated_at", "approved"]
  end
end
