# frozen_string_literal: true

module Requests
  # Resource requests (`requests` page group). GET /requests is the public list, by votes or by
  # date, 20 to a page. POST /requests creates one, POST /requests/:id/vote votes and
  # DELETE /requests/:id/vote takes the vote back: each write needs a signed-in user, goes back to
  # the page it came from and enqueues nothing.
  class RequestsController < InertiaController
    before_action :require_sign_in, except: :index

    def index
      # At most 9 digits: a larger page would overflow the query's OFFSET before the range check.
      number = params[:page].nil? ? 1 : params[:page].to_s[/\A\d{1,9}\z/].to_i
      list = ListQuery.new(sort: params[:sort], page: number, user: current_user).call
      raise ActiveRecord::RecordNotFound unless number.between?(1, list.pages)

      render_inertia 'requests/RequestsPage', locals: list.to_h, meta: page_meta(
        title: 'Resource requests - QUL',
        description: 'Resources people have asked QUL to add, with their status and votes. ' \
                     'Vote for the ones you need, or request a new one.',
      )
    end

    def create
      resource_request = ResourceRequest.new(request_params.merge(user: current_user))

      if resource_request.save(context: :submission)
        redirect_back_or_to root_path
      else
        redirect_back_or_to root_path, inertia: { errors: resource_request.errors.to_hash(true) }
      end
    end

    # The unique index on (request, user) makes a second vote, or two racing ones, a no-op. Both
    # ids are checked here and by foreign keys, so the vote has nothing else to validate.
    def vote
      ResourceRequestVote.insert( # rubocop:disable Rails/SkipsModelValidations -- see above
        { resource_request_id: visible_request.id, user_id: current_user.id },
        unique_by: :index_resource_request_votes_unique,
      )
      redirect_back_or_to root_path
    end

    def unvote
      visible_request.votes.where(user: current_user).delete_all
      redirect_back_or_to root_path
    end

    private

    # Sign-in is an old page, so an Inertia request leaves the app with a full visit. It returns to
    # the page the write came from when that page is on this site.
    def require_sign_in
      return if user_signed_in?

      sign_in_path = new_user_session_path(user_return_to: referer_path)
      request.inertia? ? inertia_location(sign_in_path) : redirect_to(sign_in_path)
    end

    # The Referer's path and query when it is on this site (`url_from` also takes a bare path).
    def referer_path
      uri = url_from(request.referer)&.then { |url| URI(url) }
      [uri.path, uri.query].compact.join('?') if uri
    end

    def visible_request
      ResourceRequest.visible.find(params[:id])
    end

    def request_params
      params.expect(request: [:title, :description, :resource_type, :language])
    end
  end
end
