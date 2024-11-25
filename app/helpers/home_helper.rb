module HomeHelper
  TAG_COLORS = ['red', 'green', 'blue', 'orange'].freeze

  def resource_tag_class(tag)
    TAG_COLORS[string_to_bucket(tag, TAG_COLORS.size) - 1]
  end

  def inline_stylesheet_source(name)
    asset_name = "#{name}.css"

    if Rails.env.development? || Rails.env.test?
      Rails.application.assets[asset_name].to_s
    else
      asset_path = ActionController::Base.helpers.asset_path(asset_name)
      File.read("#{Rails.root}/public#{asset_path}")
    end
  end

  def whodunnit(version)
    GlobalID::Locator.locate(version.whodunnit).name
  rescue Exception => e
  end

  def content_tag_if(add_tag, tag_name, content)
    if add_tag
      content_tag tag_name, content
    else
      content
    end
  end

  def diff_text(text1, text2)
    Diffy::SplitDiff.new(text1, text2, format: :html).right.html_safe
  end

  def translation_view_types
    ['ayah', 'page', 'page_with_pdf', 'page_with_arabic']
  end

  def tafisr_view_types
    ['ayah', 'page_with_pdf', 'page_with_arabic']
  end

  # Return the bucket number for the given input string
  def string_to_bucket(input, max=5)
    hash = input.bytes.sum + input.length
    (hash % max) + 1
  end
end
