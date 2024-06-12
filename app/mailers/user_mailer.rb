class UserMailer < ApplicationMailer
  def thank_you(user:)
    subject = 'Thank you for signing up!'
    @user = user

    mail to: @user.email, subject: subject
  end
end
