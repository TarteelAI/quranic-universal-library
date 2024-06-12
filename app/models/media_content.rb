# == Schema Information
#
# Table name: media_contents
#
#  id                  :integer          not null, primary key
#  author_name         :string
#  duration            :string
#  embed_text          :text
#  language_name       :string
#  provider            :string
#  resource_type       :string
#  url                 :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  language_id         :integer
#  resource_content_id :integer
#  resource_id         :integer
#
# Indexes
#
#  index_media_contents_on_language_id                    (language_id)
#  index_media_contents_on_resource_content_id            (resource_content_id)
#  index_media_contents_on_resource_type_and_resource_id  (resource_type,resource_id)
#
class MediaContent < QuranApiRecord
  include Resourceable

  belongs_to :resource, polymorphic: true
  belongs_to :language

  validates :url, :resource, presence: true

  after_create :update_embed_code_and_metadata

  protected
  def update_embed_code_and_metadata
    video = VideoInfo.new(self.url.to_s, referer: 'https://quran.com/')

    if video.available?
      #self.duration = video.duration
      self.embed_text = video.embed_code(url_attributes: url_attributes(video.provider))
      self.provider = video.provider
      self.save
    end
  rescue Exception => e
    nil
  end

  def url_attributes(provider)
    case provider.to_s.downcase
      when 'dailymotion'
        {skin: 'default', autoplay: 1, no_tabs: 0}
      when 'youtube'
        {enablejsapi: 1, wmode: 'transparent', iv_load_policy: 3, origin: 'https://quran.com', rel: 0, autohide: 1, autoplay: 1}
      else
        {}
    end
  end
end

