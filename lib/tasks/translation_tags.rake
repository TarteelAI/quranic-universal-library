namespace :translation_tags do
  task fix_bridge: :environment do
    PaperTrail.enabled =false
    def fix_formatting(text)
      # Replace <a class="sup"><sup>pl</sup></a> with <sup>pl</sup>
      text.gsub!(%r{<a class="sup">\s*(<sup>.*?</sup>)\s*</a>}, '\1')

      # Ensure space after </sup>, </span>, </i> if followed by a word
      text.gsub!(/(<\/sup>)(\w)/, '\1 \2')
      text.gsub!(/(<\/span>)(\w)/, '\1 \2')
      text.gsub!(/(<\/i>)(\w)/, '\1 \2')

      # Ensure space before <span class="h"> if not preceded by space or punctuation
      text.gsub!(/(\S)(<span class="h">)/, '\1 \2')

      # Ensure space before and after <i class="s">...</i>
      text.gsub!(/(\S)(<i class="s">)/, '\1 \2')  # space before <i>
      text.gsub!(/(<\/i>)(\S)/, '\1 \2')         # space after </i>

      # Move <sup> tag out of <span class="h"> if it's inside
      text.gsub!(%r{<span class="h">(.*?)<sup(.*?)</sup>(.*?)</span>}) do
        before = $1.strip
        sup = "<sup#{$2}</sup>"
        after = $3.strip
        result = []
        result << "<span class=h>#{before}</span>" unless before.empty?
        result << sup
        result << "<span class=h>#{after}</span>" unless after.empty?
        result.join(' ')
      end

      text.gsub!(/<\/span>\s+<sup/, '</span><sup')
      # Normalize multiple spaces
      text.gsub!(/\s+/, ' ')

      text.strip
    end
    Translation.where("text ilike ?", "%<%").where(resource_content_id: 149).find_each do |t|
      t.text = fix_formatting(t.text)
      t.save
    end
    Translation.where("text ilike ?", '%<span class="h"><span class="h">%').each do |t|
      t.text = t.text.gsub('<span class="h"><span class="h">', "<span class='h'>")
      t.save
    end
  end

  task generate_report: :environment do
    @track = {}
    tags = {}
    nested_tags = {}


    def record_tags(t, doc, tags, nested_tags, parent_tag = nil)
      if doc.name.blank? || doc.text?
        return
      end

      tags[doc.name] ||= 0
      tags[doc.name] += 1

      if doc.name == 'div'
        nested_tags['div'] ||= []
        nested_tags['div'] << t
      end

      if parent_tag
        nested_tags["#{parent_tag}-#{doc.name}"] ||= 0
        nested_tags["#{parent_tag}-#{doc.name}"] += 1

        if ['sup-sup', 'div-sup', 'span-sup'].include?("#{parent_tag}-#{doc.name}")
          @track["#{parent_tag}-#{doc.name}"] ||= []
          @track["#{parent_tag}-#{doc.name}"] << t
        end
      end

      doc.children.each do |child|
        record_tags(t, child, tags, nested_tags, doc.name)
      end

      tags
    end

    Translation.where("text ilike ?", "%<%").find_each do |t|
      doc = Nokogiri::HTML::DocumentFragment.parse(t.text)

      doc.children.each do |child|
        record_tags(t.id, child, tags, nested_tags)
      end
    end
  end
end