# frozen_string_literal: true

# An app built with QUL, in the apps directory (/apps and the home page's apps band) once it is
# published. Rows come from the submission form on /apps (Site::AppSubmissionsController),
# unpublished until an editor approves them in the CMS, and from `apps:import`. `contact` is for
# the QUL team only: no public serializer reads it. `url` is the main link (the site, else a store
# page or the repo); the store and source links are extra links beside it. Only an app (the
# `app` type) has platforms.
class App < ApplicationRecord
  # The submissions a user can send in a day (DECISIONS.md, Sprint 002).
  DAILY_LIMIT = 3

  # The icon types an app may upload, by the type its bytes show, with the extension it is stored under.
  ICON_TYPES = { 'image/png' => 'png', 'image/jpeg' => 'jpg', 'image/webp' => 'webp' }.freeze
  ICON_MAX_SIZE = 1.megabyte

  belongs_to :user, optional: true
  has_one_attached :icon, service: Rails.env.production? ? :qul_exports : nil

  LINKS = [:url, :app_store_url, :play_store_url, :source_url].freeze

  normalizes :name, :contact, :kind, :description, :evidence, *LINKS, with: ->(value) { value.strip.presence }
  normalizes :platforms, :uses, with: ->(values) { values.compact_blank.uniq }

  # Only an app has platforms.
  before_validation { self.platforms = [] unless project_type == 'app' }

  # The directory: published apps, featured first, then oldest first (the import keeps the order of
  # config/apps.yml).
  scope :directory, -> { where(published: true).order(featured: :desc, id: :asc) }

  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true
  validates(*LINKS, length: { maximum: 500 })
  validates :project_type, inclusion: { in: AppDirectory::PROJECT_TYPES.keys, message: 'must be chosen from the list' }
  validate :links_are_web_addresses
  validate :platforms_from_the_list
  validate :uses_from_the_taxonomy
  validate :icon_is_a_small_image
  # The directory shows a kind and a description, which a submission does not ask for.
  validates :kind, presence: true, length: { maximum: 40 }, if: :published?
  validates :description, presence: true, length: { maximum: 300 }, if: :published?

  with_options on: :submission do
    validates :description, presence: true, length: { maximum: 300 }
    validates :contact, presence: true, length: { maximum: 254 }
    validates :contact, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'must be an email address' },
                        allow_blank: true
    validates :consent, acceptance: { accept: true, message: 'must be given to list the app' }
    validate :within_the_daily_limit
  end

  # Attaches an uploaded icon. Its type and stored name come from the file's bytes, never from
  # the name or type the browser sent; a text value in place of a file is checked as its bytes.
  # The blob is marked as analysed because analysis runs as a job (ActiveStorage::AnalyzeJob),
  # and a submission enqueues nothing.
  def icon_upload=(file)
    file = StringIO.new(file.to_s) unless file.respond_to?(:read)
    type = Marcel::Magic.by_magic(file)&.type
    extension = ICON_TYPES[type]
    icon.attach(io: file, filename: extension ? "icon.#{extension}" : 'icon',
                content_type: type || 'application/octet-stream', metadata: { analyzed: true },)
  end

  private

  # Counted from the user's own rows of the current day (Time.zone), so the first submission after
  # midnight is taken again.
  def within_the_daily_limit
    return unless App.where(user_id:, created_at: Time.current.all_day).count >= DAILY_LIMIT

    errors.add(:base, "You can send at most #{DAILY_LIMIT} apps a day. Try again tomorrow.")
  end

  def links_are_web_addresses
    LINKS.each do |link|
      value = public_send(link)
      next if value.blank? || web_address?(value)

      errors.add(link, 'must be a web address starting with http:// or https://')
    end
  end

  def web_address?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def platforms_from_the_list
    if platforms.empty? && project_type == 'app'
      errors.add(:platforms, 'must include at least one platform')
    elsif !platforms.all? { |key| AppDirectory::PLATFORMS.key?(key) }
      errors.add(:platforms, 'must be chosen from the list')
    end
  end

  def uses_from_the_taxonomy
    if uses.empty?
      errors.add(:uses, 'must include at least one resource type')
    elsif !uses.all? { |key| Catalog::Taxonomy.type(key) }
      errors.add(:uses, 'must be chosen from the list')
    end
  end

  def icon_is_a_small_image
    return unless icon.attached?

    if ICON_TYPES.exclude?(icon.blob.content_type)
      errors.add(:icon, 'must be a PNG, JPEG or WebP image')
    elsif icon.blob.byte_size > ICON_MAX_SIZE
      errors.add(:icon, 'must be 1 MB or smaller')
    end
  end
end
