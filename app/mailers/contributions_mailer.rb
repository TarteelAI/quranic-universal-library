class ContributionsMailer < ApplicationMailer
  # counts: { translations: 3, tafsirs: 1 }
  def pending_digest(user, counts)
    @user = user
    @counts = counts
    @total = counts.values.sum
    @subject = "#{@total} #{'suggestion'.pluralize(@total)} waiting for review on QUL"

    mail to: user.email, subject: @subject
  end
end
