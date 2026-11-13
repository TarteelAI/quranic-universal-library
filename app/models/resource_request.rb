# frozen_string_literal: true

# A signed-in user's ask for a resource QUL does not have, with votes from other users. Editors set
# its status and can hide it in the CMS. The author is for the QUL team only: the public list
# (Requests::ListQuery) reads no author or voter, only vote counts.
class ResourceRequest < ApplicationRecord
  # The requests a user can send in a day (DECISIONS.md, Sprint 002).
  DAILY_LIMIT = 5

  # The statuses editors set, with the label a visitor reads. New requests are open.
  STATUSES = {
    'open' => 'Open',
    'planned' => 'Planned',
    'in_progress' => 'In progress',
    'added' => 'Added to QUL',
    'declined' => 'Not planned',
  }.freeze

  # For a resource that fits none of the catalog types.
  OTHER_TYPE = 'other'

  belongs_to :user, optional: true
  has_many :votes, class_name: 'ResourceRequestVote', dependent: :delete_all

  normalizes :title, :description, with: ->(value) { value.strip }
  normalizes :language, with: ->(value) { value.strip.presence }

  scope :visible, -> { where(hidden: false) }

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :language, length: { maximum: 60 }
  validates :resource_type, inclusion: { in: ->(_) { Catalog::Taxonomy.types.map(&:key) + [OTHER_TYPE] },
                                         message: 'must be chosen from the list', }
  validates :status, inclusion: { in: STATUSES.keys, message: 'must be chosen from the list' }
  validate :within_the_daily_limit, on: :submission

  def status_label
    STATUSES.fetch(status)
  end

  private

  # Counted from the user's own rows of the current day (Time.zone), as App counts submissions.
  def within_the_daily_limit
    return unless ResourceRequest.where(user_id:, created_at: Time.current.all_day).count >= DAILY_LIMIT

    errors.add(:base, "You can send at most #{DAILY_LIMIT} requests a day. Try again tomorrow.")
  end
end
