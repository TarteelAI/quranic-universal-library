# Crawlers and scanners hit paginated pages with junk in ?page= (URLs, null
# bytes), which Pagy rejects with a Pagy::VariableError and a 500. Include this
# and opt the paginated actions in:
#
#   before_action :normalize_page_param, only: %i[index]
module NormalizesPageParam
  extend ActiveSupport::Concern

  protected

  # Anything that isn't a positive number is treated as the first page.
  def normalize_page_param
    return if params[:page].blank?

    page = params[:page].to_s[/\A\d+/].to_i
    params[:page] = page.positive? ? page : 1
  end
end
