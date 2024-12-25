class UserMailer < ApplicationMailer
  def thank_you(user:)
    @subject = 'Welcome to QUL – JazakAllah Khair for Joining Our Community'
    @user = user

    mail to: @user.email, subject: @subject
  end
end
