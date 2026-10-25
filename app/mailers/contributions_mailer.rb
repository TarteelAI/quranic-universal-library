class ContributionsMailer < ApplicationMailer
  helper_method :review_url

  # counts: { translations: 3, tafsirs: 1, ... }, keys match the cms draft pages
  def pending_digest(user, counts)
    @user = user
    @counts = counts.select { |_, count| count.positive? }
    @total = @counts.values.sum
    @subject = "#{@total} #{'suggestion'.pluralize(@total)} waiting for review on QUL"

    mail to: user.email, subject: @subject
  end

  private

  def review_url(type)
    url_for(controller: "cms/draft_#{type}", action: :index, scope: 'pending_contributions')
  end
end
