# == Schema Information
#
# Table name: admin_users
#
#  id                     :integer          not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :inet
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  failed_attempts        :integer          default(0), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :inet
#  locked_at              :datetime
#  name                   :string
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
#  index_admin_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_admin_users_on_email                 (email) UNIQUE
#  index_admin_users_on_reset_password_token  (reset_password_token) UNIQUE
#  index_admin_users_on_unlock_token          (unlock_token) UNIQUE
#

class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, 
         :recoverable,
         :rememberable,
         :trackable,
         :validatable

  def to_s
    "#{id} - #{name || email}"
  end

  def super_admin?
    #TODO: add column in the table and allow the first admin user to manage super admins
    [1, 2].include? id
  end

  def find_or_create_user_account
    User.find_or_create_by(email: email) do |user|
      fist, last = name.split(' ')
      user.first_name = fist
      user.last_name = last.presence || 'Missing'
      user.approved = true
      user.password = Devise.friendly_token.first(8)
      user.skip_confirmation!
      user.save!
    end
  end

  def admin?
    true
  end

  #TODO: Add a column in the table to manage moderators
  def moderator?
    [
      31, #Br Yemin( Greentech)
      33, # Golam Kader( Greentech)
      40, # Shakeel
      135 #Tuba
    ].include?(id)
  end
end
