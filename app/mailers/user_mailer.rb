class UserMailer < ApplicationMailer
  def thank_you(user:)
    subject = 'Welcome to the Quranic Universal Library (QUL)!'
    @user = user

    mail to: @user.email, subject: subject
  end
end
