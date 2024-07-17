# == Schema Information
#
# Table name: api_clients
#
#  id                            :bigint           not null, primary key
#  active                        :boolean          default(TRUE)
#  api_key                       :string           not null
#  current_period_ends_at        :datetime
#  current_period_requests_count :integer
#  internal_api                  :boolean          default(FALSE)
#  kalimat_api_key               :string
#  name                          :string
#  request_quota                 :integer
#  requests_count                :integer
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_api_clients_on_active   (active)
#  index_api_clients_on_api_key  (api_key)
#
class ApiClient < QuranApiRecord
  validates :name, presence: true, uniqueness: true
  has_secure_token :api_key
  after_create :register_api
  after_update :register_api

  has_many :api_client_request_stats

  def update_api_stats
    list = requests_to_track
    track_requests(list)

    if refresh_quota?
      update_period_and_quota
    end

    update_current_period_requests
  end

  protected

  def register_api
    Recurring::UpdateApiStatsJob.perform_later(id: id)
  end

  def update_current_period_requests
    period_start = Date.today.beginning_of_month
    period_ends = Date.today.at_end_of_month

    requests = api_client_request_stats.where("date BETWEEN ? AND ?", period_start, period_ends)
    update_columns current_period_requests_count: requests.sum(:requests_count)
  end

  def track_requests(list)
    list = list.map do |query|
      parsed = Oj.load(query)
      parsed["date"] = Time.at(parsed['timestamp']).to_date

      parsed
    end

    list = list.group_by do |i|
      i['date']
    end

    list.each do |date, requests|
      stats = api_client_request_stats.where(date: date).first_or_initialize

      stats.requests_count += requests.count
      stats.save
    end
  end

  def requests_to_track
    list = redis_requests_queue.elements
    redis_requests_queue.clear

    list
  end

  def requests_key
    "api_client:#{id}-requests"
  end

  def redis_requests_queue
    @redis_list ||= Kredis.list(requests_key)
  end

  def refresh_quota?
    current_period_ends_at.nil? || current_period_ends_at.past?
  end

  def update_period_and_quota
    update_columns(
      current_period_ends_at: Date.today.at_end_of_month,
      current_period_requests_count: 0
    )
    reload
  end
end
