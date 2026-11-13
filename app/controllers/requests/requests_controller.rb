# frozen_string_literal: true

module Requests
  # The write paths of resource requests (`requests` page group): POST /requests creates one,
  # POST /requests/:id/vote votes and DELETE /requests/:id/vote takes the vote back. Each needs a
  # signed-in user, goes back to the page it came from and enqueues nothing.
  class RequestsController < InertiaController
    before_action :require_sign_in

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

      return_to = url_from(request.referer)&.then { |url| URI(url).request_uri }
      sign_in_path = new_user_session_path(user_return_to: return_to)
      request.inertia? ? inertia_location(sign_in_path) : redirect_to(sign_in_path)
    end

    def visible_request
      ResourceRequest.visible.find(params[:id])
    end

    def request_params
      params.expect(request: [:title, :description, :resource_type, :language])
    end
  end
end
