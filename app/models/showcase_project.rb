# == Schema Information
#
# Table name: showcase_projects
#
#  id                 :bigint           not null, primary key
#  app_store_url      :string
#  description        :text
#  name               :string           not null
#  owner_name         :string
#  owner_type         :string           default("individual")
#  platforms          :string           default([]), is an Array
#  play_store_url     :string
#  project_type       :string           default("app"), not null
#  published          :boolean          default(FALSE), not null
#  qul_resources_used :text
#  repository_url     :string
#  website_url        :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  user_id            :integer
#
# Indexes
#
#  index_showcase_projects_on_published  (published)
#  index_showcase_projects_on_user_id    (user_id)
#
class ShowcaseProject < ApplicationRecord
  PROJECT_TYPES = {
    'app' => 'App',
    'library' => 'Library / SDK',
    'api' => 'API',
    'cli' => 'CLI',
    'model' => 'AI model',
    'other' => 'Other'
  }.freeze

  PLATFORMS = {
    'web' => 'Web',
    'android' => 'Android',
    'ios' => 'iOS',
    'desktop' => 'Desktop',
    'bot' => 'Bot'
  }.freeze

  OWNER_TYPES = {
    'individual' => 'Individual',
    'organization' => 'Organization'
  }.freeze

  LINK_FIELDS = %i[website_url app_store_url play_store_url repository_url].freeze
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  LOGO_MAX_SIZE = 1.megabyte

  belongs_to :user, optional: true
  has_one_attached :logo, service: Rails.env.development? ? :local : :qul_exports

  attr_accessor :logo_file

  scope :published, -> { where(published: true).order(created_at: :desc) }

  before_validation :normalize_platforms
  after_save_commit :attach_logo_file, if: :logo_file

  validates :name, presence: true, length: { maximum: 60 }
  validates :description, presence: true, length: { in: 100..200 }
  validates :platforms, presence: true
  validates :qul_resources_used, presence: true, length: { maximum: 200 }
  validates :owner_name, presence: true, length: { maximum: 80 }
  validates :project_type, inclusion: { in: PROJECT_TYPES.keys }
  validates :owner_type, inclusion: { in: OWNER_TYPES.keys }, allow_blank: true
  validate :platforms_are_known
  validate :links_are_http
  validate :has_a_link
  validate :logo_file_is_an_image

  def project_type_name
    PROJECT_TYPES[project_type]
  end

  def platform_names
    platforms.filter_map { |platform| PLATFORMS[platform] }
  end

  def attach_logo(io:, filename:)
    key = "showcase/#{SecureRandom.base36(5)}/#{filename}"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: filename,
      key: key,
      service_name: Rails.env.development? ? :local : :qul_exports
    )

    logo.attach(blob)
  end

  private

  def normalize_platforms
    self.platforms = Array(platforms).map { |platform| platform.to_s.strip }.reject(&:blank?).uniq
  end

  def platforms_are_known
    unknown = platforms - PLATFORMS.keys
    errors.add(:platforms, "has unknown values: #{unknown.join(', ')}") if unknown.any?
  end

  def links_are_http
    LINK_FIELDS.each do |field|
      value = public_send(field)
      next if value.blank?

      uri = URI.parse(value) rescue nil
      errors.add(field, 'must be a valid http(s) URL') unless uri.is_a?(URI::HTTP) && uri.host.present?
    end
  end

  def has_a_link
    if LINK_FIELDS.none? { |field| public_send(field).present? }
      errors.add(:base, 'Add at least one link (website, store or repository)')
    end
  end

  def logo_file_is_an_image
    return if logo_file.blank?
    return errors.add(:logo, 'is invalid') unless logo_file.respond_to?(:tempfile)

    content_type = Marcel::MimeType.for(Pathname.new(logo_file.path))
    errors.add(:logo, 'must be a PNG, JPG or WebP image') unless LOGO_CONTENT_TYPES.include?(content_type)
    errors.add(:logo, 'must be 1 MB or smaller') if logo_file.size > LOGO_MAX_SIZE
  end

  def attach_logo_file
    file = logo_file
    self.logo_file = nil
    attach_logo(io: file.tempfile, filename: file.original_filename)
  end
end
