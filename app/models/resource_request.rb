# frozen_string_literal: true

# A signed-in user's ask for a resource QUL does not have, with votes from other users. Editors set
# its status and can hide it in the CMS. The user who sent it is for the QUL team only: the public
# list (Requests::ListQuery) reads no user or voter, only vote counts, and none of the source
# details or files, which are for editors.
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

  # What a request type asks for beyond the title and description (DECISIONS.md, "A request says
  # where its resource comes from"). `author` is 'required', 'optional' or nil: a written work
  # (translation, tafsir, surah info) needs its author and may name the book, its publisher and
  # year; Other may name them; the other types do not ask. `source_required`: a font needs the
  # font, as a file or a link. Every type may add licence details, source files and a link.
  Details = Data.define(:author, :source_required)
  WORK = Details.new(author: 'required', source_required: false)
  DETAILS = {
    'translation' => WORK, 'tafsir' => WORK, 'surah-info' => WORK,
    OTHER_TYPE => Details.new(author: 'optional', source_required: false),
    'font' => Details.new(author: nil, source_required: true),
  }.freeze
  NO_DETAILS = Details.new(author: nil, source_required: false)
  WORK_FIELDS = [:author, :book_name, :publisher, :publishing_year].freeze

  # The source files a request may carry, by the type their bytes show, with a label for the form.
  SOURCE_TYPES = {
    'application/pdf' => 'PDF',
    'application/msword' => 'Word',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'Word',
    'text/plain' => 'Text',
    'font/ttf' => 'TrueType font', 'font/otf' => 'OpenType font', 'font/woff' => 'WOFF font',
    'font/woff2' => 'WOFF2 font',
  }.freeze
  SOURCE_MAX_SIZE = 10.megabytes
  SOURCE_MAX_FILES = 5

  belongs_to :user, optional: true
  has_many :votes, class_name: 'ResourceRequestVote', dependent: :delete_all
  # For editors only, so on the private default service (signed links), not the public one the
  # app icons use.
  has_many_attached :source_files

  normalizes :title, :description, with: ->(value) { value.strip }
  normalizes :language, :author, :book_name, :publisher, :license_details, :source_url,
             with: ->(value) { value.strip.presence }

  # A type that does not ask about a written work keeps none of its fields.
  before_validation do
    WORK_FIELDS.each { |field| self[field] = nil } if details.author.nil?
  end

  scope :visible, -> { where(hidden: false) }

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, presence: true, length: { maximum: 2000 }
  validates :language, length: { maximum: 60 }
  validates :resource_type, inclusion: { in: ->(_) { Catalog::Taxonomy.types.map(&:key) + [OTHER_TYPE] },
                                         message: 'must be chosen from the list', }
  validates :status, inclusion: { in: STATUSES.keys, message: 'must be chosen from the list' }
  validates :author, :book_name, :publisher, length: { maximum: 200 }
  validates :publishing_year, numericality: { only_integer: true, greater_than: 0,
                                              less_than_or_equal_to: ->(_) { Date.current.year }, },
                              allow_nil: true
  validates :license_details, length: { maximum: 1000 }
  validates :source_url, length: { maximum: 500 }
  validate :source_url_is_a_web_address
  validate :source_files_are_documents_or_fonts
  # Asked of a new request only, so editors can still change a request sent before these fields.
  with_options on: :submission do
    validates :author, presence: true, if: -> { details.author == 'required' }
    validate :source_given, if: -> { details.source_required }
    validate :within_the_daily_limit
  end

  def self.details(type)
    DETAILS.fetch(type, NO_DETAILS)
  end

  def details
    self.class.details(resource_type)
  end

  def status_label
    STATUSES.fetch(status)
  end

  # Attaches uploaded source files. Each file's type comes from its bytes (its name only tells a
  # Word file from other OLE files, and marks text, which has no magic bytes); text must be UTF-8.
  # The blobs are marked as analysed, because analysis runs as a job and a request enqueues nothing.
  def source_uploads=(files)
    Array(files).compact_blank.each do |file|
      name = file.respond_to?(:original_filename) ? file.original_filename.to_s : 'source'
      file = StringIO.new(file.to_s) unless file.respond_to?(:read)
      source_files.attach(io: file, filename: name.presence || 'source', content_type: source_type(file, name),
                          metadata: { analyzed: true },)
    end
  end

  private

  def source_type(file, name)
    type = Marcel::MimeType.for(file, name: name)
    type = Marcel::MimeType.for(name: name) if type == 'application/x-ole-storage'
    type = 'application/octet-stream' if type == 'text/plain' && !utf8_text?(file)
    file.rewind
    type
  end

  def utf8_text?(file)
    file.rewind
    bytes = file.read(SOURCE_MAX_SIZE + 1).to_s
    bytes.force_encoding(Encoding::UTF_8).valid_encoding? && bytes.exclude?("\0")
  end

  def source_url_is_a_web_address
    return if source_url.blank? || web_address?(source_url)

    errors.add(:source_url, 'must be a web address starting with http:// or https://')
  end

  def web_address?(value)
    uri = URI.parse(value)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def source_files_are_documents_or_fonts
    files = source_files.map(&:blob)
    if files.size > SOURCE_MAX_FILES
      errors.add(:source_files, "can be at most #{SOURCE_MAX_FILES} files")
    elsif files.any? { |blob| SOURCE_TYPES.exclude?(blob.content_type) }
      errors.add(:source_files, 'must be PDF, Word, text or font files (TTF, OTF, WOFF, WOFF2)')
    elsif files.any? { |blob| blob.byte_size > SOURCE_MAX_SIZE }
      errors.add(:source_files, "must each be #{SOURCE_MAX_SIZE / 1.megabyte} MB or smaller")
    end
  end

  def source_given
    return if source_url.present? || source_files.attached?

    errors.add(:source_files, 'or a link is needed for a font')
  end

  # Counted from the user's own rows of the current day (Time.zone), as App counts submissions.
  def within_the_daily_limit
    return unless ResourceRequest.where(user_id:, created_at: Time.current.all_day).count >= DAILY_LIMIT

    errors.add(:base, "You can send at most #{DAILY_LIMIT} requests a day. Try again tomorrow.")
  end
end
