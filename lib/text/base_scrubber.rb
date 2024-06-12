module Text
  class BaseScrubber < Rails::Html::PermitScrubber
    LINK_NODE = 'a'.freeze
    TARGET_HOSTS = ['tarteel.ai', 'sunnah.com', 'quran.com']

    def initialize
      super
      self.tags = %w(strong em tag b i pre a sup sub span div del ins p  blockquote br).freeze
      self.attributes = %w(href lang xml:lang).freeze
    end

    protected

    def skip_node?(node)
      skipped = super(node)

      unless skipped
        if is_link?(node)
          convert_to_hashtag(node) if hash_tag?(node)
          open_in_new_tab(node)
        end
      end

      skipped
    end

    def convert_to_hashtag(node)
      node.name = 'hashtag'
    end

    def hash_tag?(node)
      node.text.start_with?('#') && node.attr('href').blank?
    end

    def is_link?(node)
      LINK_NODE == node.name
    end

    def open_in_new_tab(node)
      if external_link?(node.attr('href'))
        node.set_attribute('target', '_blank')
      end
    end

    def external_link?(path)
      if path
        host = begin
                 URI(path).host
               rescue URI::InvalidURIError => e
                 # TODO: track and fix these links
                 nil
               end

        return false if host.nil?
        !TARGET_HOSTS.include?(host)
      end
    end
  end
end