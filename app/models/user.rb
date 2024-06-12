# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  about_me               :text
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
  devise :database_authenticatable, :registerable, :lockable,
         :rememberable, :trackable, :validatable, :recoverable

  validates :first_name, :last_name, presence: true

  has_many :user_projects

  after_create :send_welcome_email

  def active_for_authentication?
    if created_at > 1.day.ago
      true
    else
      approved?
    end
  end

  def admin?
    1 == id && approved?
  end

  def moderator?
    false
  end

  def super_admin?
    1 == id && approved?
  end

  def name
    short_name = first_name.presence || last_name.presence || email
    short_name.to_s.humanize
  end

  def send_welcome_email
    UserMailer.thank_you(
      user: self
    ).deliver_later
  end
end
