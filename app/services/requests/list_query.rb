# frozen_string_literal: true

module Requests
  # The public list of resource requests: visible requests with their vote counts, most votes or
  # newest first, one page at a time. It depends on no controller, request or session, so the
  # public API can reuse it.
  #
  # A page is one query: the requests, their vote counts, whether `user` voted for each and the
  # total of visible requests (a window count). It reads no author or voter, so nothing about
  # who asked or voted can reach a page through it. A page past the last one is empty, with a
  # total of 0.
  class ListQuery
    PER_PAGE = 20
    SORTS = ['votes', 'date'].freeze

    Result = Data.define(:requests, :sort, :page, :pages, :total)

    def initialize(sort:, page: 1, per_page: PER_PAGE, user: nil)
      @sort = SORTS.include?(sort) ? sort : SORTS.first
      @page = [page.to_i, 1].max
      @per_page = per_page
      @user = user
    end

    def call
      requests = page_scope.to_a
      total = requests.first&.total_count || 0
      Result.new(requests:, sort: @sort, page: @page, pages: [total.fdiv(@per_page).ceil, 1].max, total:)
    end

    private

    def page_scope
      ResourceRequest.visible
        .left_joins(:votes)
        .group(:id)
        .select(:id, :title, :description, :resource_type, :language, :status, :created_at)
        .select('COUNT(resource_request_votes.id) AS votes_count', 'COUNT(*) OVER () AS total_count', voted)
        .order(order)
        .limit(@per_page)
        .offset((@page - 1) * @per_page)
    end

    def voted
      return Arel.sql('FALSE AS voted') unless @user

      ResourceRequest.sanitize_sql_array(
        ['COALESCE(BOOL_OR(resource_request_votes.user_id = ?), FALSE) AS voted', @user.id],
      )
    end

    def order
      newest = { created_at: :desc, id: :desc }
      @sort == 'votes' ? [Arel.sql('votes_count DESC'), newest] : newest
    end
  end
end
