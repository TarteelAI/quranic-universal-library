# An app built with QUL. Rows come from the submission form on /apps (Site::AppSubmissionsController),
# unpublished until an editor approves them. `contact` is for the QUL team only: no public
# serializer reads it.
class App < ApplicationRecord
  # The icon types an app may upload, by the type its bytes show, with the extension it is stored under.
  ICON_TYPES = { 'image/png' => 'png', 'image/jpeg' => 'jpg', 'image/webp' => 'webp' }.freeze
  ICON_MAX_SIZE = 1.megabyte

  belongs_to :user, optional: true
  has_one_attached :icon, service: Rails.env.production? ? :qul_exports : nil

  normalizes :name, :url, :contact, with: ->(value) { value.strip }
  normalizes :platforms, :uses, with: ->(values) { values.compact_blank.uniq }

  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true, length: { maximum: 500 }
  validate :url_is_a_web_address
  validate :platforms_from_the_list
  validate :uses_from_the_taxonomy
  validate :icon_is_a_small_image

  with_options on: :submission do
    validates :contact, presence: true, length: { maximum: 254 }
    validates :contact, format: { with: URI::MailTo::EMAIL_REGEXP, message: 'must be an email address' },
                        allow_blank: true
    validates :consent, acceptance: { accept: true, message: 'must be given to list the app' }
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
                content_type: type || 'application/octet-stream', metadata: { analyzed: true })
  end

  private

  def url_is_a_web_address
    return if url.blank? || web_address?(url)

    errors.add(:url, 'must be a web address starting with http:// or https://')
  end

  def web_address?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def platforms_from_the_list
    if platforms.empty?
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
